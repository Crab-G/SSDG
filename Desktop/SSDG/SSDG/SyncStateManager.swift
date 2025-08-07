//
//  SyncStateManager.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation
import SwiftUI

// MARK: - 同步状态管理器
@MainActor
class SyncStateManager: ObservableObject {
    
    // 单例实例
    static let shared = SyncStateManager()
    
    // UserDefaults键名
    private let lastSyncDateKey = "lastSyncDate"
    private let todaySyncStatusKey = "todaySyncStatus"
    private let todaySleepDataKey = "todaySleepData"
    private let todayStepsDataKey = "todayStepsData"
    private let currentUserKey = "currentUser"
    private let dataModeKey = "dataMode"
    private let historicalDataKey = "historicalData"
    private let historicalDataStatusKey = "historicalDataStatus"
    private let historicalDataGeneratedDateKey = "historicalDataGeneratedDate"
    
    // 发布属性
    @Published var lastSyncDate: Date?
    @Published var todaySyncStatus: SyncStatus = .notSynced
    @Published var todaySleepData: SleepData?
    @Published var todayStepsData: StepsData?
    @Published var currentUser: VirtualUser?
    @Published var dataMode: DataMode = .simple
    
    // 历史数据相关属性
    @Published var historicalSleepData: [SleepData] = []
    @Published var historicalStepsData: [StepsData] = []
    @Published var historicalDataStatus: HistoricalDataStatus = .notGenerated
    @Published var historicalDataGeneratedDate: Date?
    
    private init() {
        loadState()
    }
    
    // MARK: - 状态加载
    private func loadState() {
        // 加载最后同步时间
        if let lastSyncTimestamp = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date {
            lastSyncDate = lastSyncTimestamp
        }
        
        // 加载今日同步状态
        if let statusRawValue = UserDefaults.standard.object(forKey: todaySyncStatusKey) as? String {
            todaySyncStatus = SyncStatus(rawValue: statusRawValue) ?? .notSynced
        }
        
        // 加载今日睡眠数据
        if let sleepDataData = UserDefaults.standard.data(forKey: todaySleepDataKey) {
            todaySleepData = decodeSleepData(from: sleepDataData)
        }
        
        // 加载今日步数数据
        if let stepsDataData = UserDefaults.standard.data(forKey: todayStepsDataKey) {
            todayStepsData = decodeStepsData(from: stepsDataData)
        }
        
        // 加载当前用户
        if let userDataData = UserDefaults.standard.data(forKey: currentUserKey) {
            currentUser = decodeUser(from: userDataData)
        }
        
        // 加载数据模式
        if let dataModeRawValue = UserDefaults.standard.object(forKey: dataModeKey) as? String {
            dataMode = DataMode(rawValue: dataModeRawValue) ?? .simple
        }
        
        // 加载历史数据
        loadHistoricalData()
        
        // 检查是否是新的一天
        checkForNewDay()
    }
    
    // MARK: - 状态保存
    private func saveState() {
        UserDefaults.standard.set(lastSyncDate, forKey: lastSyncDateKey)
        UserDefaults.standard.set(todaySyncStatus.rawValue, forKey: todaySyncStatusKey)
        
        // 保存今日睡眠数据
        if let sleepData = todaySleepData {
            let sleepDataData = encodeSleepData(sleepData)
            UserDefaults.standard.set(sleepDataData, forKey: todaySleepDataKey)
        }
        
        // 保存今日步数数据
        if let stepsData = todayStepsData {
            let stepsDataData = encodeStepsData(stepsData)
            UserDefaults.standard.set(stepsDataData, forKey: todayStepsDataKey)
        }
        
        // 保存当前用户
        if let user = currentUser {
            let userData = encodeUser(user)
            UserDefaults.standard.set(userData, forKey: currentUserKey)
        }
        
        // 保存数据模式
        UserDefaults.standard.set(dataMode.rawValue, forKey: dataModeKey)
        
        // 保存历史数据
        saveHistoricalData()
    }
    
    // MARK: - 公共方法
    func updateSyncStatus(_ status: SyncStatus) {
        todaySyncStatus = status
        saveState()
    }
    
    func updateSyncData(sleepData: SleepData, stepsData: StepsData) {
        todaySleepData = sleepData
        todayStepsData = stepsData
        lastSyncDate = Date()
        todaySyncStatus = .notSynced  // 生成数据后状态应该是未同步
        
        // 数据更新完成
        
        // 注意：这里不立即添加到历史记录，只有在成功同步后才添加
        
        saveState()
    }
    
    // 重载方法：只更新步数数据
    func updateStepsData(_ stepsData: StepsData) {
        todayStepsData = stepsData
        lastSyncDate = Date()
        todaySyncStatus = .notSynced
        
        // 步数数据更新完成
        
        saveState()
    }
    
    // 新增：同步成功后才添加到历史记录
    func markSyncedAndAddToHistory(sleepData: SleepData, stepsData: StepsData) {
        todaySyncStatus = .synced
        lastSyncDate = Date()
        
        // 添加到历史记录（避免重复添加）
        if !historicalSleepData.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: sleepData.date) }) {
            historicalSleepData.append(sleepData)
        }
        
        if !historicalStepsData.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: stepsData.date) }) {
            historicalStepsData.append(stepsData)
        }
        
        // 清理过期的历史数据
        cleanupOldHistoricalData()
        
        saveState()
    }
    
    func updateUser(_ user: VirtualUser) {
        currentUser = user
        // 用户更换时，清空历史数据，需要重新生成
        clearHistoricalData()
        saveState()
    }
    
    func updateDataMode(_ mode: DataMode) {
        dataMode = mode
        saveState()
    }
    
    func checkForNewDay() {
        let calendar = Calendar.current
        let today = Date()
        
        // 如果没有同步日期，设置为未同步
        guard let lastSync = lastSyncDate else {
            todaySyncStatus = .notSynced
            return
        }
        
        // 检查是否是新的一天
        if !calendar.isDate(lastSync, inSameDayAs: today) {
            // 检查今日数据是否是昨天的
            var shouldClearTodayData = false
            if let sleepData = todaySleepData, !calendar.isDate(sleepData.date, inSameDayAs: today) {
                shouldClearTodayData = true
            }
            if let stepsData = todayStepsData, !calendar.isDate(stepsData.date, inSameDayAs: today) {
                shouldClearTodayData = true
            }
            
            // 只有在数据确实是过期的情况下才清空
            if shouldClearTodayData {
                todaySleepData = nil
                todayStepsData = nil
            }
            
            // 新的一天，重置同步状态
            todaySyncStatus = .notSynced
            
            // 清理过期的历史数据
            cleanupOldHistoricalData()
            
            saveState()
        }
    }
    
    func resetTodayData() {
        todaySyncStatus = .notSynced
        todaySleepData = nil
        todayStepsData = nil
        saveState()
    }
    
    // MARK: - 历史数据管理
    func updateHistoricalDataStatus(_ status: HistoricalDataStatus) {
        historicalDataStatus = status
        if status == .generated {
            historicalDataGeneratedDate = Date()
        }
        saveState()
    }
    
    func updateHistoricalData(sleepData: [SleepData], stepsData: [StepsData]) {
        historicalSleepData = sleepData
        historicalStepsData = stepsData
        historicalDataStatus = .generated
        historicalDataGeneratedDate = Date()
        saveState()
    }
    
    func updateTodaySleepData(_ sleepData: SleepData) {
        // 更新今日睡眠数据
        todaySleepData = sleepData
        
        // 同时更新历史数据中的今日睡眠数据
        let calendar = Calendar.current
        let sleepDate = calendar.startOfDay(for: sleepData.date)
        
        // 🔥 修复：使用睡眠数据的日期而不是今天的日期
        // 移除相同日期的旧睡眠数据（如果有）
        historicalSleepData.removeAll { 
            calendar.isDate($0.date, inSameDayAs: sleepDate) 
        }
        
        // 添加新的睡眠数据
        historicalSleepData.append(sleepData)
        
        // 按日期排序并去重
        historicalSleepData.sort { $0.date < $1.date }
        
        // 🔥 额外的去重保护：确保没有重复的日期
        var uniqueSleepData: [SleepData] = []
        var seenDates: Set<Date> = []
        
        for sleep in historicalSleepData {
            let startOfDay = calendar.startOfDay(for: sleep.date)
            if !seenDates.contains(startOfDay) {
                seenDates.insert(startOfDay)
                uniqueSleepData.append(sleep)
            }
        }
        
        historicalSleepData = uniqueSleepData
        
        saveState()
    }
    
    func updateTodayStepsData(_ stepsData: StepsData) {
        // 更新今日步数数据
        todayStepsData = stepsData
        saveState()
    }
    
    func clearHistoricalData() {
        historicalSleepData = []
        historicalStepsData = []
        historicalDataStatus = .notGenerated
        historicalDataGeneratedDate = nil
        saveState()
    }
    
    func shouldGenerateHistoricalData() -> Bool {
        // 如果没有历史数据，或者用户发生了变化，需要生成
        return historicalDataStatus == .notGenerated || 
               historicalSleepData.isEmpty || 
               historicalStepsData.isEmpty
    }
    
    private func loadHistoricalData() {
        // 加载历史数据状态
        if let statusRawValue = UserDefaults.standard.object(forKey: historicalDataStatusKey) as? String {
            historicalDataStatus = HistoricalDataStatus(rawValue: statusRawValue) ?? .notGenerated
        }
        
        // 加载历史数据生成时间
        if let generatedDate = UserDefaults.standard.object(forKey: historicalDataGeneratedDateKey) as? Date {
            historicalDataGeneratedDate = generatedDate
        }
        
        // 加载历史数据
        if let historicalDataData = UserDefaults.standard.data(forKey: historicalDataKey) {
            if let decoded = decodeHistoricalData(from: historicalDataData) {
                historicalSleepData = decoded.sleepData
                historicalStepsData = decoded.stepsData
            }
        }
    }
    
    private func saveHistoricalData() {
        // 保存历史数据状态
        UserDefaults.standard.set(historicalDataStatus.rawValue, forKey: historicalDataStatusKey)
        
        // 保存历史数据生成时间
        UserDefaults.standard.set(historicalDataGeneratedDate, forKey: historicalDataGeneratedDateKey)
        
        // 保存历史数据
        if !historicalSleepData.isEmpty && !historicalStepsData.isEmpty {
            let encoded = encodeHistoricalData(sleepData: historicalSleepData, stepsData: historicalStepsData)
            UserDefaults.standard.set(encoded, forKey: historicalDataKey)
        }
    }
    
    // MARK: - 编码解码方法
    private func encodeSleepData(_ sleepData: SleepData) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let codableSleepData = CodableSleepData(
            date: sleepData.date,
            bedTime: sleepData.bedTime,
            wakeTime: sleepData.wakeTime,
            totalSleepHours: sleepData.totalSleepHours
        )
        
        do {
            return try encoder.encode(codableSleepData)
        } catch {
            print("❌ 睡眠数据编码失败: \(error.localizedDescription)")
            // 返回空数据而不是崩溃，但记录错误
            return Data()
        }
    }
    
    private func decodeSleepData(from data: Data) -> SleepData? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let codableSleepData = try decoder.decode(CodableSleepData.self, from: data)
            // 创建简化的睡眠数据（不包含详细阶段）
            return SleepData(
                date: codableSleepData.date,
                bedTime: codableSleepData.bedTime,
                wakeTime: codableSleepData.wakeTime,
                sleepStages: [] // 简化存储，不保存详细阶段
            )
        } catch {
            print("❌ 睡眠数据解码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func encodeStepsData(_ stepsData: StepsData) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let codableStepsData = CodableStepsData(
            date: stepsData.date,
            totalSteps: stepsData.totalSteps
        )
        
        do {
            return try encoder.encode(codableStepsData)
        } catch {
            print("❌ 步数数据编码失败: \(error.localizedDescription)")
            return Data()
        }
    }
    
    private func decodeStepsData(from data: Data) -> StepsData? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let codableStepsData = try decoder.decode(CodableStepsData.self, from: data)
            // 使用扩展方法创建步数数据，保留totalSteps
            return StepsData(
                date: codableStepsData.date,
                totalSteps: codableStepsData.totalSteps
            )
        } catch {
            print("❌ 步数数据解码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func encodeUser(_ user: VirtualUser) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let codableUser = CodableUser(
            id: user.id,
            age: user.age,
            gender: user.gender.rawValue,
            height: user.height,
            weight: user.weight,
            sleepBaseline: user.sleepBaseline,
            stepsBaseline: user.stepsBaseline,
            createdAt: user.createdAt,
            deviceModel: user.deviceModel,
            deviceSerialNumber: user.deviceSerialNumber,
            deviceUUID: user.deviceUUID
        )
        
        do {
            return try encoder.encode(codableUser)
        } catch {
            print("❌ 用户数据编码失败: \(error.localizedDescription)")
            return Data()
        }
    }
    
    private func decodeUser(from data: Data) -> VirtualUser? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let codableUser = try decoder.decode(CodableUser.self, from: data)
            guard let gender = Gender(rawValue: codableUser.gender) else {
                print("❌ 用户数据解码失败: 无效的性别值 \(codableUser.gender)")
                return nil
            }
            
            // 如果旧数据没有设备信息，生成默认的
            let deviceModel = codableUser.deviceModel ?? "iPhone 14"
            let deviceSerialNumber = codableUser.deviceSerialNumber ?? "F2L\(codableUser.id.prefix(5).uppercased())"
            let deviceUUID = codableUser.deviceUUID ?? UUID().uuidString
            
            return VirtualUser(
                id: codableUser.id,
                age: codableUser.age,
                gender: gender,
                height: codableUser.height,
                weight: codableUser.weight,
                sleepBaseline: codableUser.sleepBaseline,
                stepsBaseline: codableUser.stepsBaseline,
                createdAt: codableUser.createdAt,
                deviceModel: deviceModel,
                deviceSerialNumber: deviceSerialNumber,
                deviceUUID: deviceUUID
            )
        } catch {
            print("❌ 用户数据解码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 历史数据编码解码
    private func encodeHistoricalData(sleepData: [SleepData], stepsData: [StepsData]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let codableHistoricalData = CodableHistoricalData(
            sleepData: sleepData.map { encodeSleepDataForHistorical($0) },
            stepsData: stepsData.map { encodeStepsDataForHistorical($0) }
        )
        
        do {
            return try encoder.encode(codableHistoricalData)
        } catch {
            print("❌ 历史数据编码失败: \(error.localizedDescription)")
            return Data()
        }
    }
    
    private func decodeHistoricalData(from data: Data) -> (sleepData: [SleepData], stepsData: [StepsData])? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let codableHistoricalData = try decoder.decode(CodableHistoricalData.self, from: data)
            
            let sleepData = codableHistoricalData.sleepData.compactMap { decodeSleepDataFromHistorical($0) }
            let stepsData = codableHistoricalData.stepsData.compactMap { decodeStepsDataFromHistorical($0) }
            
            return (sleepData, stepsData)
        } catch {
            print("❌ 历史数据解码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func encodeSleepDataForHistorical(_ sleepData: SleepData) -> CodableSleepData {
        return CodableSleepData(
            date: sleepData.date,
            bedTime: sleepData.bedTime,
            wakeTime: sleepData.wakeTime,
            totalSleepHours: sleepData.totalSleepHours
        )
    }
    
    private func decodeSleepDataFromHistorical(_ codableSleepData: CodableSleepData) -> SleepData? {
        return SleepData(
            date: codableSleepData.date,
            bedTime: codableSleepData.bedTime,
            wakeTime: codableSleepData.wakeTime,
            sleepStages: [] // 历史数据不存储详细阶段
        )
    }
    
    private func encodeStepsDataForHistorical(_ stepsData: StepsData) -> CodableStepsData {
        return CodableStepsData(
            date: stepsData.date,
            totalSteps: stepsData.totalSteps
        )
    }
    
    private func decodeStepsDataFromHistorical(_ codableStepsData: CodableStepsData) -> StepsData? {
        return StepsData(
            date: codableStepsData.date,
            totalSteps: codableStepsData.totalSteps
        )
    }

    // MARK: - 将今日数据添加到历史记录
    private func addTodayDataToHistory(sleepData: SleepData, stepsData: StepsData) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 检查今日数据是否已经存在于历史记录中
        let existingSleepIndex = historicalSleepData.firstIndex { calendar.isDate($0.date, inSameDayAs: today) }
        let existingStepsIndex = historicalStepsData.firstIndex { calendar.isDate($0.date, inSameDayAs: today) }
        
        // 更新或添加睡眠数据
        if let index = existingSleepIndex {
            historicalSleepData[index] = sleepData
        } else {
            historicalSleepData.append(sleepData)
        }
        
        // 更新或添加步数数据
        if let index = existingStepsIndex {
            historicalStepsData[index] = stepsData
        } else {
            historicalStepsData.append(stepsData)
        }
        
        // 对历史数据按日期排序
        historicalSleepData.sort { $0.date < $1.date }
        historicalStepsData.sort { $0.date < $1.date }
        
        // 保持历史数据在合理范围内（最多保留120天）
        let maxHistoryDays = 120
        if historicalSleepData.count > maxHistoryDays {
            historicalSleepData.removeFirst(historicalSleepData.count - maxHistoryDays)
        }
        if historicalStepsData.count > maxHistoryDays {
            historicalStepsData.removeFirst(historicalStepsData.count - maxHistoryDays)
        }
        
        print("✅ 今日数据已添加到历史记录")
        print("   历史睡眠数据: \(historicalSleepData.count) 天")
        print("   历史步数数据: \(historicalStepsData.count) 天")
    }
    
    // MARK: - 用户管理方法
    func updateCurrentUser(_ user: VirtualUser) {
        currentUser = user
        saveState()
        print("👤 当前用户已更新: \(user.age)岁\(user.gender.displayName) (ID: \(String(user.id.prefix(8))))")
    }
    
    // MARK: - 状态查询方法
    func isTodaySynced() -> Bool {
        return todaySyncStatus == .synced
    }
    
    func isTodayGenerated() -> Bool {
        return todaySleepData != nil && todayStepsData != nil
    }
    
    // MARK: - 计算属性 - 最近数据
    var recentSleepData: [SleepData] {
        return Array(historicalSleepData.suffix(7))
    }
    
    var recentStepsData: [StepsData] {
        return Array(historicalStepsData.suffix(7))
    }
    
    // MARK: - 清理过期历史数据
    func cleanupOldHistoricalData() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -120, to: Date())!
        
        historicalSleepData.removeAll { $0.date < cutoffDate }
        historicalStepsData.removeAll { $0.date < cutoffDate }
        
        saveState()
    }
}

// MARK: - 同步状态枚举
enum SyncStatus: String, CaseIterable {
    case notSynced = "notSynced"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .notSynced:
            return "未同步"
        case .syncing:
            return "同步中"
        case .synced:
            return "已同步"
        case .failed:
            return "同步失败"
        }
    }
    
    var color: Color {
        switch self {
        case .notSynced:
            return .gray
        case .syncing:
            return .orange
        case .synced:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - 可编码的数据模型
private struct CodableSleepData: Codable {
    let date: Date
    let bedTime: Date
    let wakeTime: Date
    let totalSleepHours: Double
}

private struct CodableStepsData: Codable {
    let date: Date
    let totalSteps: Int
}

private struct CodableUser: Codable {
    let id: String
    let age: Int
    let gender: String
    let height: Double
    let weight: Double
    let sleepBaseline: Double
    let stepsBaseline: Int
    let createdAt: Date
    
    // 设备信息（可选，兼容旧版本）
    let deviceModel: String?
    let deviceSerialNumber: String?
    let deviceUUID: String?
}

private struct CodableHistoricalData: Codable {
    let sleepData: [CodableSleepData]
    let stepsData: [CodableStepsData]
}

// MARK: - 历史数据状态枚举
enum HistoricalDataStatus: String, CaseIterable {
    case notGenerated = "notGenerated"
    case generating = "generating"
    case generated = "generated"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .notGenerated:
            return "未生成"
        case .generating:
            return "生成中"
        case .generated:
            return "已生成"
        case .failed:
            return "生成失败"
        }
    }
    
    var description: String {
        switch self {
        case .notGenerated:
            return "尚未生成历史数据"
        case .generating:
            return "正在生成历史数据..."
        case .generated:
            return "历史数据已生成"
        case .failed:
            return "历史数据生成失败"
        }
    }
}

// MARK: - 简化的步数数据扩展
extension StepsData {
    init(date: Date, totalSteps: Int) {
        self.date = date
        self.hourlySteps = [HourlySteps(
            hour: 12,
            steps: totalSteps,
            startTime: date,
            endTime: date.addingTimeInterval(3600)
        )]
        self.stepsIntervals = [] // 简化版本不包含精细间隔
    }
}

// MARK: - 简化的睡眠数据扩展
extension SleepData {
    init(date: Date, bedTime: Date, wakeTime: Date, totalSleepHours: Double) {
        self.date = date
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        // 创建简化的睡眠阶段
        self.sleepStages = [SleepStage(
            stage: .light,
            startTime: bedTime,
            endTime: wakeTime
        )]
    }
}