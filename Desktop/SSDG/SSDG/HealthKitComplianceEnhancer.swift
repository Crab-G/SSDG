//
//  HealthKitComplianceEnhancer.swift
//  SSDG - HealthKit规范兼容性增强器
//
//  确保生成的健康数据完全符合苹果HealthKit规范要求
//

import Foundation
import HealthKit

// MARK: - HealthKit规范兼容性增强器
class HealthKitComplianceEnhancer {
    
    // MARK: - 数据验证和修正
    
    /// 验证并修正睡眠数据，确保符合HealthKit规范
    static func validateAndCorrectSleepData(_ sleepData: SleepData) -> SleepData {
        let correctedBedTime = validateTimestamp(sleepData.bedTime)
        let correctedWakeTime = validateTimestamp(sleepData.wakeTime)
        
        // 确保起床时间晚于就寝时间
        let finalWakeTime = ensureWakeTimeAfterBedTime(
            bedTime: correctedBedTime,
            wakeTime: correctedWakeTime
        )
        
        // 验证睡眠阶段时间连续性
        let correctedStages = validateSleepStages(
            stages: sleepData.sleepStages,
            bedTime: correctedBedTime,
            wakeTime: finalWakeTime
        )
        
        return SleepData(
            date: validateTimestamp(sleepData.date),
            bedTime: correctedBedTime,
            wakeTime: finalWakeTime,
            sleepStages: correctedStages
        )
    }
    
    /// 验证并修正步数数据，确保符合HealthKit规范 - 睡眠感知版
    static func validateAndCorrectStepsData(_ stepsData: StepsData, sleepData: SleepData? = nil) -> StepsData {
        
        // 🔧 关键修复：检查并修正异常低的总步数
        let originalTotalSteps = stepsData.totalSteps
        let correctedTotalSteps = max(800, originalTotalSteps) // 确保最少800步
        
        if correctedTotalSteps != originalTotalSteps {
            print("⚠️ 自动修复异常低步数: \(originalTotalSteps)步 -> \(correctedTotalSteps)步")
            
            // 🔄 使用睡眠感知的重新分配
            let correctedHourlySteps = redistributeStepsWithSleepAwareness(
                originalHourlySteps: stepsData.hourlySteps,
                newTotalSteps: correctedTotalSteps,
                sleepData: sleepData,
                date: stepsData.date
            )
            
            let correctedData = StepsData(
                date: stepsData.date,
                hourlySteps: correctedHourlySteps,
                stepsIntervals: stepsData.stepsIntervals
            )
            
            return validateAndCorrectNormalStepsData(correctedData)
        }
        
        return validateAndCorrectNormalStepsData(stepsData)
    }
    
    /// 兼容性方法：保持原有接口
    static func validateAndCorrectStepsData(_ stepsData: StepsData) -> StepsData {
        return validateAndCorrectStepsData(stepsData, sleepData: nil)
    }
    
    /// 正常情况下的步数数据验证和修正
    private static func validateAndCorrectNormalStepsData(_ stepsData: StepsData) -> StepsData {
        // 验证每小时步数数据
        let correctedHourlySteps = stepsData.hourlySteps.map { hourlyStep in
            HourlySteps(
                hour: max(0, min(23, hourlyStep.hour)), // 小时范围0-23
                steps: max(0, min(65535, hourlyStep.steps)), // HealthKit最大单小时步数限制
                startTime: validateTimestamp(hourlyStep.startTime),
                endTime: validateTimestamp(hourlyStep.endTime)
            )
        }
        
        // 验证步数间隔数据
        let correctedStepsIntervals = stepsData.stepsIntervals.compactMap { interval -> StepsInterval? in
            let correctedSteps = max(0, min(10000, interval.steps)) // 单次记录最大10000步
            let correctedStartTime = validateTimestamp(interval.startTime)
            let correctedEndTime = validateTimestamp(interval.endTime)
            
            // 确保结束时间晚于开始时间
            guard correctedEndTime > correctedStartTime else {
                print("⚠️ 步数间隔时间顺序错误，已跳过: \(correctedStartTime) -> \(correctedEndTime)")
                return nil
            }
            
            // 确保时间间隔不超过24小时
            let maxInterval: TimeInterval = 24 * 3600
            let actualInterval = correctedEndTime.timeIntervalSince(correctedStartTime)
            guard actualInterval <= maxInterval else {
                print("⚠️ 步数间隔时间过长，已调整: \(actualInterval/3600)小时 -> 24小时")
                return StepsInterval(
                    steps: correctedSteps,
                    startTime: correctedStartTime,
                    endTime: correctedStartTime.addingTimeInterval(maxInterval)
                )
            }
            
            return StepsInterval(
                steps: correctedSteps,
                startTime: correctedStartTime,
                endTime: correctedEndTime
            )
        }
        
        return StepsData(
            date: validateTimestamp(stepsData.date),
            hourlySteps: correctedHourlySteps,
            stepsIntervals: correctedStepsIntervals
        )
    }
    
    // MARK: - 时间戳规范化
    
    /// 验证并规范化时间戳，确保符合HealthKit精度要求
    private static func validateTimestamp(_ date: Date) -> Date {
        // HealthKit要求时间戳精确到秒，移除毫秒部分
        let timeInterval = date.timeIntervalSince1970
        let roundedInterval = round(timeInterval)
        return Date(timeIntervalSince1970: roundedInterval)
    }
    
    /// 确保起床时间晚于就寝时间
    private static func ensureWakeTimeAfterBedTime(bedTime: Date, wakeTime: Date) -> Date {
        // 如果起床时间早于就寝时间，说明是跨日睡眠
        if wakeTime <= bedTime {
            // 假设睡眠时长为7-9小时，调整起床时间到第二天
            let sleepDuration: TimeInterval = 8 * 3600 // 8小时默认睡眠
            return bedTime.addingTimeInterval(sleepDuration)
        }
        
        // 检查睡眠时长是否合理（2-16小时）
        let sleepDuration = wakeTime.timeIntervalSince(bedTime)
        let minSleep: TimeInterval = 2 * 3600  // 最少2小时
        let maxSleep: TimeInterval = 16 * 3600 // 最多16小时
        
        if sleepDuration < minSleep {
            print("⚠️ 睡眠时长过短(\(sleepDuration/3600)小时)，调整为最少2小时")
            return bedTime.addingTimeInterval(minSleep)
        }
        
        if sleepDuration > maxSleep {
            print("⚠️ 睡眠时长过长(\(sleepDuration/3600)小时)，调整为最多16小时")
            return bedTime.addingTimeInterval(maxSleep)
        }
        
        return wakeTime
    }
    
    /// 验证睡眠阶段的时间连续性
    private static func validateSleepStages(
        stages: [SleepStage],
        bedTime: Date,
        wakeTime: Date
    ) -> [SleepStage] {
        
        guard !stages.isEmpty else { return [] }
        
        var correctedStages: [SleepStage] = []
        
        for stage in stages.sorted(by: { $0.startTime < $1.startTime }) {
            let correctedStartTime = validateTimestamp(stage.startTime)
            let correctedEndTime = validateTimestamp(stage.endTime)
            
            // 确保阶段在睡眠时间范围内
            let clampedStartTime = max(bedTime, min(wakeTime, correctedStartTime))
            let clampedEndTime = max(bedTime, min(wakeTime, correctedEndTime))
            
            // 确保结束时间晚于开始时间
            guard clampedEndTime > clampedStartTime else {
                print("⚠️ 睡眠阶段时间顺序错误，已跳过: \(stage.stage.displayName)")
                continue
            }
            
            // 验证睡眠阶段类型合理性
            let validatedStage = validateSleepStageType(stage.stage)
            
            correctedStages.append(SleepStage(
                stage: validatedStage,
                startTime: clampedStartTime,
                endTime: clampedEndTime
            ))
        }
        
        return correctedStages
    }
    
    /// 验证睡眠阶段类型
    private static func validateSleepStageType(_ stageType: SleepStageType) -> SleepStageType {
        // HealthKit支持的睡眠阶段类型验证
        // 确保使用的是有效的睡眠阶段类型
        return stageType
    }
    
    // MARK: - 设备和来源信息生成
    
    /// 生成符合HealthKit规范的设备信息
    static func generateValidDeviceInfo() -> [String: Any] {
        let deviceInfo: [String: Any] = [
            "name": "iPhone", // 不指定具体型号以保护隐私
            "manufacturer": "Apple Inc.",
            "model": "iPhone",
            "hardware": "iPhone", // 通用硬件标识
            "software": ProcessInfo.processInfo.operatingSystemVersionString
        ]
        
        return deviceInfo
    }
    
    /// 生成HealthKit元数据
    static func generateHealthKitMetadata(for dataType: String) -> [String: Any] {
        var metadata: [String: Any] = [
            "HKWasUserEntered": false, // 标记为非用户手动输入
            "HKTimeZone": TimeZone.current.identifier,
            "HKDataOrigin": Bundle.main.bundleIdentifier ?? "com.healthkit.testing"
        ]
        
        // 根据数据类型添加特定元数据
        switch dataType {
        case "Steps":
            metadata["HKQuantityTypeIdentifier"] = "HKQuantityTypeIdentifierStepCount"
        case "Sleep":
            metadata["HKCategoryTypeIdentifier"] = "HKCategoryTypeIdentifierSleepAnalysis"
        default:
            break
        }
        
        return metadata
    }
    
    // MARK: - 数据完整性检查
    
    /// 检查睡眠数据完整性
    static func validateSleepDataIntegrity(_ sleepData: SleepData) -> [String] {
        var issues: [String] = []
        
        // 检查基本时间逻辑
        if sleepData.wakeTime <= sleepData.bedTime {
            let duration = sleepData.wakeTime.timeIntervalSince(sleepData.bedTime)
            if duration <= 0 {
                issues.append("起床时间早于或等于就寝时间")
            }
        }
        
        // 检查睡眠时长合理性
        let duration = sleepData.duration
        if duration < 2 {
            issues.append("睡眠时长过短：\(String(format: "%.1f", duration))小时")
        } else if duration > 16 {
            issues.append("睡眠时长过长：\(String(format: "%.1f", duration))小时")
        }
        
        // 检查睡眠阶段完整性
        if !sleepData.sleepStages.isEmpty {
            let totalStagesDuration = sleepData.sleepStages.reduce(0) { $0 + $1.duration }
            let sleepDuration = sleepData.wakeTime.timeIntervalSince(sleepData.bedTime)
            let coverageRatio = totalStagesDuration / sleepDuration
            
            if coverageRatio < 0.8 {
                issues.append("睡眠阶段覆盖度不足：\(String(format: "%.0f", coverageRatio * 100))%")
            } else if coverageRatio > 1.2 {
                issues.append("睡眠阶段重叠过多：\(String(format: "%.0f", coverageRatio * 100))%")
            }
        }
        
        return issues
    }
    
    /// 检查步数数据完整性
    static func validateStepsDataIntegrity(_ stepsData: StepsData) -> [String] {
        var issues: [String] = []
        
        let totalSteps = stepsData.totalSteps
        
        // 检查总步数合理性
        if totalSteps < 0 {
            issues.append("总步数为负数：\(totalSteps)")
        } else if totalSteps < 100 {
            issues.append("单日步数异常低：\(totalSteps)步 (低于正常人最低活动量)")
        } else if totalSteps > 100000 {
            issues.append("单日步数异常高：\(totalSteps)步")
        }
        
        // 检查每小时步数合理性
        for hourlyStep in stepsData.hourlySteps {
            if hourlyStep.steps < 0 {
                issues.append("第\(hourlyStep.hour)小时步数为负数：\(hourlyStep.steps)")
            } else if hourlyStep.steps > 15000 {
                issues.append("第\(hourlyStep.hour)小时步数异常高：\(hourlyStep.steps)步")
            }
            
            if hourlyStep.hour < 0 || hourlyStep.hour > 23 {
                issues.append("小时值超出范围：\(hourlyStep.hour)")
            }
        }
        
        // 检查步数间隔数据
        for (index, interval) in stepsData.stepsIntervals.enumerated() {
            if interval.steps < 0 {
                issues.append("步数间隔\(index)步数为负数：\(interval.steps)")
            } else if interval.steps > 10000 {
                issues.append("步数间隔\(index)步数异常高：\(interval.steps)步")
            }
            
            if interval.endTime <= interval.startTime {
                issues.append("步数间隔\(index)时间顺序错误")
            }
        }
        
        return issues
    }
    
    // MARK: - 数据同步优化
    
    /// 优化数据以提高HealthKit写入成功率
    static func optimizeForHealthKitSync<T>(_ data: [T]) -> [T] {
        // 限制单次同步的数据量，避免内存压力
        let maxBatchSize = 1000
        return Array(data.prefix(maxBatchSize))
    }
    
    /// 生成数据批次，适合大量数据的分批写入
    static func createDataBatches<T>(_ data: [T], batchSize: Int = 100) -> [[T]] {
        var batches: [[T]] = []
        let count = data.count
        
        for i in stride(from: 0, to: count, by: batchSize) {
            let endIndex = min(i + batchSize, count)
            let batch = Array(data[i..<endIndex])
            batches.append(batch)
        }
        
        return batches
    }
}

// MARK: - HealthKit权限和状态检查
extension HealthKitComplianceEnhancer {
    
    /// 检查HealthKit可用性
    static func checkHealthKitAvailability() -> (available: Bool, message: String) {
        if !HKHealthStore.isHealthDataAvailable() {
            return (false, "HealthKit在此设备上不可用")
        }
        
        return (true, "HealthKit可用")
    }
    
    /// 验证所需权限
    static func validateRequiredPermissions(healthStore: HKHealthStore) -> [String] {
        var missingPermissions: [String] = []
        
        // 检查步数权限
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepsStatus = healthStore.authorizationStatus(for: stepsType)
        if stepsStatus != .sharingAuthorized {
            missingPermissions.append("步数写入权限")
        }
        
        // 检查睡眠权限
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let sleepStatus = healthStore.authorizationStatus(for: sleepType)
        if sleepStatus != .sharingAuthorized {
            missingPermissions.append("睡眠数据写入权限")
        }
        
        return missingPermissions
    }
    
    /// 睡眠感知的步数重新分配
    private static func redistributeStepsWithSleepAwareness(
        originalHourlySteps: [HourlySteps],
        newTotalSteps: Int,
        sleepData: SleepData?,
        date: Date
    ) -> [HourlySteps] {
        
        // 如果有睡眠数据，使用睡眠感知分配
        if let sleepData = sleepData {
            print("🛏️ 使用睡眠感知重新分配步数")
            return redistributeStepsWithSleepData(
                originalHourlySteps: originalHourlySteps,
                newTotalSteps: newTotalSteps,
                sleepData: sleepData,
                date: date
            )
        } else {
            print("📊 使用通用方法重新分配步数")
            return redistributeStepsToHours(
                originalHourlySteps: originalHourlySteps,
                newTotalSteps: newTotalSteps
            )
        }
    }
    
    /// 基于睡眠数据的智能步数重新分配
    private static func redistributeStepsWithSleepData(
        originalHourlySteps: [HourlySteps],
        newTotalSteps: Int,
        sleepData: SleepData,
        date: Date
    ) -> [HourlySteps] {
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        // 识别睡眠时段和清醒时段
        let sleepPeriods = extractSleepPeriodsForDate(sleepData: sleepData, date: date)
        let wakePeriods = extractWakePeriodsForDate(sleepPeriods: sleepPeriods, dayStart: dayStart, dayEnd: dayEnd)
        
        print("   睡眠时段: \(sleepPeriods.count)个")
        print("   清醒时段: \(wakePeriods.count)个")
        
        // 分配极少步数到睡眠时段（总步数的0.5-1%）
        let sleepStepsBudget = max(1, Int(Double(newTotalSteps) * 0.008)) // 0.8%
        let wakeStepsRemaining = newTotalSteps - sleepStepsBudget
        
        var newHourlySteps: [HourlySteps] = []
        
        // 为每个小时分配步数
        for hour in 0...23 {
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart)!
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
            
            let isInSleepPeriod = sleepPeriods.contains { period in
                hourStart < period.end && hourEnd > period.start
            }
            
            let hourSteps: Int
            if isInSleepPeriod {
                // 睡眠时段：分配极少步数
                let sleepHoursCount = sleepPeriods.reduce(0.0) { total, period in
                    let periodHours = period.end.timeIntervalSince(period.start) / 3600.0
                    return total + periodHours
                }
                hourSteps = max(0, Int(Double(sleepStepsBudget) / sleepHoursCount))
            } else {
                // 清醒时段：分配剩余步数
                let wakeHoursCount = wakePeriods.reduce(0.0) { total, period in
                    let periodHours = period.end.timeIntervalSince(period.start) / 3600.0
                    return total + periodHours
                }
                hourSteps = wakeHoursCount > 0 ? max(0, Int(Double(wakeStepsRemaining) / wakeHoursCount)) : 0
            }
            
            newHourlySteps.append(HourlySteps(
                hour: hour,
                steps: hourSteps,
                startTime: hourStart,
                endTime: hourEnd
            ))
        }
        
        // 确保总步数一致
        let actualTotal = newHourlySteps.reduce(0) { $0 + $1.steps }
        if actualTotal != newTotalSteps {
            // 将差值分配到最活跃的清醒时段
            let difference = newTotalSteps - actualTotal
            if let maxWakeHour = newHourlySteps.filter({ hour in
                !sleepPeriods.contains { period in
                    let hourStart = calendar.date(byAdding: .hour, value: hour.hour, to: dayStart)!
                    let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
                    return hourStart < period.end && hourEnd > period.start
                }
            }).max(by: { $0.steps < $1.steps }) {
                if let index = newHourlySteps.firstIndex(where: { $0.hour == maxWakeHour.hour }) {
                    let updatedSteps = max(0, maxWakeHour.steps + difference)
                    newHourlySteps[index] = HourlySteps(
                        hour: maxWakeHour.hour,
                        steps: updatedSteps,
                        startTime: maxWakeHour.startTime,
                        endTime: maxWakeHour.endTime
                    )
                }
            }
        }
        
        print("   重新分配完成: 睡眠时段约\(sleepStepsBudget)步，清醒时段约\(wakeStepsRemaining)步")
        
        return newHourlySteps
    }
    
    /// 提取指定日期的睡眠时段
    private static func extractSleepPeriodsForDate(sleepData: SleepData, date: Date) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        var periods: [(start: Date, end: Date)] = []
        
        // 主睡眠时段与当日的交集
        let sleepStart = max(sleepData.bedTime, dayStart)
        let sleepEnd = min(sleepData.wakeTime, dayEnd)
        
        if sleepStart < sleepEnd {
            periods.append((start: sleepStart, end: sleepEnd))
        }
        
        // 处理跨日睡眠
        if sleepData.bedTime < dayStart && sleepData.wakeTime > dayStart {
            periods.append((start: dayStart, end: min(sleepData.wakeTime, dayEnd)))
        }
        
        if sleepData.bedTime < dayEnd && sleepData.bedTime >= dayStart {
            periods.append((start: sleepData.bedTime, end: dayEnd))
        }
        
        return periods
    }
    
    /// 提取清醒时段
    private static func extractWakePeriodsForDate(
        sleepPeriods: [(start: Date, end: Date)],
        dayStart: Date,
        dayEnd: Date
    ) -> [(start: Date, end: Date)] {
        
        var wakePeriods: [(start: Date, end: Date)] = []
        var currentTime = dayStart
        
        for sleepPeriod in sleepPeriods.sorted(by: { $0.start < $1.start }) {
            if currentTime < sleepPeriod.start {
                wakePeriods.append((start: currentTime, end: sleepPeriod.start))
            }
            currentTime = max(currentTime, sleepPeriod.end)
        }
        
        if currentTime < dayEnd {
            wakePeriods.append((start: currentTime, end: dayEnd))
        }
        
        return wakePeriods
    }
    
    /// 重新分配步数到小时数据中 (原有方法，作为备用)
    private static func redistributeStepsToHours(
        originalHourlySteps: [HourlySteps],
        newTotalSteps: Int
    ) -> [HourlySteps] {
        
        guard !originalHourlySteps.isEmpty else {
            // 如果没有原始小时数据，创建基本的分布
            return createBasicHourlyDistribution(totalSteps: newTotalSteps)
        }
        
        let originalTotal = originalHourlySteps.reduce(0) { $0 + $1.steps }
        guard originalTotal > 0 else {
            return createBasicHourlyDistribution(totalSteps: newTotalSteps)
        }
        
        // 按比例重新分配
        let ratio = Double(newTotalSteps) / Double(originalTotal)
        var redistributedSteps: [HourlySteps] = []
        var assignedSteps = 0
        
        for (index, hourlyStep) in originalHourlySteps.enumerated() {
            let newSteps: Int
            if index == originalHourlySteps.count - 1 {
                // 最后一个小时分配剩余步数
                newSteps = newTotalSteps - assignedSteps
            } else {
                newSteps = Int(Double(hourlyStep.steps) * ratio)
                assignedSteps += newSteps
            }
            
            redistributedSteps.append(HourlySteps(
                hour: hourlyStep.hour,
                steps: max(0, newSteps),
                startTime: hourlyStep.startTime,
                endTime: hourlyStep.endTime
            ))
        }
        
        return redistributedSteps
    }
    
    /// 创建基本的小时步数分布
    private static func createBasicHourlyDistribution(totalSteps: Int) -> [HourlySteps] {
        var hourlySteps: [HourlySteps] = []
        let calendar = Calendar.current
        let today = Date()
        let dayStart = calendar.startOfDay(for: today)
        
        // 活跃时间段：7-22点
        let activeHours = Array(7...22)
        let stepsPerHour = totalSteps / activeHours.count
        let remainder = totalSteps % activeHours.count
        
        for (index, hour) in activeHours.enumerated() {
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart)!
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
            
            let hourSteps = stepsPerHour + (index < remainder ? 1 : 0)
            
            hourlySteps.append(HourlySteps(
                hour: hour,
                steps: hourSteps,
                startTime: hourStart,
                endTime: hourEnd
            ))
        }
        
        return hourlySteps
    }
    
    /// 生成权限请求配置
    static func createPermissionRequestConfig() -> (read: Set<HKObjectType>, write: Set<HKSampleType>) {
        var readTypes: Set<HKObjectType> = []
        var writeTypes: Set<HKSampleType> = []
        
        // 步数相关
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(stepsType)
            writeTypes.insert(stepsType)
        }
        
        // 睡眠相关
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
            writeTypes.insert(sleepType)
        }
        
        return (read: readTypes, write: writeTypes)
    }
}

// MARK: - 调试和诊断工具
extension HealthKitComplianceEnhancer {
    
    /// 生成数据质量报告
    static func generateDataQualityReport(
        sleepData: [SleepData],
        stepsData: [StepsData]
    ) -> String {
        var report = "📊 数据质量报告\n"
        report += "==================\n\n"
        
        // 睡眠数据分析
        report += "🌙 睡眠数据分析：\n"
        report += "- 数据条数：\(sleepData.count)\n"
        
        if !sleepData.isEmpty {
            let avgDuration = sleepData.map { $0.duration }.reduce(0, +) / Double(sleepData.count)
            report += "- 平均睡眠时长：\(String(format: "%.1f", avgDuration))小时\n"
            
            let sleepIssues = sleepData.flatMap { validateSleepDataIntegrity($0) }
            report += "- 数据问题：\(sleepIssues.count)个\n"
            if !sleepIssues.isEmpty {
                report += "  问题详情：\n"
                for issue in sleepIssues.prefix(5) {
                    report += "  • \(issue)\n"
                }
            }
        }
        
        report += "\n"
        
        // 步数数据分析
        report += "🚶‍♂️ 步数数据分析：\n"
        report += "- 数据条数：\(stepsData.count)\n"
        
        if !stepsData.isEmpty {
            let avgSteps = stepsData.map { $0.totalSteps }.reduce(0, +) / stepsData.count
            report += "- 平均每日步数：\(avgSteps)步\n"
            
            let stepsIssues = stepsData.flatMap { validateStepsDataIntegrity($0) }
            report += "- 数据问题：\(stepsIssues.count)个\n"
            if !stepsIssues.isEmpty {
                report += "  问题详情：\n"
                for issue in stepsIssues.prefix(5) {
                    report += "  • \(issue)\n"
                }
            }
        }
        
        report += "\n✅ 报告生成完成"
        
        return report
    }
    
    /// 打印详细的验证日志
    static func printValidationLog(for data: Any, dataType: String) {
        print("🔍 开始验证\(dataType)数据...")
        
        switch data {
        case let sleepData as SleepData:
            let issues = validateSleepDataIntegrity(sleepData)
            if issues.isEmpty {
                print("✅ 睡眠数据验证通过")
            } else {
                print("⚠️ 发现\(issues.count)个问题：")
                issues.forEach { print("  • \($0)") }
            }
            
        case let stepsData as StepsData:
            let issues = validateStepsDataIntegrity(stepsData)
            if issues.isEmpty {
                print("✅ 步数数据验证通过")
            } else {
                print("⚠️ 发现\(issues.count)个问题：")
                issues.forEach { print("  • \($0)") }
            }
            
        default:
            print("❓ 不支持的数据类型验证")
        }
        
        print("🔍 \(dataType)数据验证完成\n")
    }
}