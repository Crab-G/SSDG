import Foundation
import SwiftUI

// MARK: - 预缓存数据结构

/// 周数据包 - 包含一周的完整数据计划
struct WeeklyDataPackage: Codable {
    let generatedDate: Date
    let userID: String
    let weekStartDate: Date
    
    let dailyPlans: [DailyDataPlan]
    
    // 统计信息
    let totalSleepHours: Double
    let totalSteps: Int
    let dataVersion: String
    
    // 计算属性不参与编码
    var id: UUID {
        return UUID() 
    }
    
    /// 获取指定日期的数据计划
    func getDailyPlan(for date: Date) -> DailyDataPlan? {
        let calendar = Calendar.current
        return dailyPlans.first { plan in
            calendar.isDate(plan.date, inSameDayAs: date)
        }
    }
    
    /// 检查数据包是否过期
    var isExpired: Bool {
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartDate) ?? Date()
        return Date() >= nextWeek
    }
    
    /// 格式化的周期描述
    var weekDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        return "\(formatter.string(from: weekStartDate)) - \(formatter.string(from: endDate))"
    }
}

/// 每日数据计划
struct DailyDataPlan: Codable {
    let date: Date
    let sleepData: SleepData?
    let stepDistribution: StepDistributionPlan
    let importSchedule: ImportSchedule
    
    // 计算属性不参与编码
    var id: UUID {
        return UUID() 
    }
    
    /// 当日是否为休息日
    var isWeekend: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // 周日或周六
    }
    
    /// 格式化的日期描述
    var dateDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 EEEE"
        return formatter.string(from: date)
    }
}

/// 步数分布计划
struct StepDistributionPlan: Codable {
    let totalSteps: Int
    let distributionBatches: [StepBatch]
    let sleepTimeReduction: SleepTimeStepReduction
    
    /// 计算平均每小时步数
    var averageStepsPerHour: Int {
        let awakeBatches = distributionBatches.filter { !$0.isDuringSleep }
        guard !awakeBatches.isEmpty else { return 0 }
        return totalSteps / awakeBatches.count
    }
    
    /// 活跃时段数量
    var activeBatchCount: Int {
        distributionBatches.filter { $0.steps > 10 }.count
    }
}

/// 步数批次
struct StepBatch: Codable {
    let scheduledTime: Date
    let steps: Int
    let duration: TimeInterval
    let activityType: ActivityType
    let priority: BatchPriority
    let isDuringSleep: Bool
    
    // 计算属性不参与编码
    var id: UUID {
        return UUID() 
    }
    
    /// 格式化的时间描述
    var timeDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: scheduledTime)
    }
    
    /// 批次描述
    var batchDescription: String {
        return "\(timeDescription): \(steps)步 (\(activityType.displayName))"
    }
}

/// 睡眠时间步数减少
struct SleepTimeStepReduction: Codable {
    let sleepStartTime: Date
    let sleepEndTime: Date
    let reducedStepBatches: [StepBatch]
    let normalStepBatches: [StepBatch]
    
    /// 睡眠期间总步数
    var sleepPeriodTotalSteps: Int {
        reducedStepBatches.reduce(0) { $0 + $1.steps }
    }
    
    /// 清醒期间总步数
    var awakePeriodTotalSteps: Int {
        normalStepBatches.reduce(0) { $0 + $1.steps }
    }
}

/// 导入时间表
struct ImportSchedule: Codable {
    let sleepImportTime: Date?
    let stepBatchTimes: [Date]
    let fallbackSchedule: [Date]
    
    /// 今日是否有睡眠数据需要导入
    var hasSleepDataToImport: Bool {
        guard let sleepImportTime = sleepImportTime else { return false }
        return sleepImportTime >= Date()
    }
    
    /// 剩余步数批次数量
    var remainingStepBatches: Int {
        let now = Date()
        return stepBatchTimes.filter { $0 > now }.count
    }
}

/// 活动类型
enum ActivityType: String, Codable, CaseIterable {
    case idle = "idle"
    case standing = "standing" 
    case walking = "walking"
    case running = "running"
    case commuting = "commuting"
    case exercise = "exercise"
    
    var displayName: String {
        switch self {
        case .idle: return "静息"
        case .standing: return "站立"
        case .walking: return "步行"
        case .running: return "跑步"
        case .commuting: return "通勤"
        case .exercise: return "运动"
        }
    }
    
    var emoji: String {
        switch self {
        case .idle: return "😴"
        case .standing: return "🧍"
        case .walking: return "🚶"
        case .running: return "🏃"
        case .commuting: return "🚇"
        case .exercise: return "💪"
        }
    }
}

/// 批次优先级
enum BatchPriority: String, Codable {
    case high = "high"
    case normal = "normal"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "高优先级"
        case .normal: return "正常"
        case .low: return "低优先级"
        }
    }
}

// MARK: - WeeklyPreCacheSystem 主系统

@MainActor
class WeeklyPreCacheSystem: ObservableObject {
    // MARK: - Published Properties
    @Published var currentWeekPackage: WeeklyDataPackage?
    @Published var nextWeekPackage: WeeklyDataPackage?
    @Published var cacheStatus: CacheStatus = .empty
    @Published var generationProgress: Double = 0.0
    @Published var isGenerating: Bool = false
    @Published var lastError: String?
    
    // MARK: - Dependencies
    private let storageManager = OfflineStorageManager.shared
    private let healthKitManager = HealthKitManager.shared
    private let syncStateManager = SyncStateManager.shared
    
    // MARK: - Timers
    private var weeklyGenerationTimer: Timer?
    private var cacheCheckTimer: Timer?
    
    // MARK: - Singleton
    static let shared = WeeklyPreCacheSystem()
    
    private init() {
        setupAutomaticGeneration()
        loadExistingPackages()
    }
    
    deinit {
        weeklyGenerationTimer?.invalidate()
        cacheCheckTimer?.invalidate()
    }
    
    // MARK: - 自动生成设置
    
    /// 设置自动生成计划
    private func setupAutomaticGeneration() {
        // 每周日晚上23:00自动生成下周数据
        scheduleWeeklyGeneration()
        
        // 每小时检查缓存状态
        scheduleCacheStatusCheck()
        
        print("📅 预缓存自动生成已设置")
    }
    
    /// 调度周数据生成
    private func scheduleWeeklyGeneration() {
        let calendar = Calendar.current
        let now = Date()
        
        // 找到下一个周日23:00
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 1 // 周日
        components.hour = 23
        components.minute = 0
        components.second = 0
        
        guard let nextSunday = calendar.date(from: components) else { return }
        
        // 如果今天已经是周日23:00之后，则安排下周
        let targetDate = nextSunday <= now ? calendar.date(byAdding: .weekOfYear, value: 1, to: nextSunday)! : nextSunday
        
        let timeInterval = targetDate.timeIntervalSince(now)
        
        weeklyGenerationTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task { @MainActor in
                await self.generateNextWeekDataAutomatically()
                self.scheduleWeeklyGeneration() // 重新调度下次生成
            }
        }
        
        print("⏰ 下次自动生成时间: \(targetDate.formatted())")
    }
    
    /// 调度缓存状态检查
    private func scheduleCacheStatusCheck() {
        cacheCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { @MainActor in
                await self.checkCacheStatus()
            }
        }
    }
    
    // MARK: - 数据加载
    
    /// 加载现有数据包
    private func loadExistingPackages() {
        Task {
            await loadCurrentWeekPackage()
            await loadNextWeekPackage()
            await updateCacheStatus()
        }
    }
    
    /// 加载当前周数据包
    private func loadCurrentWeekPackage() async {
        let now = Date()
        if let package = await storageManager.loadWeeklyPackage(for: now) {
            currentWeekPackage = package
            print("📂 当前周数据包已加载: \(package.weekDescription)")
        } else {
            print("⚠️ 未找到当前周数据包")
        }
    }
    
    /// 加载下周数据包
    private func loadNextWeekPackage() async {
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        
        if let package = await storageManager.loadWeeklyPackage(for: nextWeek) {
            nextWeekPackage = package
            print("📂 下周数据包已加载: \(package.weekDescription)")
        } else {
            print("⚠️ 未找到下周数据包")
        }
    }
    
    // MARK: - 缓存状态管理
    
    /// 检查缓存状态
    private func checkCacheStatus() async {
        await updateCacheStatus()
        
        // 如果当前周没有数据，立即生成
        if currentWeekPackage == nil {
            print("🚨 当前周缺少数据，立即生成...")
            await generateCurrentWeekData()
        }
        
        // 如果下周没有数据，提前生成
        if nextWeekPackage == nil {
            print("📋 下周缺少数据，提前生成...")
            await generateNextWeekData()
        }
        
        // 清理过期数据
        await storageManager.cleanExpiredData()
    }
    
    /// 更新缓存状态
    private func updateCacheStatus() async {
        let hasCurrentWeek = currentWeekPackage != nil
        let hasNextWeek = nextWeekPackage != nil
        
        if hasCurrentWeek && hasNextWeek {
            cacheStatus = .ready
        } else if hasCurrentWeek {
            cacheStatus = .partial
        } else {
            cacheStatus = .empty
        }
        
        print("📊 缓存状态更新: \(cacheStatus.displayName)")
    }
    
    // MARK: - 数据生成
    
    /// 生成当前周数据
    func generateCurrentWeekData() async {
        guard let user = syncStateManager.currentUser else {
            lastError = "未找到当前用户"
            return
        }
        
        isGenerating = true
        generationProgress = 0.0
        lastError = nil
        
        print("📦 开始生成当前周数据包...")
        
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: Date())
        let package = await generateWeeklyPackage(for: user, weekStart: weekStart)
        
        await storageManager.saveWeeklyPackage(package)
        currentWeekPackage = package
        
        await updateCacheStatus()
        
        print("✅ 当前周数据包生成完成")
        print("   数据周期: \(package.weekDescription)")
        print("   总睡眠时间: \(String(format: "%.1f", package.totalSleepHours))小时")
        print("   总步数: \(package.totalSteps)步")
        
        isGenerating = false
        generationProgress = 1.0
    }
    
    /// 生成下周数据
    func generateNextWeekData() async {
        guard let user = syncStateManager.currentUser else {
            lastError = "未找到当前用户"
            return
        }
        
        isGenerating = true
        generationProgress = 0.0
        lastError = nil
        
        print("📦 开始生成下周数据包...")
        
        let calendar = Calendar.current
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfWeek(for: Date())) ?? Date()
        let package = await generateWeeklyPackage(for: user, weekStart: nextWeekStart)
        
        await storageManager.saveWeeklyPackage(package)
        nextWeekPackage = package
        
        await updateCacheStatus()
        
        print("✅ 下周数据包生成完成")
        print("   数据周期: \(package.weekDescription)")
        print("   总睡眠时间: \(String(format: "%.1f", package.totalSleepHours))小时")
        print("   总步数: \(package.totalSteps)步")
        
        isGenerating = false
        generationProgress = 1.0
    }
    
    /// 自动生成下周数据（定时器调用）
    private func generateNextWeekDataAutomatically() async {
        print("🤖 自动生成下周数据...")
        
        // 如果下周数据已存在，先切换当前周
        if let nextPackage = nextWeekPackage {
            currentWeekPackage = nextPackage
            nextWeekPackage = nil
            print("🔄 数据包已切换到新的一周")
        }
        
        // 生成新的下周数据
        await generateNextWeekData()
    }
    
    // MARK: - 核心生成逻辑
    
    /// 生成周数据包
    private func generateWeeklyPackage(for user: VirtualUser, weekStart: Date) async -> WeeklyDataPackage {
        var dailyPlans: [DailyDataPlan] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            
            // 更新生成进度
            generationProgress = Double(dayOffset) / 7.0
            
            let dailyPlan = await generateDailyPlan(for: user, date: date)
            dailyPlans.append(dailyPlan)
            
            print("📅 已生成 \(date.formatted(date: .abbreviated, time: .omitted)) 的数据计划")
        }
        
        // 计算统计信息
        let totalSleepHours = dailyPlans.reduce(0.0) { total, plan in
            total + (plan.sleepData?.duration ?? 0)
        }
        
        let totalSteps = dailyPlans.reduce(0) { total, plan in
            total + plan.stepDistribution.totalSteps
        }
        
        generationProgress = 1.0
        
        return WeeklyDataPackage(
            generatedDate: Date(),
            userID: user.id,
            weekStartDate: weekStart,
            dailyPlans: dailyPlans,
            totalSleepHours: totalSleepHours,
            totalSteps: totalSteps,
            dataVersion: "1.0"
        )
    }
    
    /// 生成每日计划
    private func generateDailyPlan(for user: VirtualUser, date: Date) async -> DailyDataPlan {
        // 1. 生成睡眠数据
        let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: date,
            mode: .simple
        )
        
        // 2. 生成步数分布计划
        let stepDistribution = generateStepDistributionPlan(
            for: user,
            date: date,
            sleepData: sleepData
        )
        
        // 3. 计算导入时间表
        let importSchedule = calculateImportSchedule(
            sleepData: sleepData,
            stepDistribution: stepDistribution
        )
        
        return DailyDataPlan(
            date: date,
            sleepData: sleepData,
            stepDistribution: stepDistribution,
            importSchedule: importSchedule
        )
    }
    
    /// 生成步数分布计划
    private func generateStepDistributionPlan(for user: VirtualUser, date: Date, sleepData: SleepData) -> StepDistributionPlan {
        let totalSteps = PersonalizedDataGenerator.calculateDailySteps(for: user, date: date)
        
        // 计算清醒时段
        let awakePeriods = calculateAwakePeriods(from: sleepData)
        
        // 分配步数到清醒时段
        let distributionBatches = distributeStepsIntoAwakePeriods(
            totalSteps: totalSteps,
            awakePeriods: awakePeriods,
            date: date
        )
        
        // 计算睡眠期间的减少步数
        let sleepTimeReduction = calculateSleepTimeReduction(
            from: sleepData,
            date: date
        )
        
        return StepDistributionPlan(
            totalSteps: totalSteps,
            distributionBatches: distributionBatches,
            sleepTimeReduction: sleepTimeReduction
        )
    }
    
    /// 计算清醒时段
    private func calculateAwakePeriods(from sleepData: SleepData) -> [(start: Date, end: Date)] {
        let dayStart = Calendar.current.startOfDay(for: sleepData.bedTime)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        
        var awakePeriods: [(start: Date, end: Date)] = []
        
        // 处理跨日睡眠情况
        if sleepData.wakeTime > sleepData.bedTime {
            // 同日睡眠（少见）
            awakePeriods.append((start: dayStart, end: sleepData.bedTime))
            awakePeriods.append((start: sleepData.wakeTime, end: dayEnd))
        } else {
            // 跨日睡眠（常见）
            awakePeriods.append((start: sleepData.wakeTime, end: sleepData.bedTime))
        }
        
        return awakePeriods
    }
    
    /// 将步数分布到清醒时段
    private func distributeStepsIntoAwakePeriods(totalSteps: Int, awakePeriods: [(start: Date, end: Date)], date: Date) -> [StepBatch] {
        var batches: [StepBatch] = []
        
        // 计算总清醒时间
        let totalAwakeTime = awakePeriods.reduce(0.0) { total, period in
            total + period.end.timeIntervalSince(period.start)
        }
        
        guard totalAwakeTime > 0 else { return batches }
        
        for period in awakePeriods {
            let periodDuration = period.end.timeIntervalSince(period.start)
            let periodSteps = Int(Double(totalSteps) * (periodDuration / totalAwakeTime))
            
            // 将时段分割为15分钟的批次
            let batchDuration: TimeInterval = 900 // 15分钟
            let batchCount = max(1, Int(periodDuration / batchDuration))
            let stepsPerBatch = periodSteps / batchCount
            
            for batchIndex in 0..<batchCount {
                let batchTime = period.start.addingTimeInterval(Double(batchIndex) * batchDuration)
                
                // 确定活动类型
                let activityType = determineActivityType(for: stepsPerBatch, time: batchTime)
                
                // 确定优先级
                let priority = determineBatchPriority(for: batchTime)
                
                let batch = StepBatch(
                    scheduledTime: batchTime,
                    steps: stepsPerBatch,
                    duration: batchDuration,
                    activityType: activityType,
                    priority: priority,
                    isDuringSleep: false
                )
                
                batches.append(batch)
            }
        }
        
        return batches
    }
    
    /// 根据步数和时间确定活动类型
    private func determineActivityType(for steps: Int, time: Date) -> ActivityType {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        
        // 根据时间和步数判断活动类型
        switch (hour, steps) {
        case (0...6, _): return .idle
        case (7...9, 50...): return .commuting
        case (10...11, 20...): return .walking
        case (12...13, 10...): return .standing
        case (14...17, 30...): return .walking
        case (18...19, 50...): return .commuting
        case (20...22, 40...): return .exercise
        case (23...24, _): return .idle
        default:
            switch steps {
            case 0...10: return .idle
            case 11...30: return .standing
            case 31...80: return .walking
            case 81...: return .running
            default: return .walking
            }
        }
    }
    
    /// 确定批次优先级
    private func determineBatchPriority(for time: Date) -> BatchPriority {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        
        switch hour {
        case 7...9, 18...19: return .high    // 通勤时间高优先级
        case 12...13: return .normal         // 午休时间正常优先级
        case 0...6, 22...23: return .low     // 休息时间低优先级
        default: return .normal
        }
    }
    
    /// 计算睡眠期间的步数减少
    private func calculateSleepTimeReduction(from sleepData: SleepData, date: Date) -> SleepTimeStepReduction {
        var reducedBatches: [StepBatch] = []
        let normalBatches: [StepBatch] = [] // 保持为常量，因为在这个方法中不需要修改
        
        // 生成睡眠期间的最小步数批次（每30分钟0-2步）
        var sleepTime = sleepData.bedTime
        let sleepEnd = sleepData.wakeTime
        
        while sleepTime < sleepEnd {
            let steps = Int.random(in: 0...2) // 睡眠期间最小步数
            
            let batch = StepBatch(
                scheduledTime: sleepTime,
                steps: steps,
                duration: 1800, // 30分钟
                activityType: .idle,
                priority: .low,
                isDuringSleep: true
            )
            
            reducedBatches.append(batch)
            sleepTime = sleepTime.addingTimeInterval(1800) // 30分钟间隔
        }
        
        return SleepTimeStepReduction(
            sleepStartTime: sleepData.bedTime,
            sleepEndTime: sleepData.wakeTime,
            reducedStepBatches: reducedBatches,
            normalStepBatches: normalBatches
        )
    }
    
    /// 计算导入时间表
    private func calculateImportSchedule(sleepData: SleepData, stepDistribution: StepDistributionPlan) -> ImportSchedule {
        // 睡眠数据在起床时间导入
        let sleepImportTime = sleepData.wakeTime
        
        // 步数批次时间
        let stepBatchTimes = stepDistribution.distributionBatches.map { $0.scheduledTime }
        
        // 备用时间（网络失败时延后1小时）
        let fallbackSchedule = stepBatchTimes.map { $0.addingTimeInterval(3600) }
        
        return ImportSchedule(
            sleepImportTime: sleepImportTime,
            stepBatchTimes: stepBatchTimes,
            fallbackSchedule: fallbackSchedule
        )
    }
    
    // MARK: - 公共接口
    
    /// 手动刷新缓存
    func refreshCache() async {
        print("🔄 手动刷新缓存...")
        await checkCacheStatus()
    }
    
    /// 强制重新生成所有数据
    func forceRegenerateAllData() async {
        print("🔄 强制重新生成所有数据...")
        currentWeekPackage = nil
        nextWeekPackage = nil
        
        await generateCurrentWeekData()
        await generateNextWeekData()
    }
    
    /// 获取今日数据计划
    func getTodayPlan() -> DailyDataPlan? {
        return currentWeekPackage?.getDailyPlan(for: Date())
    }
    
    /// 获取明日数据计划
    func getTomorrowPlan() -> DailyDataPlan? {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return currentWeekPackage?.getDailyPlan(for: tomorrow) ?? nextWeekPackage?.getDailyPlan(for: tomorrow)
    }
}

// MARK: - 缓存状态枚举

enum CacheStatus: String, Codable {
    case empty = "empty"
    case partial = "partial"
    case ready = "ready"
    case generating = "generating"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .empty: return "缓存为空"
        case .partial: return "部分缓存"
        case .ready: return "缓存就绪"
        case .generating: return "生成中"
        case .error: return "缓存错误"
        }
    }
    
    var emoji: String {
        switch self {
        case .empty: return "📭"
        case .partial: return "📬"
        case .ready: return "📫"
        case .generating: return "⚙️"
        case .error: return "❌"
        }
    }
}

// MARK: - Calendar Extension

extension Calendar {
    /// 获取指定日期所在周的开始日期（周一）
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
} 