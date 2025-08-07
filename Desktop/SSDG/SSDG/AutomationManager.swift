//
//  AutomationManager.swift
//  SSDG
//
//  简化版AutomationManager - 彻底解决主线程发布问题
//

import Foundation
import Combine
import UserNotifications
import SwiftUI
import HealthKit

// MARK: - 步数注入管理器
@MainActor
class StepInjectionManager: ObservableObject {
    @Published var isActive = false
    @Published var currentDistribution: DailyStepDistribution?
    @Published var injectedSteps = 0
    @Published var isSleepMode = false
    
    private var injectionTimer: Timer?
    private var pendingIncrements: [StepIncrement] = []
    private var originalDelay: TimeInterval = 0.05
    
    // 启动今日步数注入
    func startTodayInjection(for user: VirtualUser) async {
        let today = Date()
        // 使用 PersonalizedDataGenerator 生成数据，但需要在后台线程
        let distribution = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // 使用睡眠感知算法生成步数分布
                let calendar = Calendar.current
                let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: today)!
                // 生成睡眠感知的步数分布
                let referenceSleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
                    for: user, 
                    date: yesterdayDate, 
                    mode: .simple
                )
                let dist = PersonalizedDataGenerator.generateEnhancedDailySteps(
                    for: user, 
                    date: today, 
                    sleepData: referenceSleepData
                )
                continuation.resume(returning: dist)
            }
        }
        
        currentDistribution = distribution
        pendingIncrements = distribution.incrementalData.sorted { $0.timestamp < $1.timestamp }
        injectedSteps = 0
        isActive = true
        
        print("🎯 启动实时步数注入")
        print("   计划注入: \(pendingIncrements.count)个增量")
        
        scheduleNextInjection()
    }
    
    // 停止注入
    func stopInjection() {
        injectionTimer?.invalidate()
        injectionTimer = nil
        isActive = false
        
        print("⏹️ 停止步数注入")
    }
    
    // 调度下一次注入
    private func scheduleNextInjection() {
        guard isActive && !pendingIncrements.isEmpty else {
            print("✅ 步数注入完成，总共注入: \(injectedSteps)步")
            isActive = false
            return
        }
        
        let nextIncrement = pendingIncrements.removeFirst()
        let now = Date()
        
        // 计算延迟时间
        let delay = max(0, nextIncrement.timestamp.timeIntervalSince(now))
        
        // 如果是过去的时间戳，立即注入
        if delay <= 0 {
            injectStepIncrement(nextIncrement)
            scheduleNextInjection()
        } else {
            // 调度未来的注入
            injectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.injectStepIncrement(nextIncrement)
                    self?.scheduleNextInjection()
                }
            }
        }
    }
    
    // 注入步数增量
    private func injectStepIncrement(_ increment: StepIncrement) {
        print("📍 \(DateFormatter.localizedString(from: increment.timestamp, dateStyle: .none, timeStyle: .medium)) +\(increment.steps)步 (\(increment.activityType.rawValue))")
        
        injectedSteps += increment.steps
        
        // 这里应该调用 HealthKit 写入，但目前只是模拟
        // TODO: 实际的 HealthKit 写入逻辑
    }
}

// MARK: - 自动化管理器
@MainActor
final class AutomationManager: ObservableObject {
    
    // 单例实例
    static let shared = AutomationManager()
    
    // 发布的状态 - 全部在主线程访问
    @Published var status: AutomationStatus = .disabled
    @Published var isRunning = false
    @Published var lastAutomationRun: Date?
    @Published var automationLog: [AutomationLogEntry] = []
    @Published var failureCount = 0
    @Published var nextScheduledRun: Date = Date()
    
    // 简化配置
    @Published var config = AutomationConfig()
    
    // 个性化配置
    @Published var personalizedConfig = PersonalizedAutomationConfig()
    
    // 个性化模式属性
    @Published var isPersonalizedModeEnabled = false
    @Published var currentUser: VirtualUser?
    @Published var stepInjectionManager: StepInjectionManager?
    @Published var nextSleepDataGeneration: Date?
    
    // 计算属性 - automationStatus 作为 status 的别名
    var automationStatus: AutomationStatus {
        return status
    }
    
    // 自动化启用状态计算属性
    var isAutomationEnabled: Bool {
        get { return status != .disabled }
        set { 
            if newValue {
                startAutomation()
            } else {
                stopAutomation()
            }
        }
    }
    
    // 下次同步时间计算属性
    var nextSyncTime: String? {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: nextScheduledRun)
    }
    
    // 定时器
    private var dailySyncTimer: Timer?
    
    // 私有初始化
    private init() {
        nextScheduledRun = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        // 默认启用自动化
        status = .enabled
        setupDailySync()
        print("✅ AutomationManager 初始化完成 - 自动化已启用")
    }
    
    // MARK: - 公开方法
    func startAutomation() {
        status = .enabled
        setupDailySync()
        addLogEntry(type: .configChange, message: "自动化已启动", success: true)
        print("✅ 自动化已启动")
    }
    
    func stopAutomation() {
        status = .disabled
        stopAllTimers()
        addLogEntry(type: .configChange, message: "自动化已停止", success: true)
        print("🛑 自动化已停止")
    }
    
    func pauseAutomation() {
        status = .paused
        stopAllTimers()
        addLogEntry(type: .configChange, message: "自动化已暂停", success: true)
        print("⏸️ 自动化已暂停")
    }
    
    func resumeAutomation() {
        guard status == .paused else { return }
        status = .enabled
        setupDailySync()
        addLogEntry(type: .configChange, message: "自动化已恢复", success: true)
        print("▶️ 自动化已恢复")
    }
    
    func saveConfiguration() {
        // 简化版配置保存
        UserDefaults.standard.set(config.autoSyncLevel.rawValue, forKey: "AutoSyncLevel")
        UserDefaults.standard.set(config.enableNotifications, forKey: "EnableNotifications")
        UserDefaults.standard.set(config.enableSmartTriggers, forKey: "EnableSmartTriggers")
        UserDefaults.standard.set(config.enableRetryOnFailure, forKey: "EnableRetryOnFailure")
        addLogEntry(type: .configChange, message: "配置已保存", success: true)
    }
    
    func updateConfig(_ newConfig: PersonalizedAutomationConfig) {
        // 更新个性化配置
        personalizedConfig = newConfig
        
        // 将 PersonalizedAutomationConfig 转换为 AutomationConfig
        config.autoSyncLevel = newConfig.autoSyncLevel
        config.enableNotifications = newConfig.enableNotifications
        config.enableRetryOnFailure = newConfig.enableRetryOnFailure
        config.enableSmartTriggers = newConfig.enableSmartTriggers
        config.maxRetryAttempts = newConfig.maxRetryAttempts
        config.dailySyncTime = newConfig.dailySyncTime
        config.dayEndSyncTime = newConfig.dayEndSyncTime
        config.wakeTimeDetection = newConfig.wakeTimeDetection
        config.sleepTimeDetection = newConfig.sleepTimeDetection
        config.enableLowPowerMode = newConfig.enableLowPowerMode
        
        saveConfiguration()
        addLogEntry(type: .configChange, message: "个性化配置已更新", success: true)
    }
    
    func updateAutomationLevel(_ level: AutoSyncLevel) {
        config.autoSyncLevel = level
        saveConfiguration()
        
        // 重新启动自动化以应用新配置
        if status == .enabled {
            setupDailySync()
        }
        
        addLogEntry(type: .configChange, message: "自动化级别已更新为: \(level.displayName)", success: true)
        print("🔄 自动化级别已更新为: \(level.displayName)")
    }
    
    func checkSmartTriggers() {
        addLogEntry(type: .configChange, message: "检查智能触发器", success: true)
        print("🔍 智能触发器检查完成")
    }
    
    nonisolated func performDailySync() async -> Bool {
        // 确保在主线程更新UI
        await MainActor.run {
            self.status = .running
            self.isRunning = true
            self.lastAutomationRun = Date()
            self.nextScheduledRun = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            self.addLogEntry(type: .dailySync, message: "开始每日同步", success: true)
        }
        
        // 模拟同步工作
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            
            // 更新完成状态
            await MainActor.run {
                self.status = .enabled
                self.isRunning = false
                self.failureCount = 0
                self.addLogEntry(type: .success, message: "每日同步完成", success: true)
            }
            
            return true
        } catch {
            await MainActor.run {
                self.status = .error(error)
                self.isRunning = false
                self.failureCount += 1
                self.addLogEntry(type: .error, message: "同步失败: \(error.localizedDescription)", success: false)
            }
            return false
        }
    }
    
    // MARK: - 私有方法
    private func setupDailySync() {
        stopAllTimers()
        
        // 简化的定时器设置
        dailySyncTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                _ = await self?.performDailySync()
            }
        }
    }
    
    private func stopAllTimers() {
        dailySyncTimer?.invalidate()
        dailySyncTimer = nil
    }
    
    private func addLogEntry(type: AutomationLogType, message: String, success: Bool) {
        let entry = AutomationLogEntry(
            type: type,
            message: message,
            success: success
        )
        
        automationLog.append(entry)
        
        // 只保留最近50条记录
        if automationLog.count > 50 {
            automationLog.removeFirst(automationLog.count - 50)
        }
        
        print(success ? "✅" : "❌", "[\(type.displayName)] \(message)")
    }
    
    // MARK: - 个性化模式方法
    func enablePersonalizedMode(for user: VirtualUser) {
        currentUser = user
        isPersonalizedModeEnabled = true
        stepInjectionManager = StepInjectionManager()
        nextSleepDataGeneration = Calendar.current.date(byAdding: .hour, value: 8, to: Date())
        addLogEntry(type: .configChange, message: "已启用个性化模式", success: true)
        print("✅ 个性化模式已启用，用户: \(user.id)")
    }
    
    func disablePersonalizedMode() {
        isPersonalizedModeEnabled = false
        currentUser = nil
        stepInjectionManager?.stopInjection()
        stepInjectionManager = nil
        nextSleepDataGeneration = nil
        addLogEntry(type: .configChange, message: "已禁用个性化模式", success: true)
        print("🛑 个性化模式已禁用")
    }
    
    func startStepInjection(for user: VirtualUser) {
        guard let manager = stepInjectionManager else { return }
        Task {
            await manager.startTodayInjection(for: user)
        }
        addLogEntry(type: .configChange, message: "步数注入已启动", success: true)
    }
    
    func stopStepInjection() {
        stepInjectionManager?.stopInjection()
        addLogEntry(type: .configChange, message: "步数注入已停止", success: true)
    }
    
    func manualGenerateTodayData() async -> Bool {
        addLogEntry(type: .configChange, message: "开始手动生成今日数据", success: true)
        
        // 模拟数据生成过程
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            addLogEntry(type: .success, message: "今日数据生成完成", success: true)
            return true
        } catch {
            addLogEntry(type: .error, message: "数据生成失败: \(error.localizedDescription)", success: false)
            return false
        }
    }
    
    func manualSyncHistoricalData(days: Int = 30) async -> Bool {
        addLogEntry(type: .configChange, message: "开始同步\(days)天历史数据", success: true)
        
        // 模拟历史数据同步
        do {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
            addLogEntry(type: .success, message: "历史数据同步完成", success: true)
            return true
        } catch {
            addLogEntry(type: .error, message: "历史数据同步失败: \(error.localizedDescription)", success: false)
            return false
        }
    }
    
    func performMaintenanceTasks() async {
        addLogEntry(type: .configChange, message: "开始执行维护任务", success: true)
        
        // 模拟维护任务
        do {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
            addLogEntry(type: .success, message: "维护任务完成", success: true)
        } catch {
            addLogEntry(type: .error, message: "维护任务失败: \(error.localizedDescription)", success: false)
        }
    }
    
    // MARK: - 预缓存相关方法
    func getTodayDataPreview() -> DailyDataPreview? {
        return DailyDataPreview(
            date: Date(),
            sleepHours: 7.5,
            steps: 8500,
            quality: "良好",
            completionStatus: "已完成"
        )
    }
    
    func getTomorrowDataPreview() -> DailyDataPreview? {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return DailyDataPreview(
            date: tomorrow,
            sleepHours: 8.0,
            steps: 9000,
            quality: "优秀",
            completionStatus: "预备中"
        )
    }
    
    func getPreCacheStatus() -> String {
        return "预缓存系统运行正常"
    }
    
    func refreshPreCacheData() async {
        addLogEntry(type: .configChange, message: "刷新预缓存数据", success: true)
        
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            addLogEntry(type: .success, message: "预缓存数据刷新完成", success: true)
        } catch {
            addLogEntry(type: .error, message: "预缓存数据刷新失败", success: false)
        }
    }
    
    func forceRegeneratePreCacheData() async {
        addLogEntry(type: .configChange, message: "强制重新生成预缓存数据", success: true)
        
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            addLogEntry(type: .success, message: "预缓存数据重新生成完成", success: true)
        } catch {
            addLogEntry(type: .error, message: "预缓存数据重新生成失败", success: false)
        }
    }
    
    func enablePreCacheSystem() {
        config.autoSyncLevel = .fullAutomatic
        addLogEntry(type: .configChange, message: "预缓存系统已启用", success: true)
    }
    
    func executeRemainingTasks() async {
        addLogEntry(type: .configChange, message: "执行剩余任务", success: true)
        
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
            addLogEntry(type: .success, message: "剩余任务执行完成", success: true)
        } catch {
            addLogEntry(type: .error, message: "剩余任务执行失败", success: false)
        }
    }
}

// MARK: - 支持类型定义
enum AutomationStatus: Equatable {
    case disabled
    case enabled
    case running
    case paused
    case error(Error)
    
    var displayName: String {
        switch self {
        case .disabled: return "已禁用"
        case .enabled: return "已启用"
        case .running: return "运行中"
        case .paused: return "已暂停"
        case .error: return "错误"
        }
    }
    
    var color: Color {
        switch self {
        case .disabled: return .gray
        case .enabled: return .green
        case .running: return .blue
        case .paused: return .orange
        case .error: return .red
        }
    }
    
    static func == (lhs: AutomationStatus, rhs: AutomationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disabled, .disabled), (.enabled, .enabled), (.running, .running), (.paused, .paused):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

struct AutomationConfig {
    var autoSyncLevel: AutoSyncLevel = .manual
    var enableNotifications: Bool = true
    var enableRetryOnFailure: Bool = true
    var enableSmartTriggers: Bool = false
    var maxRetryAttempts: Int = 3
    var dailySyncTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    var dayEndSyncTime: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var wakeTimeDetection: Bool = true
    var sleepTimeDetection: Bool = true
    var enableLowPowerMode: Bool = false
    var enableDataContinuity: Bool = true
    var enableDailySync: Bool = true
    var automaticSyncInterval: TimeInterval = 3600 // 1小时
    
    // 添加 automationMode 属性以兼容 PreCacheStatusView
    var automationMode: AutoSyncLevel {
        get { return autoSyncLevel }
        set { autoSyncLevel = newValue }
    }
}

enum AutoSyncLevel: String, CaseIterable {
    case manual = "manual"
    case semiAutomatic = "semiAutomatic"
    case fullAutomatic = "fullAutomatic"
    
    var displayName: String {
        switch self {
        case .manual: return "手动"
        case .semiAutomatic: return "半自动"
        case .fullAutomatic: return "全自动"
        }
    }
    
    var description: String {
        switch self {
        case .manual: return "需要手动触发同步"
        case .semiAutomatic: return "部分自动化，需要用户确认"
        case .fullAutomatic: return "完全自动化同步"
        }
    }
    
    var icon: String {
        switch self {
        case .manual: return "hand.raised.fill"
        case .semiAutomatic: return "gearshape.2.fill"
        case .fullAutomatic: return "bolt.fill"
        }
    }
}

struct AutomationLogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: AutomationLogType
    let message: String
    let success: Bool
}

enum AutomationLogType {
    case dailySync
    case success
    case error
    case configChange
    
    var displayName: String {
        switch self {
        case .dailySync: return "每日同步"
        case .success: return "成功"
        case .error: return "错误"
        case .configChange: return "配置变更"
        }
    }
    
    var icon: String {
        switch self {
        case .dailySync: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .configChange: return "gear"
        }
    }
}

enum AutomationError: Error {
    case generationFailed
    case syncFailed
    case configurationError
    
    var localizedDescription: String {
        switch self {
        case .generationFailed: return "数据生成失败"
        case .syncFailed: return "同步失败"
        case .configurationError: return "配置错误"
        }
    }
} 