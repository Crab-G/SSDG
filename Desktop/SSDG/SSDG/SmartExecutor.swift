import Foundation
import SwiftUI

/// 智能执行器 - 负责执行预缓存的数据导入计划
@MainActor
class SmartExecutor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var todaySchedule: DailyDataPlan?
    @Published var executionStatus: ExecutionStatus = .idle
    @Published var completedBatches: Int = 0
    @Published var totalBatches: Int = 0
    @Published var lastExecutionTime: Date?
    @Published var nextScheduledTime: Date?
    @Published var executionLog: [ExecutionLogEntry] = []
    
    // MARK: - Dependencies
    private let healthKitManager = HealthKitManager.shared
    private let storageManager = OfflineStorageManager.shared
    private let preCacheSystem = WeeklyPreCacheSystem.shared
    private let notificationManager = NotificationManager.shared
    
    // MARK: - Timers
    private var sleepImportTimer: Timer?
    private var stepBatchTimers: [Timer] = []
    private var statusCheckTimer: Timer?
    
    // MARK: - Execution State
    private var currentExecutions: Set<UUID> = []
    private var failedBatches: [StepBatch] = []
    private var retryAttempts: [UUID: Int] = [:]
    
    // MARK: - Constants
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 1800 // 30分钟
    
    // MARK: - Singleton
    static let shared = SmartExecutor()
    
    private init() {
        setupStatusMonitoring()
        loadTodaySchedule()
    }
    
    // MARK: - 初始化和清理
    
    /// 设置状态监控
    private func setupStatusMonitoring() {
        // 每5分钟检查一次执行状态
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                await self.checkExecutionStatus()
            }
        }
        
        print("📊 执行状态监控已启动")
    }
    
    /// 清理资源
    private func cleanup() {
        sleepImportTimer?.invalidate()
        stepBatchTimers.forEach { $0.invalidate() }
        statusCheckTimer?.invalidate()
    }
    
    /// 加载今日执行计划
    private func loadTodaySchedule() {
        Task {
            await refreshTodaySchedule()
        }
    }
    
    // MARK: - 执行计划管理
    
    /// 刷新今日执行计划
    func refreshTodaySchedule() async {
        if let todayPlan = preCacheSystem.getTodayPlan() {
            todaySchedule = todayPlan
            totalBatches = todayPlan.stepDistribution.distributionBatches.count
            
            // 启动今日执行
            await startTodayExecution()
            
            print("📅 今日执行计划已加载")
            print("   睡眠导入: \(todayPlan.importSchedule.sleepImportTime?.formatted() ?? "无")")
            print("   步数批次: \(totalBatches)个")
        } else {
            print("⚠️ 未找到今日数据计划")
            executionStatus = .noSchedule
        }
    }
    
    /// 启动今日执行
    private func startTodayExecution() async {
        guard let schedule = todaySchedule else { return }
        
        executionStatus = .scheduled
        
        // 调度睡眠数据导入
        scheduleSleepDataImport(schedule.importSchedule)
        
        // 调度步数批次执行
        scheduleStepBatchExecution(schedule.importSchedule)
        
        // 计算下次执行时间
        updateNextScheduledTime()
        
        addLogEntry("📅 今日执行计划已启动", type: .info)
        
        // 发送通知
        await notificationManager.sendDailySyncStartNotification()
    }
    
    // MARK: - 睡眠数据导入
    
    /// 调度睡眠数据导入
    private func scheduleSleepDataImport(_ schedule: ImportSchedule) {
        guard let sleepImportTime = schedule.sleepImportTime else {
            print("ℹ️ 今日无睡眠数据需要导入")
            return
        }
        
        let delay = sleepImportTime.timeIntervalSinceNow
        
        if delay > 0 {
            sleepImportTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                Task { @MainActor in
                    await self.executeSleepDataImport()
                }
            }
            print("⏰ 睡眠数据导入已调度: \(sleepImportTime.formatted())")
        } else {
            // 如果时间已过，立即执行
            print("🚨 睡眠导入时间已过，立即执行")
            Task {
                await executeSleepDataImport()
            }
        }
    }
    
    /// 执行睡眠数据导入
    private func executeSleepDataImport() async {
        guard let sleepData = todaySchedule?.sleepData else {
            addLogEntry("❌ 睡眠数据导入失败: 未找到睡眠数据", type: .error)
            return
        }
        
        addLogEntry("🌅 开始执行睡眠数据导入...", type: .info)
        executionStatus = .sleepImporting
        
        do {
            let success = await healthKitManager.writePersonalizedSleepData(sleepData)
            
            if success {
                executionStatus = .sleepImported
                lastExecutionTime = Date()
                
                addLogEntry("✅ 睡眠数据导入成功 (\(String(format: "%.1f", sleepData.duration))小时)", type: .success)
                
                // 发送成功通知
                await notificationManager.sendDailySyncSuccessNotification()
                
            } else {
                addLogEntry("❌ 睡眠数据导入失败", type: .error)
                
                // 安排重试
                scheduleSleepDataRetry()
            }
        }
        
        updateNextScheduledTime()
    }
    
    /// 安排睡眠数据重试
    private func scheduleSleepDataRetry() {
        Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { _ in
            Task { @MainActor in
                self.addLogEntry("🔄 重试睡眠数据导入...", type: .info)
                await self.executeSleepDataImport()
            }
        }
        
        addLogEntry("⏰ 已安排30分钟后重试睡眠数据导入", type: .warning)
    }
    
    // MARK: - 步数批次执行
    
    /// 调度步数批次执行
    private func scheduleStepBatchExecution(_ schedule: ImportSchedule) {
        // 清理旧的定时器
        stepBatchTimers.forEach { $0.invalidate() }
        stepBatchTimers.removeAll()
        
        _ = Date() // 修复：明确标记未使用的变量
        var scheduledCount = 0
        var immediateCount = 0
        
        for batchTime in schedule.stepBatchTimes {
            let delay = batchTime.timeIntervalSinceNow
            
            if delay > 0 {
                let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                    Task { @MainActor in
                        await self.executeStepBatch(at: batchTime)
                    }
                }
                stepBatchTimers.append(timer)
                scheduledCount += 1
            } else {
                // 过期的批次立即执行
                Task {
                    await executeStepBatch(at: batchTime)
                }
                immediateCount += 1
            }
        }
        
        print("⏰ 步数批次调度完成")
        print("   计划执行: \(scheduledCount)个")
        print("   立即执行: \(immediateCount)个")
        
        if scheduledCount > 0 {
            addLogEntry("⏰ 已调度\(scheduledCount)个步数批次", type: .info)
        }
    }
    
    /// 执行步数批次
    private func executeStepBatch(at time: Date) async {
        guard let plan = todaySchedule?.stepDistribution,
              let batch = findBatch(at: time, in: plan.distributionBatches) else {
            addLogEntry("⚠️ 未找到对应时间的步数批次: \(time.formatted(date: .omitted, time: .shortened))", type: .warning)
            return
        }
        
        // 检查是否已在执行
        guard !currentExecutions.contains(batch.id) else {
            print("⚠️ 批次已在执行中: \(batch.id)")
            return
        }
        
        currentExecutions.insert(batch.id)
        
        let batchDescription = "\(batch.timeDescription): \(batch.steps)步"
        addLogEntry("🚶‍♂️ 执行步数批次: \(batchDescription)", type: .info)
        
        executionStatus = .stepImporting
        
        do {
            let success = await executeStepBatchWithRetry(batch)
            
            if success {
                completedBatches += 1
                lastExecutionTime = Date()
                
                addLogEntry("✅ 步数批次完成: \(batchDescription)", type: .success)
                
                // 检查是否全部完成
                if completedBatches >= totalBatches {
                    await completeAllExecutions()
                }
            } else {
                failedBatches.append(batch)
                addLogEntry("❌ 步数批次失败: \(batchDescription)", type: .error)
            }
        }
        
        currentExecutions.remove(batch.id)
        updateNextScheduledTime()
    }
    
    /// 执行步数批次（带重试）
    private func executeStepBatchWithRetry(_ batch: StepBatch) async -> Bool {
        let attemptCount = retryAttempts[batch.id, default: 0]
        
        if attemptCount >= maxRetryAttempts {
            addLogEntry("❌ 步数批次达到最大重试次数: \(batch.batchDescription)", type: .error)
            return false
        }
        
        let success = await healthKitManager.writeStepBatch(batch)
        
        if !success && attemptCount < maxRetryAttempts {
            retryAttempts[batch.id] = attemptCount + 1
            
            // 安排重试
            Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { _ in
                Task { @MainActor in
                    await self.executeStepBatch(at: batch.scheduledTime)
                }
            }
            
            addLogEntry("⏰ 步数批次将在30分钟后重试 (第\(attemptCount + 1)次)", type: .warning)
        }
        
        return success
    }
    
    /// 查找指定时间的批次
    private func findBatch(at time: Date, in batches: [StepBatch]) -> StepBatch? {
        return batches.first { batch in
            abs(batch.scheduledTime.timeIntervalSince(time)) < 60 // 1分钟误差
        }
    }
    
    // MARK: - 执行完成处理
    
    /// 完成所有执行任务
    private func completeAllExecutions() async {
        executionStatus = .completed
        
        let successRate = Double(completedBatches) / Double(totalBatches) * 100
        
        addLogEntry("🎉 今日所有数据导入完成", type: .success)
        addLogEntry("📊 执行统计: \(completedBatches)/\(totalBatches) (\(String(format: "%.1f", successRate))%)", type: .info)
        
        if !failedBatches.isEmpty {
            addLogEntry("⚠️ 失败批次: \(failedBatches.count)个", type: .warning)
        }
        
        // 发送完成通知
        await notificationManager.sendDailySyncSuccessNotification()
        
        // 清理状态
        cleanupExecutionState()
    }
    
    /// 清理执行状态
    private func cleanupExecutionState() {
        stepBatchTimers.forEach { $0.invalidate() }
        stepBatchTimers.removeAll()
        currentExecutions.removeAll()
        retryAttempts.removeAll()
        
        print("🧹 执行状态已清理")
    }
    
    // MARK: - 状态监控
    
    /// 检查执行状态
    private func checkExecutionStatus() async {
        // 检查是否需要切换到明日计划
        let calendar = Calendar.current
        if let schedule = todaySchedule,
           !calendar.isDateInToday(schedule.date) {
            
            addLogEntry("📅 切换到新的一天", type: .info)
            await refreshTodaySchedule()
        }
        
        // 检查失败的重试
        checkFailedRetries()
        
        // 更新下次执行时间
        updateNextScheduledTime()
    }
    
    /// 检查失败的重试
    private func checkFailedRetries() {
        _ = Date() // 修复：明确标记未使用的变量
        
        for batch in failedBatches {
            let attemptCount = retryAttempts[batch.id, default: 0]
            
            if attemptCount < maxRetryAttempts {
                let nextRetryTime = (lastExecutionTime ?? Date()).addingTimeInterval(retryDelay)
                
                if Date() >= nextRetryTime {
                    Task {
                        await executeStepBatch(at: batch.scheduledTime)
                    }
                }
            }
        }
    }
    
    /// 更新下次执行时间
    private func updateNextScheduledTime() {
        guard let schedule = todaySchedule else {
            nextScheduledTime = nil
            return
        }
        
        let now = Date()
        var upcomingTimes: [Date] = []
        
        // 添加睡眠导入时间
        if let sleepTime = schedule.importSchedule.sleepImportTime,
           sleepTime > now {
            upcomingTimes.append(sleepTime)
        }
        
        // 添加步数批次时间
        upcomingTimes.append(contentsOf: schedule.importSchedule.stepBatchTimes.filter { $0 > now })
        
        nextScheduledTime = upcomingTimes.min()
    }
    
    // MARK: - 日志管理
    
    /// 添加日志条目
    private func addLogEntry(_ message: String, type: LogEntryType) {
        let entry = ExecutionLogEntry(
            timestamp: Date(),
            message: message,
            type: type
        )
        
        executionLog.append(entry)
        
        // 限制日志数量
        if executionLog.count > 100 {
            executionLog.removeFirst(executionLog.count - 100)
        }
        
        print("\(type.emoji) \(message)")
    }
    
    /// 清理日志
    func clearLog() {
        executionLog.removeAll()
        addLogEntry("🧹 执行日志已清理", type: .info)
    }
    
    /// 导出日志
    func exportLog() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        return executionLog.map { entry in
            "[\(formatter.string(from: entry.timestamp))] \(entry.type.emoji) \(entry.message)"
        }.joined(separator: "\n")
    }
    
    // MARK: - 手动控制
    
    /// 手动执行今日剩余任务
    func executeRemainingTasks() async {
        guard let schedule = todaySchedule else {
            addLogEntry("❌ 无今日执行计划", type: .error)
            return
        }
        
        addLogEntry("🔄 手动执行剩余任务", type: .info)
        
        let now = Date()
        
        // 执行睡眠数据（如果尚未执行）
        if let sleepTime = schedule.importSchedule.sleepImportTime,
           sleepTime <= now,
           executionStatus != .sleepImported {
            await executeSleepDataImport()
        }
        
        // 执行所有未完成的步数批次
        for batchTime in schedule.importSchedule.stepBatchTimes {
            if batchTime <= now {
                await executeStepBatch(at: batchTime)
            }
        }
    }
    
    /// 手动重试失败的批次
    func retryFailedBatches() async {
        guard !failedBatches.isEmpty else {
            addLogEntry("ℹ️ 无失败批次需要重试", type: .info)
            return
        }
        
        addLogEntry("🔄 手动重试失败批次 (\(failedBatches.count)个)", type: .info)
        
        let batchesToRetry = failedBatches
        failedBatches.removeAll()
        
        for batch in batchesToRetry {
            retryAttempts[batch.id] = 0 // 重置重试计数
            await executeStepBatch(at: batch.scheduledTime)
        }
    }
    
    /// 跳过今日执行
    func skipTodayExecution() {
        cleanup()
        executionStatus = .skipped
        addLogEntry("⏭️ 已跳过今日执行", type: .warning)
    }
    
    // MARK: - 统计信息
    
    /// 获取执行统计
    func getExecutionStats() -> ExecutionStats {
        let successRate = totalBatches > 0 ? Double(completedBatches) / Double(totalBatches) : 0.0
        
        return ExecutionStats(
            totalBatches: totalBatches,
            completedBatches: completedBatches,
            failedBatches: failedBatches.count,
            successRate: successRate,
            executionStatus: executionStatus,
            lastExecutionTime: lastExecutionTime,
            nextScheduledTime: nextScheduledTime,
            logEntryCount: executionLog.count
        )
    }
}

// MARK: - 数据结构

/// 执行状态
enum ExecutionStatus: String, Codable {
    case idle = "idle"
    case noSchedule = "noSchedule"
    case scheduled = "scheduled"
    case sleepImporting = "sleepImporting"
    case sleepImported = "sleepImported"
    case stepImporting = "stepImporting"
    case completed = "completed"
    case skipped = "skipped"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .noSchedule: return "无计划"
        case .scheduled: return "已调度"
        case .sleepImporting: return "导入睡眠数据"
        case .sleepImported: return "睡眠已导入"
        case .stepImporting: return "导入步数数据"
        case .completed: return "全部完成"
        case .skipped: return "已跳过"
        case .error: return "执行错误"
        }
    }
    
    var emoji: String {
        switch self {
        case .idle: return "😴"
        case .noSchedule: return "📭"
        case .scheduled: return "⏰"
        case .sleepImporting: return "🌙"
        case .sleepImported: return "✅"
        case .stepImporting: return "🚶‍♂️"
        case .completed: return "🎉"
        case .skipped: return "⏭️"
        case .error: return "❌"
        }
    }
}

/// 日志条目类型
enum LogEntryType: String, Codable {
    case info = "info"
    case success = "success"
    case warning = "warning"
    case error = "error"
    
    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// 执行日志条目
struct ExecutionLogEntry: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogEntryType
    
    enum CodingKeys: String, CodingKey {
        case timestamp, message, type
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

/// 执行统计
struct ExecutionStats {
    let totalBatches: Int
    let completedBatches: Int
    let failedBatches: Int
    let successRate: Double
    let executionStatus: ExecutionStatus
    let lastExecutionTime: Date?
    let nextScheduledTime: Date?
    let logEntryCount: Int
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var remainingBatches: Int {
        return totalBatches - completedBatches
    }
}

// MARK: - HealthKitManager Extension

extension HealthKitManager {
    /// 写入步数批次数据
    func writeStepBatch(_ batch: StepBatch) async -> Bool {
        // 将步数分布到批次时间段内
        let stepIncrements = distributeStepsInBatch(batch)
        
        // 按日期分组步数增量
        let calendar = Calendar.current
        var stepsByDate: [Date: [HourlySteps]] = [:]
        
        for increment in stepIncrements {
            let date = calendar.startOfDay(for: increment.startTime)
            let hour = calendar.component(.hour, from: increment.startTime)
            
            let hourlyStep = HourlySteps(
                hour: hour,
                steps: increment.steps,
                startTime: increment.startTime,
                endTime: increment.startTime.addingTimeInterval(3600) // 1小时后
            )
            
            if stepsByDate[date] == nil {
                stepsByDate[date] = []
            }
            stepsByDate[date]?.append(hourlyStep)
        }
        
        // 为每个日期创建StepsData并写入
        var allSuccess = true
        for (date, hourlySteps) in stepsByDate {
            let stepsData = StepsData(
                date: date,
                hourlySteps: hourlySteps
            )
            
            let success = await writeStepsData([stepsData])
            if !success {
                allSuccess = false
                print("❌ 写入日期 \(date) 的步数数据失败")
            }
        }
        
        return allSuccess
    }
    
    /// 将步数批次分布为更小的增量
    private func distributeStepsInBatch(_ batch: StepBatch) -> [StepDataIncrement] {
        let incrementDuration: TimeInterval = 60 // 1分钟间隔
        let incrementCount = max(1, Int(batch.duration / incrementDuration))
        let stepsPerIncrement = batch.steps / incrementCount
        let remainderSteps = batch.steps % incrementCount
        
        var increments: [StepDataIncrement] = []
        
        for i in 0..<incrementCount {
            let startTime = batch.scheduledTime.addingTimeInterval(Double(i) * incrementDuration)
            
            // 将余数步数分配到前几个增量中
            let steps = stepsPerIncrement + (i < remainderSteps ? 1 : 0)
            
            increments.append(StepDataIncrement(
                steps: steps,
                startTime: startTime,
                activityType: batch.activityType
            ))
        }
        
        return increments
    }
}

/// 步数数据增量（内部使用）
private struct StepDataIncrement {
    let steps: Int
    let startTime: Date
    let activityType: ActivityType
} 