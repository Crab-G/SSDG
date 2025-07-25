//
//  DataGenerator.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation

// MARK: - 数据模式枚举
enum DataMode: String, CaseIterable {
    case simple = "simple"
    case wearableDevice = "wearableDevice"
    
    var displayName: String {
        switch self {
        case .simple:
            return "简易模式"
        case .wearableDevice:
            return "模拟穿戴设备"
        }
    }
    
    var description: String {
        switch self {
        case .simple:
            return "模拟iPhone无穿戴设备记录，生成分段卧床时间"
        case .wearableDevice:
            return "细分睡眠数据，包括深度睡眠、REM睡眠、核心睡眠等"
        }
    }
}

// MARK: - 数据生成器
class DataGenerator {
    
    // MARK: - 生成历史数据
    static func generateHistoricalData(for user: VirtualUser, days: Int = 30, mode: DataMode = .simple) -> (sleepData: [SleepData], stepsData: [StepsData]) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        
        var sleepData: [SleepData] = []
        var stepsData: [StepsData] = []
        
        // 使用用户ID作为种子，确保数据一致性
        let seed = generateSeed(from: user.id)
        var generator = SeededRandomGenerator(seed: UInt64(seed))
        
        // 生成每天的数据
        var currentDate = startDate
        var recentSleepHours: [Double] = [] // 用于连续性检查
        
        while currentDate <= endDate {
            // 生成睡眠数据
            let sleepHours = generateSleepHours(
                baseline: user.sleepBaseline,
                date: currentDate,
                recentSleepHours: recentSleepHours,
                generator: &generator
            )
            
            let sleep = generateSleepData(
                date: currentDate,
                totalSleepHours: sleepHours,
                mode: mode,
                generator: &generator
            )
            sleepData.append(sleep)
            
            // 更新最近睡眠时间记录
            recentSleepHours.append(sleepHours)
            if recentSleepHours.count > 3 {
                recentSleepHours.removeFirst()
            }
            
            // 生成步数数据（考虑睡眠时间）
            let steps = generateStepsData(
                date: currentDate,
                baseline: user.stepsBaseline,
                sleepData: sleep,
                mode: mode,
                generator: &generator
            )
            stepsData.append(steps)
            
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return (sleepData, stepsData)
    }
    
    // MARK: - 生成每日数据（增强版：双向关联）
    static func generateDailyData(for user: VirtualUser, recentSleepData: [SleepData], recentStepsData: [StepsData], mode: DataMode = .simple) -> (sleepData: SleepData, stepsData: StepsData) {
        return generateDailyData(for: user, date: Date(), recentSleepData: recentSleepData, recentStepsData: recentStepsData, mode: mode)
    }
    
    // 重载方法：支持指定日期
    static func generateDailyData(for user: VirtualUser, date: Date, recentSleepData: [SleepData], recentStepsData: [StepsData], mode: DataMode = .simple) -> (sleepData: SleepData, stepsData: StepsData) {
        let seed = generateSeed(from: user.id + date.timeIntervalSince1970.description)
        var generator = SeededRandomGenerator(seed: UInt64(seed))
        
        // 计算最近3天的睡眠时间
        let recentSleepHours = recentSleepData.suffix(3).map { $0.totalSleepHours }
        
        // 考虑昨天的运动量对今天睡眠需求的影响
        var adjustedSleepBaseline = user.sleepBaseline
        if let yesterdaySteps = recentStepsData.last {
            let activityImpact = calculateActivityImpactOnSleep(stepsData: yesterdaySteps, baseline: user.stepsBaseline)
            adjustedSleepBaseline += activityImpact
        }
        
        // 生成今日睡眠数据（考虑运动影响）
        let sleepHours = generateSleepHours(
            baseline: adjustedSleepBaseline,
            date: date,
            recentSleepHours: recentSleepHours,
            generator: &generator
        )
        
        let sleepData = generateSleepData(
            date: date,
            totalSleepHours: sleepHours,
            mode: mode,
            generator: &generator
        )
        
        // 计算最近7天的平均步数
        let recentSteps = recentStepsData.suffix(7).map { $0.totalSteps }
        let averageSteps = recentSteps.isEmpty ? user.stepsBaseline : recentSteps.reduce(0, +) / recentSteps.count
        
        // 生成今日步数数据（考虑睡眠质量）
        let stepsData = generateStepsData(
            date: date,
            baseline: averageSteps,
            sleepData: sleepData,
            mode: mode,
            generator: &generator
        )
        
        return (sleepData, stepsData)
    }
    
    // MARK: - 计算运动量对睡眠需求的影响
    private static func calculateActivityImpactOnSleep(stepsData: StepsData, baseline: Int) -> Double {
        let totalSteps = stepsData.totalSteps
        let stepsDifference = totalSteps - baseline
        
        // 计算运动强度相对于个人基准的偏差
        let relativeActivity = Double(stepsDifference) / Double(baseline)
        
        var sleepAdjustment: Double = 0
        
        if relativeActivity > 0.5 { // 运动量比平时多50%以上
            // 高强度活动：需要更多睡眠来恢复
            sleepAdjustment = min(relativeActivity * 0.8, 1.5) // 最多增加1.5小时
        } else if relativeActivity > 0.2 { // 运动量比平时多20-50%
            // 中等强度活动：适度增加睡眠需求
            sleepAdjustment = relativeActivity * 0.5 // 增加0.1-0.4小时
        } else if relativeActivity < -0.3 { // 运动量比平时少30%以上
            // 活动不足：可能因为疲劳，需要稍微多睡
            sleepAdjustment = abs(relativeActivity) * 0.3 // 增加0.1-0.2小时
        }
        
        // 考虑具体的步数范围
        if totalSteps > 15000 { // 高活动量
            sleepAdjustment += 0.2 + (Double(totalSteps - 15000) / 10000.0) * 0.5
        } else if totalSteps < 3000 { // 极低活动量（可能生病或休息日）
            sleepAdjustment += 0.3 // 身体需要更多休息
        }
        
        return max(-0.5, min(2.0, sleepAdjustment)) // 限制在±0.5到+2小时范围内
    }
    
    // MARK: - 生成每日睡眠数据
    static func generateDailySleepData(for user: VirtualUser, date: Date, previousData: [SleepData], mode: DataMode = .simple) -> SleepData {
        let seed = generateSeed(from: user.id + date.timeIntervalSince1970.description)
        var generator = SeededRandomGenerator(seed: UInt64(seed))
        
        // 计算最近3天的睡眠时间
        let recentSleepHours = previousData.suffix(3).map { $0.totalSleepHours }
        
        // 生成睡眠时长
        let sleepHours = generateSleepHours(
            baseline: user.sleepBaseline,
            date: date,
            recentSleepHours: recentSleepHours,
            generator: &generator
        )
        
        // 生成睡眠数据
        return generateSleepData(
            date: date,
            totalSleepHours: sleepHours,
            mode: mode,
            generator: &generator
        )
    }
    
    // MARK: - 生成每日步数数据
    static func generateDailyStepsData(for user: VirtualUser, date: Date, previousData: [StepsData], mode: DataMode = .simple) -> StepsData {
        let seed = generateSeed(from: user.id + date.timeIntervalSince1970.description)
        var generator = SeededRandomGenerator(seed: UInt64(seed))
        
        // 计算最近7天的平均步数
        let recentSteps = previousData.suffix(7).map { $0.totalSteps }
        let averageSteps = recentSteps.isEmpty ? user.stepsBaseline : recentSteps.reduce(0, +) / recentSteps.count
        
        // 生成步数数据（无睡眠数据时使用默认逻辑）
        return generateStepsData(
            date: date,
            baseline: averageSteps,
            sleepData: nil,
            mode: mode,
            generator: &generator
        )
    }
    
    // MARK: - 生成睡眠时长（增强版：周期性 + 关联性）
    private static func generateSleepHours(baseline: Double, date: Date, recentSleepHours: [Double], generator: inout SeededRandomGenerator) -> Double {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7 // 周日或周六
        let isFriday = weekday == 6 // 周五
        
        var sleepHours = baseline
        
        // 1. 计算睡眠债务（过去7天的累积）
        let sleepDebt = calculateSleepDebt(recentSleepHours: recentSleepHours, baseline: baseline)
        
        // 2. 睡眠债务补偿机制
        if sleepDebt > 0 {
            let debtCompensation = min(sleepDebt * 0.3, 2.0) // 最多补偿2小时
            if isWeekend {
                // 周末优先补觉
                sleepHours += debtCompensation * generator.nextDouble(in: 0.8...1.2)
            } else {
                // 工作日少量补偿
                sleepHours += debtCompensation * 0.3
            }
        }
        
        // 3. 周期性睡眠模式
        if isWeekend {
            // 周末：睡眠时间增加1-2.5小时
            let weekendBonus = generator.nextDouble(in: 1.0...2.5)
            sleepHours += weekendBonus
            
            // 周六夜通常比周日夜睡得晚（社交活动）
            if weekday == 7 { // 周六
                if generator.nextDouble(in: 0...1) < 0.4 { // 40%概率熬夜
                    sleepHours -= generator.nextDouble(in: 0.5...1.5)
                }
            }
        } else if isFriday {
            // 周五夜：30%概率熬夜（社交活动）
            if generator.nextDouble(in: 0...1) < 0.3 {
                sleepHours -= generator.nextDouble(in: 0.5...2.0)
            }
        }
        
        // 4. 睡眠压力累积效应
        let sleepPressure = calculateSleepPressure(recentSleepHours: recentSleepHours, baseline: baseline)
        if sleepPressure > 1.5 { // 高睡眠压力
            // 更容易早睡和睡得更深
            sleepHours += generator.nextDouble(in: 0.3...1.0)
        }
        
        // 5. 日常波动（减小，因为周期性因素已经包含了主要变化）
        let dailyVariation = generator.nextDouble(in: -0.10...0.10)
        sleepHours *= (1 + dailyVariation)
        
        // 6. 偶发事件（降低概率，增加影响）
        if generator.nextDouble(in: 0...1) < 0.08 { // 8%概率
            let eventType = generator.nextDouble(in: 0...1)
            if eventType < 0.3 { // 失眠夜
                sleepHours -= generator.nextDouble(in: 1.0...3.0)
            } else if eventType < 0.6 { // 疲劳补觉
                sleepHours += generator.nextDouble(in: 1.0...2.5)
            } else { // 其他干扰
                sleepHours *= generator.nextDouble(in: 0.7...1.3)
            }
        }
        
        // 7. 连续性约束（适当放宽，允许更大的周期性变化）
        if let lastSleepHours = recentSleepHours.last {
            let maxDiff = isWeekend ? 3.0 : 2.0 // 周末允许更大变化
            if abs(sleepHours - lastSleepHours) > maxDiff {
                if sleepHours > lastSleepHours {
                    sleepHours = lastSleepHours + maxDiff
                } else {
                    sleepHours = lastSleepHours - maxDiff
                }
            }
        }
        
        // 8. 健康补偿：连续睡眠不足后的强制恢复
        if recentSleepHours.count >= 3 {
            let recentAverage = recentSleepHours.suffix(3).reduce(0, +) / 3.0
            if recentAverage < baseline - 1.0 { // 连续3天睡眠不足1小时以上
                sleepHours = baseline + generator.nextDouble(in: 0.5...1.5) // 强制补偿
            }
        }
        
        // 9. 限制在合理范围内 (医学建议：成人每日5-10小时睡眠)
        sleepHours = max(5.0, min(10.0, sleepHours))
        
        return sleepHours
    }
    
    // MARK: - 计算睡眠债务
    private static func calculateSleepDebt(recentSleepHours: [Double], baseline: Double) -> Double {
        guard !recentSleepHours.isEmpty else { return 0 }
        
        var totalDebt: Double = 0
        let daysToCheck = min(7, recentSleepHours.count)
        
        for i in 0..<daysToCheck {
            let sleepHours = recentSleepHours[recentSleepHours.count - 1 - i]
            let dailyDebt = max(0, baseline - sleepHours)
            
            // 越近期的债务权重越高
            let weight = 1.0 - (Double(i) * 0.1)
            totalDebt += dailyDebt * weight
        }
        
        return totalDebt
    }
    
    // MARK: - 计算睡眠压力
    private static func calculateSleepPressure(recentSleepHours: [Double], baseline: Double) -> Double {
        guard !recentSleepHours.isEmpty else { return 0 }
        
        let recentDays = min(5, recentSleepHours.count)
        let recentAverage = recentSleepHours.suffix(recentDays).reduce(0, +) / Double(recentDays)
        
        // 睡眠压力 = 理想睡眠时间 - 实际平均睡眠时间
        return max(0, baseline - recentAverage)
    }
    
    // MARK: - 生成睡眠数据
    private static func generateSleepData(date: Date, totalSleepHours: Double, mode: DataMode, generator: inout SeededRandomGenerator) -> SleepData {
        let calendar = Calendar.current
        
        // 生成入睡时间 21:00-24:00
        let bedHour = generator.nextInt(in: 21...23)
        let bedMinute = generator.nextInt(in: 0...59)
        
        var bedTimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        bedTimeComponents.hour = bedHour
        bedTimeComponents.minute = bedMinute
        let bedTime = calendar.date(from: bedTimeComponents)!
        
        // 先生成一个临时的起床时间用于生成睡眠阶段
        let totalSleepSeconds = totalSleepHours * 3600
        let temporaryWakeTime = bedTime.addingTimeInterval(totalSleepSeconds)
        
        // 生成睡眠阶段
        let sleepStages = generateSleepStages(
            bedTime: bedTime,
            wakeTime: temporaryWakeTime,
            totalSleepHours: totalSleepHours,
            mode: mode,
            generator: &generator
        )
        
        // 基于实际生成的睡眠段落计算真正的起床时间
        let actualWakeTime: Date
        if let lastStage = sleepStages.max(by: { $0.endTime < $1.endTime }) {
            actualWakeTime = lastStage.endTime
        } else {
            actualWakeTime = temporaryWakeTime
        }
        
        return SleepData(
            date: date,
            bedTime: bedTime,
            wakeTime: actualWakeTime,
            sleepStages: sleepStages
        )
    }
    
    // MARK: - 生成睡眠阶段
    private static func generateSleepStages(bedTime: Date, wakeTime: Date, totalSleepHours: Double, mode: DataMode, generator: inout SeededRandomGenerator) -> [SleepStage] {
        var stages: [SleepStage] = []
        
        switch mode {
        case .simple:
            // 简易模式：生成分段的卧床时间，模拟iPhone无穿戴设备的记录方式
            stages = generateSegmentedBedTime(
                bedTime: bedTime,
                wakeTime: wakeTime,
                totalSleepHours: totalSleepHours,
                generator: &generator
            )
            
        case .wearableDevice:
            // 模拟穿戴设备模式：生成详细的睡眠阶段
            // 入睡延迟：5-30分钟
            let sleepLatency = generator.nextDouble(in: 5...30) * 60
            let sleepStart = bedTime.addingTimeInterval(sleepLatency)
            
            // 生成4-6个睡眠周期
            let cycleCount = generator.nextInt(in: 4...6)
            let cycleLength = (totalSleepHours * 3600) / Double(cycleCount)
            
            var currentTime = sleepStart
            
            for cycle in 0..<cycleCount {
                let remainingTime = wakeTime.timeIntervalSince(currentTime)
                let thisCycleLength = min(cycleLength, remainingTime)
                
                if thisCycleLength <= 0 { break }
                
                // 生成周期内的睡眠阶段
                let cycleStages = generateSleepCycle(
                    startTime: currentTime,
                    duration: thisCycleLength,
                    cycleIndex: cycle,
                    totalCycles: cycleCount,
                    generator: &generator
                )
                
                stages.append(contentsOf: cycleStages)
                currentTime = currentTime.addingTimeInterval(thisCycleLength)
            }
            
            // 添加夜间清醒
            stages = addNightWakeEvents(stages: stages, generator: &generator)
        }
        
        return stages
    }
    
    // MARK: - 生成分段卧床时间（简易模式）
    private static func generateSegmentedBedTime(bedTime: Date, wakeTime: Date, totalSleepHours: Double, generator: inout SeededRandomGenerator) -> [SleepStage] {
        var stages: [SleepStage] = []
        
        // 总睡眠时间（秒）
        let totalSleepSeconds = totalSleepHours * 3600
        var allocatedSleepSeconds: TimeInterval = 0
        
        // 生成主要睡眠段（占总睡眠时间的75-85%）
        let mainSleepRatio = generator.nextDouble(in: 0.75...0.85)
        let mainSleepDuration = totalSleepSeconds * mainSleepRatio
        allocatedSleepSeconds += mainSleepDuration
        
        // 主睡眠段的开始时间（入睡后10分钟到1小时内）
        let mainSleepStart = bedTime.addingTimeInterval(generator.nextDouble(in: 600...3600)) // 10分钟到1小时
        let mainSleepEnd = mainSleepStart.addingTimeInterval(mainSleepDuration)
        
        // 添加主睡眠段
        stages.append(SleepStage(
            stage: .light,
            startTime: mainSleepStart,
            endTime: mainSleepEnd
        ))
        
        // 剩余时间分配给其他段落
        let remainingSleepSeconds = totalSleepSeconds - allocatedSleepSeconds
        
        // 生成入睡前的小段睡眠（使用剩余时间的25-40%）
        let beforeSleepRatio = generator.nextDouble(in: 0.25...0.40)
        let beforeSleepTotalDuration = remainingSleepSeconds * beforeSleepRatio
        var beforeSleepUsedDuration: TimeInterval = 0
        
        let beforeSleepSegmentCount = generator.nextInt(in: 0...2)
        for _ in 0..<beforeSleepSegmentCount {
            let remainingBeforeSleep = beforeSleepTotalDuration - beforeSleepUsedDuration
            if remainingBeforeSleep <= 0 { break }
            
            let segmentStart = bedTime.addingTimeInterval(generator.nextDouble(in: 0...1800)) // 就寝后30分钟内
            let maxSegmentDuration = min(remainingBeforeSleep, 600) // 最多10分钟
            let segmentDuration = min(generator.nextDouble(in: 60...600), maxSegmentDuration)
            let segmentEnd = segmentStart.addingTimeInterval(segmentDuration)
            
            // 确保不与主睡眠段重叠
            if segmentEnd < mainSleepStart {
                stages.append(SleepStage(
                    stage: .light,
                    startTime: segmentStart,
                    endTime: segmentEnd
                ))
                beforeSleepUsedDuration += segmentDuration
                allocatedSleepSeconds += segmentDuration
            }
        }
        
        // 生成主睡眠后的"起夜"段落（使用剩余的所有时间）
        let afterSleepTotalDuration = totalSleepSeconds - allocatedSleepSeconds
        var afterSleepUsedDuration: TimeInterval = 0
        
        let nightActivityCount = generator.nextInt(in: 5...12)
        var currentTime = mainSleepEnd
        
        for _ in 0..<nightActivityCount {
            let remainingAfterSleep = afterSleepTotalDuration - afterSleepUsedDuration
            if remainingAfterSleep <= 0 { break }
            
            // 间隔时间（1-15分钟）
            let intervalDuration = generator.nextDouble(in: 60...900) // 1-15分钟
            let segmentStart = currentTime.addingTimeInterval(intervalDuration)
            
            // 确保不超过起床时间
            if segmentStart >= wakeTime {
                break
            }
            
            // 段落持续时间（从剩余时间中分配）
            let maxSegmentDuration = min(remainingAfterSleep, 1200) // 最多20分钟
            let segmentDuration: TimeInterval
            let randomValue = generator.nextDouble(in: 0...1)
            
            if randomValue < 0.3 { // 30%概率：0分钟段（瞬间检测）
                segmentDuration = 0
            } else if randomValue < 0.6 { // 30%概率：1-3分钟段（短暂翻身）
                segmentDuration = min(generator.nextDouble(in: 60...180), maxSegmentDuration)
            } else if randomValue < 0.85 { // 25%概率：3-10分钟段（起夜、玩手机）
                segmentDuration = min(generator.nextDouble(in: 180...600), maxSegmentDuration)
            } else { // 15%概率：10-20分钟段（长时间玩手机）
                segmentDuration = min(generator.nextDouble(in: 600...1200), maxSegmentDuration)
            }
            
            let segmentEnd = segmentStart.addingTimeInterval(segmentDuration)
            
            // 确保不超过起床时间
            if segmentEnd <= wakeTime {
                stages.append(SleepStage(
                    stage: .light,
                    startTime: segmentStart,
                    endTime: segmentEnd
                ))
                
                afterSleepUsedDuration += segmentDuration
                allocatedSleepSeconds += segmentDuration
                currentTime = segmentEnd
            } else {
                // 如果会超过起床时间，调整为刚好到起床时间
                if segmentStart < wakeTime {
                    let adjustedDuration = wakeTime.timeIntervalSince(segmentStart)
                    stages.append(SleepStage(
                        stage: .light,
                        startTime: segmentStart,
                        endTime: wakeTime
                    ))
                    afterSleepUsedDuration += adjustedDuration
                    allocatedSleepSeconds += adjustedDuration
                }
                break
            }
        }
        
        // 如果还有剩余时间，创建最后一个段落确保总时长准确
        let finalRemainingDuration = totalSleepSeconds - allocatedSleepSeconds
        if finalRemainingDuration > 30 { // 如果剩余时间超过30秒
            let lastSegmentStart = max(currentTime.addingTimeInterval(30), wakeTime.addingTimeInterval(-finalRemainingDuration))
            let lastSegmentEnd = lastSegmentStart.addingTimeInterval(finalRemainingDuration)
            
            if lastSegmentEnd <= wakeTime {
                stages.append(SleepStage(
                    stage: .light,
                    startTime: lastSegmentStart,
                    endTime: lastSegmentEnd
                ))
            }
        }
        
        // 按时间排序
        stages.sort { $0.startTime < $1.startTime }
        
        return stages
    }
    
    // MARK: - 生成单个睡眠周期
    private static func generateSleepCycle(startTime: Date, duration: TimeInterval, cycleIndex: Int, totalCycles: Int, generator: inout SeededRandomGenerator) -> [SleepStage] {
        var stages: [SleepStage] = []
        var currentTime = startTime
        let endTime = startTime.addingTimeInterval(duration)
        
        // 早期周期：更多深度睡眠
        // 后期周期：更多REM睡眠
        let deepSleepRatio = cycleIndex < totalCycles/2 ? 0.25 : 0.15
        let remSleepRatio = cycleIndex < totalCycles/2 ? 0.15 : 0.30
        let lightSleepRatio = 1.0 - deepSleepRatio - remSleepRatio
        
        // 轻度睡眠
        let lightDuration = duration * lightSleepRatio
        stages.append(SleepStage(
            stage: .light,
            startTime: currentTime,
            endTime: currentTime.addingTimeInterval(lightDuration)
        ))
        currentTime = currentTime.addingTimeInterval(lightDuration)
        
        // 深度睡眠
        let deepDuration = duration * deepSleepRatio
        if currentTime.addingTimeInterval(deepDuration) <= endTime {
            stages.append(SleepStage(
                stage: .deep,
                startTime: currentTime,
                endTime: currentTime.addingTimeInterval(deepDuration)
            ))
            currentTime = currentTime.addingTimeInterval(deepDuration)
        }
        
        // REM睡眠
        let remDuration = endTime.timeIntervalSince(currentTime)
        if remDuration > 0 {
            stages.append(SleepStage(
                stage: .rem,
                startTime: currentTime,
                endTime: endTime
            ))
        }
        
        return stages
    }
    
    // MARK: - 添加夜间清醒事件
    private static func addNightWakeEvents(stages: [SleepStage], generator: inout SeededRandomGenerator) -> [SleepStage] {
        var modifiedStages = stages
        
        // 生成1-5次夜间清醒
        let wakeCount = generator.nextInt(in: 1...5)
        
        for _ in 0..<wakeCount {
            // 随机选择一个睡眠阶段插入清醒
            let stageIndex = generator.nextInt(in: 0...(modifiedStages.count - 1))
            let originalStage = modifiedStages[stageIndex]
            
            // 清醒时长：5-30分钟
            let wakeDuration = generator.nextDouble(in: 5...30) * 60
            
            // 在阶段中间插入清醒
            let stageDuration = originalStage.duration
            if stageDuration > wakeDuration * 2 {
                let wakeStart = originalStage.startTime.addingTimeInterval(stageDuration / 2)
                let wakeEnd = wakeStart.addingTimeInterval(wakeDuration)
                
                // 分割原阶段
                let beforeStage = SleepStage(
                    stage: originalStage.stage,
                    startTime: originalStage.startTime,
                    endTime: wakeStart
                )
                
                let wakeStage = SleepStage(
                    stage: .awake,
                    startTime: wakeStart,
                    endTime: wakeEnd
                )
                
                let afterStage = SleepStage(
                    stage: originalStage.stage,
                    startTime: wakeEnd,
                    endTime: originalStage.endTime
                )
                
                modifiedStages[stageIndex] = beforeStage
                modifiedStages.insert(wakeStage, at: stageIndex + 1)
                modifiedStages.insert(afterStage, at: stageIndex + 2)
            }
        }
        
        return modifiedStages
    }
    
    // MARK: - 生成步数数据（增强版：睡眠关联性）
    static func generateStepsData(date: Date, baseline: Int, sleepData: SleepData?, mode: DataMode = .simple, generator: inout SeededRandomGenerator) -> StepsData {
        var totalSteps = baseline
        
        // 1. 睡眠质量对活动的影响
        if let sleepData = sleepData {
            let sleepQualityFactor = calculateSleepQualityImpact(sleepData: sleepData)
            totalSteps = Int(Double(totalSteps) * sleepQualityFactor)
        }
        
        // 2. 周末vs工作日的步数差异
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        
        if isWeekend {
            // 周末步数模式：更随机，可能很高（户外活动）或很低（宅家）
            let weekendPattern = generator.nextDouble(in: 0...1)
            if weekendPattern < 0.3 { // 30% 宅家模式
                totalSteps = Int(Double(totalSteps) * generator.nextDouble(in: 0.4...0.8))
            } else if weekendPattern < 0.7 { // 40% 正常活动
                totalSteps = Int(Double(totalSteps) * generator.nextDouble(in: 0.8...1.2))
            } else { // 30% 户外活动模式
                totalSteps = Int(Double(totalSteps) * generator.nextDouble(in: 1.3...2.0))
            }
        }
        
        // 3. 基础日常波动（减小范围，因为睡眠影响已经考虑）
        let dailyVariation = generator.nextDouble(in: -0.20...0.20)
        totalSteps = Int(Double(totalSteps) * (1 + dailyVariation))
        
        // 4. 特殊事件（降低概率，增加影响）
        if generator.nextDouble(in: 0...1) < 0.10 { // 10%概率
            let eventType = generator.nextDouble(in: 0...1)
            if eventType < 0.2 { // 生病/不适
                totalSteps = Int(Double(totalSteps) * generator.nextDouble(in: 0.2...0.6))
            } else if eventType < 0.4 { // 特别忙碌（久坐）
                totalSteps = Int(Double(totalSteps) * generator.nextDouble(in: 0.3...0.7))
            } else if eventType < 0.6 { // 外出购物/社交
                totalSteps = Int(Double(totalSteps) * generator.nextDouble(in: 1.5...2.5))
            } else if eventType < 0.8 { // 运动/锻炼
                totalSteps = Int(Double(totalSteps) * generator.nextDouble(in: 1.8...3.0))
            } else { // 旅行/徒步
                totalSteps = Int(Double(totalSteps) * generator.nextDouble(in: 2.0...4.0))
            }
        }
        
        // 5. 限制在合理范围内
        totalSteps = max(200, min(25000, totalSteps))
        
        // 6. 生成日内分布（考虑睡眠时间和活动模式）
        let hourlySteps = generateHourlySteps(
            date: date,
            totalSteps: totalSteps,
            sleepData: sleepData,
            mode: mode,
            generator: &generator
        )
        
        return StepsData(
            date: date,
            hourlySteps: hourlySteps
        )
    }
    
    // MARK: - 计算睡眠质量对步数的影响
    private static func calculateSleepQualityImpact(sleepData: SleepData) -> Double {
        let sleepHours = sleepData.totalSleepHours
        
        // 睡眠时长对活动积极性的影响
        var impactFactor: Double = 1.0
        
        if sleepHours < 5.0 {
            // 严重睡眠不足：活动显著减少
            impactFactor = 0.5 + (sleepHours / 5.0) * 0.3 // 0.5-0.8
        } else if sleepHours < 6.5 {
            // 轻度睡眠不足：活动适度减少
            impactFactor = 0.8 + ((sleepHours - 5.0) / 1.5) * 0.15 // 0.8-0.95
        } else if sleepHours <= 8.5 {
            // 理想睡眠：正常或略微增加活动
            impactFactor = 0.95 + ((sleepHours - 6.5) / 2.0) * 0.15 // 0.95-1.1
        } else if sleepHours <= 10.0 {
            // 睡眠较多：可能略微降低活动（起床较晚）
            impactFactor = 1.1 - ((sleepHours - 8.5) / 1.5) * 0.2 // 1.1-0.9
        } else {
            // 睡眠过多：活动明显减少（可能身体不适或周末懒惰）
            impactFactor = 0.9 - ((sleepHours - 10.0) / 2.0) * 0.3 // 0.9-0.6
        }
        
        // 睡眠分段数对精神状态的影响
        let segmentCount = sleepData.sleepStages.count
        if segmentCount > 8 { // 睡眠分段过多，质量差
            impactFactor *= 0.85 // 活动减少15%
        } else if segmentCount > 6 {
            impactFactor *= 0.95 // 活动减少5%
        }
        
        // 起床时间对当天活动的影响
        let calendar = Calendar.current
        let wakeHour = calendar.component(.hour, from: sleepData.wakeTime)
        
        if wakeHour <= 6 { // 很早起床：可能有晨练习惯
            impactFactor *= 1.1
        } else if wakeHour >= 10 { // 晚起：下午活动时间减少
            impactFactor *= 0.9
        } else if wakeHour >= 11 { // 很晚起：活动时间显著减少
            impactFactor *= 0.8
        }
        
        return max(0.3, min(2.0, impactFactor))
    }
    
    // MARK: - 生成小时步数分布（基于睡眠数据精确分配）
    private static func generateHourlySteps(date: Date, totalSteps: Int, sleepData: SleepData?, mode: DataMode = .simple, generator: inout SeededRandomGenerator) -> [HourlySteps] {
        let calendar = Calendar.current
        
        // 清醒时间的活跃度权重分布
        let awakeActivityWeights: [Int: Double] = [
            0: 0.01,   // 深夜清醒（可能失眠、夜班等）
            1: 0.01,
            2: 0.01,
            3: 0.01,
            4: 0.01,
            5: 0.02,   // 早起
            6: 0.04,   // 早起准备
            7: 0.08,   // 起床洗漱
            8: 0.12,   // 上班通勤高峰
            9: 0.10,   // 上午工作
            10: 0.08,  // 上午工作
            11: 0.09,  // 上午会议走动
            12: 0.11,  // 午餐外出
            13: 0.06,  // 午休
            14: 0.09,  // 下午工作
            15: 0.08,  // 下午工作
            16: 0.09,  // 下午会议
            17: 0.11,  // 下班通勤
            18: 0.12,  // 晚餐运动（一天最活跃）
            19: 0.08,  // 晚间活动
            20: 0.06,  // 晚间放松
            21: 0.04,  // 准备休息
            22: 0.03,  // 睡前活动
            23: 0.02   // 睡前
        ]
        
        // 获取当天的睡眠时间段（根据模式正确过滤）
        var sleepTimeRanges: [(start: Date, end: Date)] = []
        if let sleepData = sleepData {
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            for stage in sleepData.sleepStages {
                // 根据模式判断是否为睡眠时间段
                let isSleepStage: Bool
                switch mode {
                case .simple:
                    // 简易模式：所有阶段都是卧床时间，都算作睡眠
                    isSleepStage = true
                case .wearableDevice:
                    // 穿戴设备模式：只有非清醒阶段才算作睡眠
                    isSleepStage = stage.stage != .awake
                }
                
                if isSleepStage {
                    let segmentStart = max(stage.startTime, dayStart)
                    let segmentEnd = min(stage.endTime, dayEnd)
                    
                    if segmentStart < segmentEnd {
                        sleepTimeRanges.append((start: segmentStart, end: segmentEnd))
                    }
                }
            }
        }
        
        // 分析每小时的睡眠状态和清醒权重
        var hourlyData: [(hour: Int, startTime: Date, endTime: Date, sleepRatio: Double, awakeWeight: Double)] = []
        var totalAwakeWeight: Double = 0
        
        for hour in 0..<24 {
            var hourComponents = calendar.dateComponents([.year, .month, .day], from: date)
            hourComponents.hour = hour
            hourComponents.minute = 0
            let hourStart = calendar.date(from: hourComponents)!
            let hourEnd = hourStart.addingTimeInterval(3600)
            
            // 计算这一小时的睡眠比例
            let sleepRatio = calculateSleepRatioForHour(
                hourStart: hourStart,
                hourEnd: hourEnd,
                sleepRanges: sleepTimeRanges
            )
            
            // 计算清醒时间的权重
            let baseWeight = awakeActivityWeights[hour] ?? 0.01
            let awakeRatio = 1.0 - sleepRatio
            let awakeWeight = baseWeight * awakeRatio
            
            totalAwakeWeight += awakeWeight
            
            hourlyData.append((
                hour: hour,
                startTime: hourStart,
                endTime: hourEnd,
                sleepRatio: sleepRatio,
                awakeWeight: awakeWeight
            ))
        }
        
        // 计算每小时的初始步数分配（严格限制睡眠期间步数）
        var hourlyStepsArray: [Int] = []
        
        for data in hourlyData {
            var steps = 0
            
            if data.sleepRatio >= 0.90 {
                // 深度睡眠时间（90%以上睡眠）：完全无步数
                steps = 0
            } else if data.sleepRatio >= 0.70 {
                // 主要睡眠时间（70-90%睡眠）：95%为0步，5%为个位数步数
                steps = generator.nextDouble(in: 0...1) < 0.05 ? generator.nextInt(in: 1...9) : 0
            } else if data.sleepRatio >= 0.30 {
                // 轻度睡眠/入睡时间（30-70%睡眠）：很少步数
                let maxSteps = max(1, Int(Double(totalSteps) * 0.001)) // 最多0.1%的总步数
                steps = generator.nextDouble(in: 0...1) < 0.3 ? generator.nextInt(in: 0...maxSteps) : 0
            } else if data.sleepRatio > 0.05 {
                // 轻微睡眠/准备睡觉时间（5-30%睡眠）：少量步数
                let maxSteps = max(2, Int(Double(totalSteps) * 0.005)) // 最多0.5%的总步数
                steps = generator.nextDouble(in: 0...1) < 0.6 ? generator.nextInt(in: 0...maxSteps) : 0
            } else {
                // 清醒时间（睡眠比例<5%）：根据权重分配步数
                if totalAwakeWeight > 0 {
                    let stepRatio = data.awakeWeight / totalAwakeWeight
                    let allocatedSteps = Int(Double(totalSteps) * stepRatio)
                    
                    // 添加自然波动 ±30%
                    let variation = generator.nextDouble(in: -0.30...0.30)
                    steps = max(0, Int(Double(allocatedSteps) * (1 + variation)))
                    
                    // 限制单小时最大步数
                    let maxHourlySteps = Int(Double(totalSteps) * 0.20) // 最多20%
                    steps = min(steps, maxHourlySteps)
                }
            }
            
            hourlyStepsArray.append(steps)
        }
        
        // 确保总步数准确性：将差值分配给最活跃的清醒时段
        let currentTotal = hourlyStepsArray.reduce(0, +)
        let difference = totalSteps - currentTotal
        
        if abs(difference) > 0 {
            // 找出最活跃的清醒时段（8-20点，且睡眠比例<50%）
            let activeAwakeHours = hourlyData.enumerated().filter { (index, data) in
                data.hour >= 8 && data.hour <= 20 && data.sleepRatio < 0.5
            }.sorted { $0.element.awakeWeight > $1.element.awakeWeight }
            
            if !activeAwakeHours.isEmpty {
                let topActiveHours = Array(activeAwakeHours.prefix(6)) // 取最活跃的6小时
                let stepsPerHour = difference / topActiveHours.count
                let remainder = difference % topActiveHours.count
                
                for (adjustIndex, (hourIndex, _)) in topActiveHours.enumerated() {
                    let adjustment = stepsPerHour + (adjustIndex < remainder ? (difference > 0 ? 1 : -1) : 0)
                    hourlyStepsArray[hourIndex] = max(0, hourlyStepsArray[hourIndex] + adjustment)
                }
            }
        }
        
        // 创建最终的HourlySteps数组
        var hourlySteps: [HourlySteps] = []
        for (index, data) in hourlyData.enumerated() {
            hourlySteps.append(HourlySteps(
                hour: data.hour,
                steps: hourlyStepsArray[index],
                startTime: data.startTime,
                endTime: data.endTime
            ))
        }
        
        return hourlySteps
    }
    
    // MARK: - 计算小时内睡眠时间比例
    private static func calculateSleepRatioForHour(
        hourStart: Date,
        hourEnd: Date,
        sleepRanges: [(start: Date, end: Date)]
    ) -> Double {
        let hourDuration = hourEnd.timeIntervalSince(hourStart)
        var sleepDuration: TimeInterval = 0
        
        for sleepRange in sleepRanges {
            // 计算睡眠时间段与当前小时的交集
            let overlapStart = max(hourStart, sleepRange.start)
            let overlapEnd = min(hourEnd, sleepRange.end)
            
            if overlapStart < overlapEnd {
                sleepDuration += overlapEnd.timeIntervalSince(overlapStart)
            }
        }
        
        return min(1.0, sleepDuration / hourDuration)
    }
    
    // MARK: - 生成种子
    private static func generateSeed(from string: String) -> Int {
        return abs(string.hashValue)
    }
} 