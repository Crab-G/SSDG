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
        let calendar = Calendar.current
        let now = Date()
        
        // 🔥 关键修复：睡眠数据只能生成到昨天，步数数据最多到今天当前时间
        let todayStart = calendar.startOfDay(for: now)
        let _ = calendar.date(byAdding: .day, value: -1, to: todayStart)! // yesterdayStart for reference
        
        // 睡眠数据的结束日期：今天开始（不包含今天，但包含昨天）
        let sleepEndDate = todayStart
        
        // 步数数据的结束日期：今天开始（但生成时会检查当前时间）
        let stepsEndDate = todayStart
        
        let startDate = calendar.date(byAdding: .day, value: -days, to: sleepEndDate)!
        
        var sleepData: [SleepData] = []
        var stepsData: [StepsData] = []
        
        // 使用用户ID作为种子，确保数据一致性
        let seed = generateSeed(from: user.id)
        var generator = SeededRandomGenerator(seed: UInt64(seed))
        
        // 生成每天的数据
        var currentDate = startDate
        var recentSleepHours: [Double] = [] // 用于连续性检查
        
        while currentDate < sleepEndDate {
            // 生成睡眠数据（历史数据）
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
            
            // 生成步数数据（历史数据）
            let steps = generateStepsData(
                date: currentDate,
                baseline: user.stepsBaseline,
                sleepData: sleep,
                mode: mode,
                generator: &generator
            )
            stepsData.append(steps)
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // 🔥 特殊处理：生成今天的步数数据（不包含睡眠数据）
        if currentDate == stepsEndDate && stepsEndDate < calendar.date(byAdding: .day, value: 1, to: todayStart)! {
            let todaySteps = generateTodayStepsData(
                date: todayStart,
                baseline: user.stepsBaseline,
                currentTime: now,
                recentStepsData: Array(stepsData.suffix(7)), // 最近7天用于趋势分析
                mode: mode,
                generator: &generator
            )
            stepsData.append(todaySteps)
        }
        
        return (sleepData, stepsData)
    }
    
    // MARK: - 生成每日数据（增强版：双向关联 + 严格时间控制）
    static func generateDailyData(for user: VirtualUser, recentSleepData: [SleepData], recentStepsData: [StepsData], mode: DataMode = .simple) -> (sleepData: SleepData?, stepsData: StepsData) {
        let calendar = Calendar.current
        let now = Date()
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        
        // 🔥 关键修复：只能生成昨天的完整数据，今天只生成步数数据
        return generateDailyData(for: user, date: yesterdayStart, recentSleepData: recentSleepData, recentStepsData: recentStepsData, mode: mode)
    }
    
    // 重载方法：支持指定日期（带时间边界检查）
    static func generateDailyData(for user: VirtualUser, date: Date, recentSleepData: [SleepData], recentStepsData: [StepsData], mode: DataMode = .simple) -> (sleepData: SleepData?, stepsData: StepsData) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        // 🔥 修复时间边界：今日不生成睡眠数据，只生成步数数据
        if date >= todayStart {
            print("📅 今日数据生成：只生成步数数据，不生成今晚睡眠数据")
            
            // 🔧 改进种子生成：使用更多变化因子
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
            let seedInput = user.id + dateString + String(dayOfYear) + "daily"
            let seed = generateSeed(from: seedInput)
            var generator = SeededRandomGenerator(seed: UInt64(seed))
            
            // 生成当天步数（到当前时间）
            let todaySteps = generateCurrentDayStepsData(
                user: user,
                date: date,
                currentTime: now,
                recentStepsData: Array(recentStepsData.suffix(7)),
                recentSleepData: Array(recentSleepData.suffix(7)),
                mode: mode,
                generator: &generator
            )
            
            return (sleepData: nil, stepsData: todaySteps)  // 今日不返回睡眠数据
        }
        
        // 🔧 改进种子生成：使用更多变化因子
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let seedInput = user.id + dateString + String(dayOfYear) + "daily"
        let seed = generateSeed(from: seedInput)
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
        
        return (sleepData: sleepData, stepsData: stepsData)
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
        // 🔧 改进种子生成：使用更多变化因子
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let seedInput = user.id + dateString + String(dayOfYear) + "sleep"
        let seed = generateSeed(from: seedInput)
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
        // 🔧 改进种子生成：使用更多变化因子
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let seedInput = user.id + dateString + String(dayOfYear) + "steps"
        let seed = generateSeed(from: seedInput)
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
        
        // 生成睡眠中断次数（1-4次，模拟真实的夜间醒来）
        let interruptionCount = generator.nextInt(in: 1...4)
        
        // 计算每个睡眠段的基础时长
        let segmentCount = interruptionCount + 1
        let baseSegmentDuration = totalSleepSeconds / Double(segmentCount)
        
        // 入睡延迟（5-30分钟）
        let sleepLatency = generator.nextDouble(in: 300...1800)
        var currentTime = bedTime.addingTimeInterval(sleepLatency)
        
        // 生成睡眠段落
        for i in 0..<segmentCount {
            // 添加睡眠段落的随机变化（±30%）
            let variation = generator.nextDouble(in: -0.3...0.3)
            let segmentDuration = baseSegmentDuration * (1 + variation)
            
            // 确保不超过剩余可分配时间
            let remainingTime = totalSleepSeconds - allocatedSleepSeconds
            let actualSegmentDuration = min(segmentDuration, remainingTime)
            
            if actualSegmentDuration <= 0 { break }
            
            let segmentEnd = currentTime.addingTimeInterval(actualSegmentDuration)
            
            // 确保不超过起床时间
            if segmentEnd > wakeTime {
                let adjustedDuration = wakeTime.timeIntervalSince(currentTime)
                if adjustedDuration > 60 { // 至少1分钟
                    stages.append(SleepStage(
                        stage: .light,
                        startTime: currentTime,
                        endTime: wakeTime
                    ))
                }
                break
            }
            
            stages.append(SleepStage(
                stage: .light,
                startTime: currentTime,
                endTime: segmentEnd
            ))
            
            allocatedSleepSeconds += actualSegmentDuration
            
            // 如果不是最后一个段落，添加中断（醒来时间）
            if i < segmentCount - 1 {
                // 中断时长（2-30分钟，模拟上厕所、喝水、查看手机等）
                let interruptionType = generator.nextDouble(in: 0...1)
                let interruptionDuration: TimeInterval
                
                if interruptionType < 0.5 { // 50%：短暂醒来（2-5分钟）
                    interruptionDuration = generator.nextDouble(in: 120...300)
                } else if interruptionType < 0.8 { // 30%：中等醒来（5-15分钟）
                    interruptionDuration = generator.nextDouble(in: 300...900)
                } else { // 20%：长时间醒来（15-30分钟）
                    interruptionDuration = generator.nextDouble(in: 900...1800)
                }
                
                currentTime = segmentEnd.addingTimeInterval(interruptionDuration)
            }
        }
        
        // 添加早晨醒来前的短暂睡眠段（模拟赖床）
        if allocatedSleepSeconds < totalSleepSeconds && currentTime < wakeTime {
            let remainingTime = wakeTime.timeIntervalSince(currentTime)
            let lastSegmentProbability = generator.nextDouble(in: 0...1)
            
            if lastSegmentProbability < 0.7 && remainingTime > 1800 { // 70%概率有赖床段
                // 最后醒来前的时间（10-30分钟）
                let prewakeGap = generator.nextDouble(in: 600...1800)
                let lastSegmentStart = wakeTime.addingTimeInterval(-prewakeGap)
                
                if lastSegmentStart > currentTime.addingTimeInterval(300) { // 至少5分钟间隔
                    // 赖床时长（5-20分钟）
                    let lazyDuration = generator.nextDouble(in: 300...1200)
                    let lazyEnd = min(lastSegmentStart.addingTimeInterval(lazyDuration), wakeTime)
                    
                    stages.append(SleepStage(
                        stage: .light,
                        startTime: lastSegmentStart,
                        endTime: lazyEnd
                    ))
                }
            }
        }
        
        // 按时间排序
        stages.sort { $0.startTime < $1.startTime }
        
        // 合并过于接近的段落（间隔小于2分钟的）
        var mergedStages: [SleepStage] = []
        var i = 0
        while i < stages.count {
            if i < stages.count - 1 {
                let currentStage = stages[i]
                let nextStage = stages[i + 1]
                let gap = nextStage.startTime.timeIntervalSince(currentStage.endTime)
                
                if gap < 120 { // 间隔小于2分钟，合并
                    mergedStages.append(SleepStage(
                        stage: .light,
                        startTime: currentStage.startTime,
                        endTime: nextStage.endTime
                    ))
                    i += 2 // 跳过下一个段落
                } else {
                    mergedStages.append(currentStage)
                    i += 1
                }
            } else {
                mergedStages.append(stages[i])
                i += 1
            }
        }
        
        return mergedStages
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
        // 🔧 修复：提高最小步数保护从200到800步
        totalSteps = max(800, min(25000, totalSteps))
        
        // 6. 生成日内分布（考虑睡眠时间和活动模式）
        let hourlySteps = generateHourlySteps(
            date: date,
            totalSteps: totalSteps,
            sleepData: sleepData,
            mode: mode,
            generator: &generator
        )
        
        // 生成真实iPhone风格的随机步数记录块
        let stepsIntervals = generateRealisticiPhoneStepsSamples(
            date: date,
            hourlyStepsArray: hourlySteps,
            sleepData: sleepData,
            generator: &generator
        )
        
        return StepsData(
            date: date,
            hourlySteps: hourlySteps,
            stepsIntervals: stepsIntervals
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
            // 🔥 使用真实传感器时间模拟
            hourComponents.minute = generateRealisticMinute(for: hour, generator: &generator)
            hourComponents.second = generateRealisticSecond(generator: &generator)
            let hourStart = calendar.date(from: hourComponents)!
            
            // 结束时间也添加随机分秒偏移，但保证在下个小时内
            let randomOffset = generator.nextInt(in: 30...90) * 60 // 30-90分钟的随机偏移
            let hourEnd = hourStart.addingTimeInterval(TimeInterval(randomOffset))
            
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
        
        // 首先生成起夜行为（整晚0-2次起夜）
        let nightBathroomVisits = generateNightBathroomVisits(
            sleepRanges: sleepTimeRanges,
            generator: &generator
        )
        
        // 计算每小时的初始步数分配（超严格限制睡眠期间步数）
        var hourlyStepsArray: [Int] = []
        
        for data in hourlyData {
            var steps = 0
            
            if data.sleepRatio >= 0.95 {
                // 深度睡眠时间（95%以上睡眠）：完全无步数
                steps = 0
                
                // 检查是否有起夜行为
                for visit in nightBathroomVisits {
                    if visit.startTime >= data.startTime && visit.startTime < data.endTime {
                        steps = visit.steps
                        break
                    }
                }
                
            } else if data.sleepRatio >= 0.80 {
                // 主要睡眠时间（80-95%睡眠）：99.5%为0步，0.5%为1-2步（翻身）
                if generator.nextDouble(in: 0...1) < 0.005 {
                    steps = generator.nextInt(in: 1...2) // 翻身微动
                } else {
                    steps = 0
                }
                
                // 检查是否有起夜行为
                for visit in nightBathroomVisits {
                    if visit.startTime >= data.startTime && visit.startTime < data.endTime {
                        steps = visit.steps
                        break
                    }
                }
                
            } else if data.sleepRatio >= 0.50 {
                // 轻度睡眠时间（50-80%睡眠）：99%为0步，1%为1-3步
                if generator.nextDouble(in: 0...1) < 0.01 {
                    steps = generator.nextInt(in: 1...3) // 轻微翻身
                } else {
                    steps = 0
                }
                
            } else if data.sleepRatio >= 0.20 {
                // 入睡/醒来时间（20-50%睡眠）：90%为0步，10%为1-8步（床上活动）
                if generator.nextDouble(in: 0...1) < 0.10 {
                    steps = generator.nextInt(in: 1...8) // 床上翻身、调整姿势
                } else {
                    steps = 0
                }
                
            } else if data.sleepRatio > 0.05 {
                // 准备睡觉/刚醒来时间（5-20%睡眠）：允许少量活动
                if generator.nextDouble(in: 0...1) < 0.3 {
                    steps = generator.nextInt(in: 1...15) // 准备睡觉的活动
                } else {
                    steps = 0
                }
                
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
            // 🔥 添加传感器噪声，使数据更真实
            let noisySteps = addSensorNoise(to: hourlyStepsArray[index], generator: &generator)
            
            hourlySteps.append(HourlySteps(
                hour: data.hour,
                steps: noisySteps,
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
    
    // MARK: - 起夜行为数据结构
    private struct NightBathroomVisit {
        let startTime: Date
        let steps: Int
    }
    
    // MARK: - 生成起夜行为
    private static func generateNightBathroomVisits(
        sleepRanges: [(start: Date, end: Date)],
        generator: inout SeededRandomGenerator
    ) -> [NightBathroomVisit] {
        var visits: [NightBathroomVisit] = []
        
        guard !sleepRanges.isEmpty else { return visits }
        
        // 80%的夜晚有0次起夜，15%有1次，5%有2次
        let visitCount: Int
        let randomValue = generator.nextDouble(in: 0...1)
        if randomValue < 0.80 {
            visitCount = 0
        } else if randomValue < 0.95 {
            visitCount = 1
        } else {
            visitCount = 2
        }
        
        guard visitCount > 0 else { return visits }
        
        // 计算总睡眠时间段
        let totalSleepDuration = sleepRanges.reduce(0.0) { total, range in
            total + range.end.timeIntervalSince(range.start)
        }
        
        // 如果睡眠时间少于4小时，减少起夜概率
        if totalSleepDuration < 4 * 3600 && generator.nextDouble(in: 0...1) < 0.7 {
            return visits // 短睡眠时间，70%概率不起夜
        }
        
        for _ in 0..<visitCount {
            // 选择一个睡眠时间段
            let rangeIndex = generator.nextInt(in: 0...(sleepRanges.count - 1))
            let selectedRange = sleepRanges[rangeIndex]
            
            // 在该时间段的中间80%时间内随机选择起夜时间
            let rangeDuration = selectedRange.end.timeIntervalSince(selectedRange.start)
            let startOffset = rangeDuration * 0.1 // 跳过前10%
            let endOffset = rangeDuration * 0.9   // 跳过后10%
            
            let randomOffset = generator.nextDouble(in: startOffset...endOffset)
            let visitTime = selectedRange.start.addingTimeInterval(randomOffset)
            
            // 生成起夜步数：根据不同情况
            let steps: Int
            let stepType = generator.nextDouble(in: 0...1)
            
            if stepType < 0.70 { // 70%：正常上厕所
                steps = generator.nextInt(in: 20...60) // 卧室到厕所往返
            } else if stepType < 0.85 { // 15%：喝水或轻微活动
                steps = generator.nextInt(in: 8...25) 
            } else if stepType < 0.95 { // 10%：检查什么或更长的厕所时间
                steps = generator.nextInt(in: 60...120)
            } else { // 5%：失眠起床活动
                steps = generator.nextInt(in: 100...200)
            }
            
            visits.append(NightBathroomVisit(
                startTime: visitTime,
                steps: steps
            ))
        }
        
        // 按时间排序
        visits.sort { $0.startTime < $1.startTime }
        
        // 确保起夜时间间隔至少1小时
        var filteredVisits: [NightBathroomVisit] = []
        for visit in visits {
            let tooClose = filteredVisits.contains { existingVisit in
                abs(visit.startTime.timeIntervalSince(existingVisit.startTime)) < 3600 // 1小时
            }
            
            if !tooClose {
                filteredVisits.append(visit)
            }
        }
        
        return filteredVisits
    }
    
    // MARK: - 生成今天的步数数据（严格时间边界控制）
    private static func generateTodayStepsData(
        date: Date,
        baseline: Int,
        currentTime: Date,
        recentStepsData: [StepsData],
        mode: DataMode,
        generator: inout SeededRandomGenerator
    ) -> StepsData {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentTime)
        let currentMinute = calendar.component(.minute, from: currentTime)
        
        // 计算到当前时间为止应该产生的总步数（按比例）
        let timeProgress = (Double(currentHour) + Double(currentMinute) / 60.0) / 24.0
        let expectedStepsToNow = Int(Double(baseline) * timeProgress * generator.nextDouble(in: 0.8...1.2))
        
        // 生成今天的活跃度权重分布（只到当前时间）
        let todayActivityWeights: [Int: Double] = [
            0: 0.01, 1: 0.01, 2: 0.01, 3: 0.01, 4: 0.01, 5: 0.02,
            6: 0.04, 7: 0.08, 8: 0.12, 9: 0.10, 10: 0.08, 11: 0.09,
            12: 0.11, 13: 0.06, 14: 0.09, 15: 0.08, 16: 0.09, 17: 0.11,
            18: 0.12, 19: 0.08, 20: 0.06, 21: 0.04, 22: 0.03, 23: 0.02
        ]
        
        var hourlySteps: [HourlySteps] = []
        var totalAllocatedSteps = 0
        
        // 生成已过去时间的步数
        for hour in 0...currentHour {
            var hourComponents = calendar.dateComponents([.year, .month, .day], from: date)
            hourComponents.hour = hour
            // 🔥 使用真实传感器时间模拟
            hourComponents.minute = generateRealisticMinute(for: hour, generator: &generator)
            hourComponents.second = generateRealisticSecond(generator: &generator)
            let hourStart = calendar.date(from: hourComponents)!
            
            var hourEnd: Date
            var steps: Int
            
            if hour < currentHour {
                // 已完全过去的小时：生成完整的步数
                let randomOffset = generator.nextInt(in: 30...90) * 60
                hourEnd = hourStart.addingTimeInterval(TimeInterval(randomOffset))
                
                let baseWeight = todayActivityWeights[hour] ?? 0.01
                let stepRatio = baseWeight / todayActivityWeights.values.reduce(0, +)
                let allocatedSteps = Int(Double(expectedStepsToNow) * stepRatio)
                
                let variation = generator.nextDouble(in: -0.30...0.30)
                steps = max(0, Int(Double(allocatedSteps) * (1 + variation)))
            } else {
                // 当前小时：只生成到当前分钟的步数
                let progressInHour = Double(currentMinute) / 60.0
                hourEnd = currentTime
                
                let baseWeight = todayActivityWeights[hour] ?? 0.01
                let stepRatio = baseWeight / todayActivityWeights.values.reduce(0, +)
                let fullHourSteps = Int(Double(expectedStepsToNow) * stepRatio)
                
                // 按当前小时的进度分配步数
                steps = Int(Double(fullHourSteps) * progressInHour)
                
                // 添加一些随机性，但不能超过合理范围
                let variation = generator.nextDouble(in: -0.20...0.20)
                steps = max(0, Int(Double(steps) * (1 + variation)))
            }
            
            // 🔥 添加传感器噪声使数据更真实
            let noisySteps = addSensorNoise(to: steps, generator: &generator)
            totalAllocatedSteps += noisySteps
            
            hourlySteps.append(HourlySteps(
                hour: hour,
                steps: noisySteps,
                startTime: hourStart,
                endTime: hourEnd
            ))
        }
        
        // 🔥 关键：不生成未来时间的步数数据
        // （不添加currentHour+1到23的数据）
        
        // 调整总步数，确保与预期接近
        let difference = expectedStepsToNow - totalAllocatedSteps
        if abs(difference) > 0 && !hourlySteps.isEmpty {
            // 将差值分配给最近的几个小时
            let activeHourCount = min(3, hourlySteps.count)
            let adjustmentPerHour = difference / activeHourCount
            let remainder = difference % activeHourCount
            
            // 重新创建需要调整的HourlySteps对象
            for i in (hourlySteps.count - activeHourCount)..<hourlySteps.count {
                let adjustment = adjustmentPerHour + (i < hourlySteps.count - remainder ? 0 : (difference > 0 ? 1 : -1))
                let adjustedSteps = max(0, hourlySteps[i].steps + adjustment)
                
                // 创建新的HourlySteps对象
                hourlySteps[i] = HourlySteps(
                    hour: hourlySteps[i].hour,
                    steps: adjustedSteps,
                    startTime: hourlySteps[i].startTime,
                    endTime: hourlySteps[i].endTime
                )
            }
        }
        
        return StepsData(
            date: date,
            hourlySteps: hourlySteps
        )
    }
    
    // MARK: - 生成种子（改进版，确保更多变化）
    private static func generateSeed(from string: String) -> Int {
        // 使用多重哈希确保更好的分布
        let hash1 = abs(string.hashValue)
        let hash2 = abs(String(string.reversed()).hashValue)
        let combinedHash = hash1 ^ (hash2 << 16)
        return abs(combinedHash) % 1000000  // 扩大种子范围
    }
    
    // MARK: - 真实传感器时间模拟
    private static func generateRealisticMinute(for hour: Int, generator: inout SeededRandomGenerator) -> Int {
        // 模拟真实iPhone传感器的采集模式
        // 不同时间段有不同的采集偏好
        switch hour {
        case 0...6:   // 深夜：更稀疏的采集
            return generator.nextInt(in: 0...59)
        case 7...9:   // 早晨：相对规律
            return generator.nextInt(in: 10...50)
        case 10...16: // 白天：活跃期，更频繁
            return generator.nextInt(in: 5...55)
        case 17...20: // 傍晚：较规律
            return generator.nextInt(in: 15...45)
        default:      // 晚上：逐渐减少
            return generator.nextInt(in: 0...59)
        }
    }
    
    private static func generateRealisticSecond(generator: inout SeededRandomGenerator) -> Int {
        // 真实传感器的秒级偏移通常不是完全随机的
        // 有一定的聚集性（某些秒数更常见）
        let commonSeconds = [0, 15, 30, 45] // 传感器常见采集点
        
        if generator.nextInt(in: 1...100) <= 40 { // 40%几率使用常见秒数
            return commonSeconds.randomElement() ?? 0
        } else {
            return generator.nextInt(in: 0...59)
        }
    }
    
    private static func generateRealisticDuration(generator: inout SeededRandomGenerator) -> TimeInterval {
        // 真实采集间隔不是固定1小时
        // 根据传感器特性，有一定的变化
        let baseInterval: TimeInterval = 3600 // 1小时
        let variation = Double(generator.nextInt(in: -600...600)) // ±10分钟变化
        
        return max(1800, baseInterval + variation) // 至少30分钟间隔
    }
    
    private static func addSensorNoise(to steps: Int, generator: inout SeededRandomGenerator) -> Int {
        // 添加传感器噪声，模拟真实计步器的微小误差
        guard steps > 0 else { return 0 }
        
        let noiseLevel = Double(generator.nextInt(in: -3...3)) / 100.0 // ±3%噪声
        let noisySteps = Double(steps) * (1.0 + noiseLevel)
        
        return max(0, Int(noisySteps.rounded()))
    }
    
    // MARK: - 生成当日步数数据（限制到当前时间）
    static func generateCurrentDayStepsData(
        user: VirtualUser,
        date: Date,
        currentTime: Date,
        recentStepsData: [StepsData],
        recentSleepData: [SleepData],
        mode: DataMode,
        generator: inout SeededRandomGenerator
    ) -> StepsData {
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        
        // 计算当前时间是今天的第几个小时
        let currentHour = calendar.component(.hour, from: currentTime)
        let currentMinute = calendar.component(.minute, from: currentTime)
        
        // 生成总步数（基于用户基准）
        let baseline = user.stepsBaseline
        let variation = generator.nextDouble(in: -0.15...0.15) // ±15%变化
        let totalSteps = max(0, Int(Double(baseline) * (1 + variation)))
        
        var hourlyStepsArray: [HourlySteps] = []
        
        // 为每个小时生成步数（只到当前时间）
        for hour in 0..<24 {
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: dateStart)!
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
            
            var steps: Int
            
            if hour < currentHour || (hour == currentHour && currentMinute >= 30) {
                // 已经过去的完整小时或当前小时过半
                steps = generateHourlySteps(
                    hour: hour,
                    totalSteps: totalSteps,
                    recentData: recentStepsData,
                    mode: mode,
                    generator: &generator
                )
            } else if hour == currentHour {
                // 当前小时，只生成到当前分钟的步数
                let fullHourSteps = generateHourlySteps(
                    hour: hour,
                    totalSteps: totalSteps,
                    recentData: recentStepsData,
                    mode: mode,
                    generator: &generator
                )
                
                // 按分钟比例计算
                let minuteRatio = Double(currentMinute) / 60.0
                steps = Int(Double(fullHourSteps) * minuteRatio)
            } else {
                // 未来的小时，步数为0
                steps = 0
            }
            
            hourlyStepsArray.append(HourlySteps(
                hour: hour,
                steps: steps,
                startTime: hourStart,
                endTime: hourEnd
            ))
        }
        
        // 获取最近的睡眠数据（通常是昨晚的）来影响今天的活动模式
        let relevantSleepData = recentSleepData.last
        
        // 生成真实iPhone风格的随机步数记录块（限制到当前时间）
        let stepsIntervals = generateRealisticiPhoneStepsSamplesForToday(
            date: date,
            currentTime: currentTime,
            hourlyStepsArray: hourlyStepsArray,
            sleepData: relevantSleepData,
            generator: &generator
        )
        
        return StepsData(
            date: date,
            hourlySteps: hourlyStepsArray,
            stepsIntervals: stepsIntervals
        )
    }
    
    // 生成单个小时的步数
    private static func generateHourlySteps(
        hour: Int,
        totalSteps: Int,
        recentData: [StepsData],
        mode: DataMode,
        generator: inout SeededRandomGenerator
    ) -> Int {
        // 根据时间段确定活跃度
        let activityMultiplier: Double
        
        switch hour {
        case 0...5:
            activityMultiplier = 0.01 // 深夜，几乎无活动
        case 6...7:
            activityMultiplier = 0.15 // 早起
        case 8...11:
            activityMultiplier = 0.20 // 上午活跃
        case 12...13:
            activityMultiplier = 0.12 // lunch时间
        case 14...17:
            activityMultiplier = 0.25 // 下午最活跃
        case 18...20:
            activityMultiplier = 0.18 // 晚餐后活动
        case 21...23:
            activityMultiplier = 0.08 // 晚上减少
        default:
            activityMultiplier = 0.05
        }
        
        // 基础步数分配
        let baseSteps = Int(Double(totalSteps) * activityMultiplier / 24.0)
        
        // 添加随机变化 ±30%
        let variation = generator.nextDouble(in: -0.30...0.30)
        let steps = max(0, Int(Double(baseSteps) * (1 + variation)))
        
        return steps
    }
    
    // 生成真实iPhone风格的随机步数记录块（今日版本 - 限制到当前时间）
    private static func generateRealisticiPhoneStepsSamplesForToday(
        date: Date,
        currentTime: Date,
        hourlyStepsArray: [HourlySteps],
        sleepData: SleepData?,
        generator: inout SeededRandomGenerator
    ) -> [StepsInterval] {
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        let currentHour = calendar.component(.hour, from: currentTime)
        let currentMinute = calendar.component(.minute, from: currentTime)
        
        var intervals: [StepsInterval] = []
        
        for hourlyStep in hourlyStepsArray {
            let hour = hourlyStep.hour
            let hourSteps = hourlyStep.steps
            
            // 跳过未来的小时
            guard hour <= currentHour else { continue }
            
            // 跳过0步数的小时
            guard hourSteps > 0 else { continue }
            
            // 检查这个小时是否在睡眠时间内
            if let sleepData = sleepData, isHourDuringSleep(hour: hour, date: date, sleepData: sleepData) {
                continue // 睡眠期间跳过步数生成
            }
            
            // 确定这个小时的结束时间
            let actualHourEnd: Int
            if hour == currentHour {
                actualHourEnd = currentMinute
            } else {
                actualHourEnd = 60
            }
            
            // 为这个小时生成随机的活动时间段
            let activityPeriods = generateActivityPeriods(
                hour: hour,
                maxMinute: actualHourEnd,
                totalSteps: hourSteps,
                sleepData: sleepData,
                date: date,
                generator: &generator
            )
            
            // 为每个活动时间段创建步数记录
            for period in activityPeriods {
                let startTime = calendar.date(byAdding: .minute, value: hour * 60 + period.startMinute, to: dateStart)!
                var endTime = calendar.date(byAdding: .minute, value: hour * 60 + period.endMinute, to: dateStart)!
                
                // 确保不超过当前时间
                if hour == currentHour && period.endMinute > currentMinute {
                    endTime = currentTime
                }
                
                intervals.append(StepsInterval(
                    steps: period.steps,
                    startTime: startTime,
                    endTime: endTime
                ))
            }
        }
        
        return intervals
    }
    
    // 获取时间间隔的活跃度系数
    private static func getIntervalActivityMultiplier(hour: Int, intervalStart: Int) -> Double {
        // 基础小时活跃度
        let baseHourMultiplier: Double
        switch hour {
        case 0...5:
            baseHourMultiplier = 0.1 // 深夜
        case 6...7:
            baseHourMultiplier = 0.8 // 早起
        case 8...11:
            baseHourMultiplier = 1.2 // 上午活跃
        case 12...13:
            baseHourMultiplier = 0.9 // 午餐时间
        case 14...17:
            baseHourMultiplier = 1.4 // 下午最活跃
        case 18...20:
            baseHourMultiplier = 1.1 // 晚餐后
        case 21...23:
            baseHourMultiplier = 0.6 // 晚上减少
        default:
            baseHourMultiplier = 0.5
        }
        
        // 根据小时内的时间段微调
        let minuteMultiplier: Double
        switch intervalStart {
        case 0...10:
            minuteMultiplier = 0.9 // 小时开始相对平静
        case 20...30:
            minuteMultiplier = 1.2 // 中段活跃
        case 40...50:
            minuteMultiplier = 1.1 // 末段准备下一小时
        default:
            minuteMultiplier = 1.0
        }
        
        return baseHourMultiplier * minuteMultiplier
    }
    
    // 生成真实iPhone风格的随机步数记录块（历史数据版本）
    private static func generateRealisticiPhoneStepsSamples(
        date: Date,
        hourlyStepsArray: [HourlySteps],
        sleepData: SleepData?,
        generator: inout SeededRandomGenerator
    ) -> [StepsInterval] {
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        
        var intervals: [StepsInterval] = []
        
        // 如果有睡眠数据，使用智能分配逻辑
        if let sleepData = sleepData {
            intervals = generateSleepAwareStepsIntervals(
                date: date,
                sleepData: sleepData,
                hourlyStepsArray: hourlyStepsArray,
                generator: &generator
            )
        } else {
            // 没有睡眠数据时使用原来的逻辑
            for hourlyStep in hourlyStepsArray {
                let hour = hourlyStep.hour
                let hourSteps = hourlyStep.steps
                
                // 跳过0步数的小时
                guard hourSteps > 0 else { continue }
                
                // 为这个小时生成随机的活动时间段
                let activityPeriods = generateActivityPeriods(
                    hour: hour,
                    maxMinute: 60,
                    totalSteps: hourSteps,
                    sleepData: nil,
                    date: date,
                    generator: &generator
                )
                
                // 为每个活动时间段创建步数记录
                for period in activityPeriods {
                    let startTime = calendar.date(byAdding: .minute, value: hour * 60 + period.startMinute, to: dateStart)!
                    let endTime = calendar.date(byAdding: .minute, value: hour * 60 + period.endMinute, to: dateStart)!
                    
                    intervals.append(StepsInterval(
                        steps: period.steps,
                        startTime: startTime,
                        endTime: endTime
                    ))
                }
            }
        }
        
        // 历史数据生成完成
        return intervals
    }
    
    // 活动时间段结构
    private struct ActivityPeriod {
        let startMinute: Int
        let endMinute: Int
        let steps: Int
    }
    
    // 为一个小时生成随机的活动时间段（模拟真实iPhone记录）
    private static func generateActivityPeriods(
        hour: Int,
        maxMinute: Int,
        totalSteps: Int,
        sleepData: SleepData?,
        date: Date,
        generator: inout SeededRandomGenerator
    ) -> [ActivityPeriod] {
        guard totalSteps > 0 && maxMinute > 0 else { return [] }
        
        // 获取考虑睡眠边界的有效活动时间范围
        let validRange = getValidActivityRange(
            hour: hour,
            maxMinute: maxMinute,
            date: date,
            sleepData: sleepData
        )
        
        // 如果没有有效活动时间，返回空数组
        guard validRange.endMinute > validRange.startMinute else { return [] }
        
        var periods: [ActivityPeriod] = []
        var remainingSteps = totalSteps
        var currentMinute = validRange.startMinute
        let maxValidMinute = validRange.endMinute
        
        // 根据时间段确定活动模式（考虑睡眠影响）
        let activityPattern = getHourActivityPattern(hour: hour, sleepData: sleepData)
        
        while remainingSteps > 0 && currentMinute < maxValidMinute {
            // 决定静止时间（没有步数记录的时间）
            let restDuration = generateRestDuration(
                hour: hour,
                pattern: activityPattern,
                generator: &generator
            )
            
            currentMinute += restDuration
            if currentMinute >= maxValidMinute { break }
            
            // 生成一个活动时间段
            let activityDuration = generateActivityDuration(
                pattern: activityPattern,
                generator: &generator
            )
            
            let endMinute = min(currentMinute + activityDuration, maxValidMinute)
            
            // 分配步数给这个时间段
            let stepsForPeriod = generateStepsForPeriod(
                remainingSteps: remainingSteps,
                duration: endMinute - currentMinute,
                pattern: activityPattern,
                generator: &generator
            )
            
            if stepsForPeriod > 0 {
                periods.append(ActivityPeriod(
                    startMinute: currentMinute,
                    endMinute: endMinute,
                    steps: stepsForPeriod
                ))
                
                remainingSteps -= stepsForPeriod
            }
            
            currentMinute = endMinute
        }
        
        // 如果还有剩余步数，添加到最后一个时间段或创建新时间段
        if remainingSteps > 0 && !periods.isEmpty {
            let lastIndex = periods.count - 1
            periods[lastIndex] = ActivityPeriod(
                startMinute: periods[lastIndex].startMinute,
                endMinute: periods[lastIndex].endMinute,
                steps: periods[lastIndex].steps + remainingSteps
            )
        }
        
        return periods
    }
    
    // 活动模式枚举
    private enum HourActivityPattern {
        case inactive    // 深夜/休息
        case light      // 轻度活动
        case moderate   // 中度活动
        case active     // 活跃时段
        case commute    // 通勤时段
    }
    
    // 获取小时的活动模式（考虑睡眠数据）
    private static func getHourActivityPattern(hour: Int, sleepData: SleepData?) -> HourActivityPattern {
        // 如果有睡眠数据，检查是否是睡前或起床时间
        if let sleepData = sleepData {
            let calendar = Calendar.current
            let bedHour = calendar.component(.hour, from: sleepData.bedTime)
            let wakeHour = calendar.component(.hour, from: sleepData.wakeTime)
            
            // 睡前一小时：活动量减少
            if (bedHour > 0 && hour == bedHour - 1) || 
               (bedHour == 0 && hour == 23) {
                return .light
            }
            
            // 睡觉的那个小时：很少活动
            if hour == bedHour {
                return .inactive
            }
            
            // 起床的那个小时：逐渐活跃
            if hour == wakeHour {
                return .light
            }
            
            // 起床后一小时：正常活跃
            if hour == wakeHour + 1 {
                return .moderate
            }
        }
        
        // 默认的时间模式
        switch hour {
        case 0...5, 23:
            return .inactive
        case 6...7:
            return .light
        case 8...9, 17...19: // 通勤时间
            return .commute
        case 10...11, 14...16:
            return .active
        case 12...13, 20...22:
            return .moderate
        default:
            return .light
        }
    }
    
    // 生成静止时间（分钟）
    private static func generateRestDuration(
        hour: Int,
        pattern: HourActivityPattern,
        generator: inout SeededRandomGenerator
    ) -> Int {
        switch pattern {
        case .inactive:
            return generator.nextInt(in: 15...45) // 长时间静止
        case .light:
            return generator.nextInt(in: 8...20)
        case .moderate:
            return generator.nextInt(in: 5...15)
        case .active:
            return generator.nextInt(in: 2...8)
        case .commute:
            return generator.nextInt(in: 1...5) // 通勤时很少静止
        }
    }
    
    // 生成活动时间段长度（分钟）
    private static func generateActivityDuration(
        pattern: HourActivityPattern,
        generator: inout SeededRandomGenerator
    ) -> Int {
        switch pattern {
        case .inactive:
            return generator.nextInt(in: 1...3) // 短暂活动，如上厕所
        case .light:
            return generator.nextInt(in: 2...8)
        case .moderate:
            return generator.nextInt(in: 3...12)
        case .active:
            return generator.nextInt(in: 5...18) // 较长的活动，如散步
        case .commute:
            return generator.nextInt(in: 8...25) // 通勤活动较长
        }
    }
    
    // 为时间段分配步数
    private static func generateStepsForPeriod(
        remainingSteps: Int,
        duration: Int,
        pattern: HourActivityPattern,
        generator: inout SeededRandomGenerator
    ) -> Int {
        guard remainingSteps > 0 && duration > 0 else { return 0 }
        
        // 根据活动模式确定步数密度（步数/分钟）
        let stepsPerMinute: Int
        switch pattern {
        case .inactive:
            stepsPerMinute = generator.nextInt(in: 5...20)
        case .light:
            stepsPerMinute = generator.nextInt(in: 15...45)
        case .moderate:
            stepsPerMinute = generator.nextInt(in: 25...70)
        case .active:
            stepsPerMinute = generator.nextInt(in: 40...100)
        case .commute:
            stepsPerMinute = generator.nextInt(in: 35...90)
        }
        
        let targetSteps = stepsPerMinute * duration
        
        // 确保不超过剩余步数，并添加随机变化
        let maxSteps = min(targetSteps, remainingSteps)
        let variation = generator.nextDouble(in: 0.7...1.3)
        
        return max(1, min(maxSteps, Int(Double(targetSteps) * variation)))
    }
    
    // 检查指定小时是否在睡眠时间内
    private static func isHourDuringSleep(hour: Int, date: Date, sleepData: SleepData) -> Bool {
        let calendar = Calendar.current
        
        // 获取睡眠时间的小时数
        let bedHour = calendar.component(.hour, from: sleepData.bedTime)
        let wakeHour = calendar.component(.hour, from: sleepData.wakeTime)
        
        // 如果睡眠跨越午夜（床时间的小时数 > 起床时间的小时数）
        if bedHour > wakeHour {
            // 睡眠时间跨越了午夜，如 23:00 睡觉，7:00 起床
            // 睡眠小时：23, 0, 1, 2, 3, 4, 5, 6
            return hour >= bedHour || hour < wakeHour
        } else if bedHour < wakeHour {
            // 睡眠时间在同一天内（少见情况，如午觉 13:00-15:00）
            return hour >= bedHour && hour < wakeHour
        } else {
            // bedHour == wakeHour，睡眠不到1小时，认为不影响步数
            return false
        }
    }
    
    // 获取小时内的有效活动时间范围（考虑睡眠边界）
    private static func getValidActivityRange(
        hour: Int,
        maxMinute: Int,
        date: Date,
        sleepData: SleepData?
    ) -> (startMinute: Int, endMinute: Int) {
        guard let sleepData = sleepData else {
            return (startMinute: 0, endMinute: maxMinute)
        }
        
        let calendar = Calendar.current
        
        var validStart = 0
        var validEnd = maxMinute
        
        // 检查睡觉时间边界
        let bedTimeHour = calendar.component(.hour, from: sleepData.bedTime)
        let bedTimeMinute = calendar.component(.minute, from: sleepData.bedTime)
        
        if hour == bedTimeHour {
            // 如果是睡觉的那个小时，活动应该在睡觉时间前停止
            validEnd = min(validEnd, bedTimeMinute)
        }
        
        // 检查起床时间边界
        let wakeTimeHour = calendar.component(.hour, from: sleepData.wakeTime)
        let wakeTimeMinute = calendar.component(.minute, from: sleepData.wakeTime)
        
        if hour == wakeTimeHour {
            // 如果是起床的那个小时，活动应该在起床时间后开始
            validStart = max(validStart, wakeTimeMinute)
        }
        
        // 确保有效范围
        if validStart >= validEnd {
            return (startMinute: 0, endMinute: 0) // 无有效时间
        }
        
        return (startMinute: validStart, endMinute: validEnd)
    }
    
    // 基于睡眠数据的智能步数分配
    private static func generateSleepAwareStepsIntervals(
        date: Date,
        sleepData: SleepData,
        hourlyStepsArray: [HourlySteps],
        generator: inout SeededRandomGenerator
    ) -> [StepsInterval] {
        let calendar = Calendar.current
        let _ = calendar.startOfDay(for: date)
        
        // 计算总步数
        let totalSteps = hourlyStepsArray.reduce(0) { $0 + $1.steps }
        guard totalSteps > 0 else { return [] }
        
        // Debug: 基于睡眠数据分配步数
        
        var intervals: [StepsInterval] = []
        
        // 1. 为睡眠期间分配少量步数（起夜/翻身）
        let sleepStepsIntervals = generateSleepPeriodSteps(
            date: date,
            sleepData: sleepData,
            totalSteps: totalSteps,
            generator: &generator
        )
        
        let sleepStepsUsed = sleepStepsIntervals.reduce(0) { $0 + $1.steps }
        intervals.append(contentsOf: sleepStepsIntervals)
        
        // 睡眠期间步数分配完成
        
        // 2. 剩余步数分配到清醒时间
        let remainingSteps = totalSteps - sleepStepsUsed
        if remainingSteps > 0 {
            let wakeStepsIntervals = generateWakePeriodSteps(
                date: date,
                sleepData: sleepData,
                remainingSteps: remainingSteps,
                generator: &generator
            )
            
            intervals.append(contentsOf: wakeStepsIntervals)
            // 清醒期间步数分配完成
        }
        
        // 按时间排序
        intervals.sort { $0.startTime < $1.startTime }
        
        return intervals
    }
    
    // 生成睡眠期间的步数（起夜/翻身）
    private static func generateSleepPeriodSteps(
        date: Date,
        sleepData: SleepData,
        totalSteps: Int,
        generator: inout SeededRandomGenerator
    ) -> [StepsInterval] {
        var intervals: [StepsInterval] = []
        
        // 睡眠期间分配总步数的3-8%作为起夜步数
        let sleepStepsRatio = generator.nextDouble(in: 0.03...0.08)
        let maxSleepSteps = Int(Double(totalSteps) * sleepStepsRatio)
        
        guard maxSleepSteps > 0 else { return [] }
        
        // 睡眠期间最多分配步数
        
        // 基于基本睡眠时间分配，不依赖详细睡眠阶段
        let sleepStart = sleepData.bedTime
        let sleepEnd = sleepData.wakeTime
        let sleepDuration = sleepEnd.timeIntervalSince(sleepStart)
        
        // 计算当天的睡眠时间段（处理跨夜情况）
        let calendar = Calendar.current
        var actualSleepStart = sleepStart
        var actualSleepEnd = sleepEnd
        
        // 如果是跨夜睡眠，调整到当天范围内
        if sleepEnd < sleepStart {
            // 跨夜情况：睡眠从前一天晚上开始，到当天早上结束
            let dayStart = calendar.startOfDay(for: date)
            actualSleepStart = max(sleepStart, dayStart)
            actualSleepEnd = min(sleepEnd.addingTimeInterval(24*3600), dayStart.addingTimeInterval(24*3600))
        }
        
        // 在睡眠期间生成2-4次起夜活动
        let nighttimeEvents = generator.nextInt(in: 2...4)
        var stepsUsed = 0
        
        for _ in 0..<nighttimeEvents {
            guard stepsUsed < maxSleepSteps else { break }
            
            // 随机选择起夜时间（避免刚入睡和即将醒来的时间）
            let timeRatio = generator.nextDouble(in: 0.2...0.8) // 在睡眠时间的20%-80%范围内
            let nighttimeStart = actualSleepStart.addingTimeInterval(sleepDuration * timeRatio)
            
            // 确保时间在当天范围内
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = dayStart.addingTimeInterval(24*3600)
            guard nighttimeStart >= dayStart && nighttimeStart < dayEnd else { continue }
            
            // 起夜步数：3-15步
            let nighttimeSteps = min(
                generator.nextInt(in: 3...15),
                maxSleepSteps - stepsUsed
            )
            
            if nighttimeSteps > 0 {
                // 起夜活动持续时间：30秒到3分钟
                let nighttimeDuration = generator.nextDouble(in: 30...180)
                let nighttimeEnd = nighttimeStart.addingTimeInterval(nighttimeDuration)
                
                // 确保不超出睡眠时间和当天范围
                let actualEnd = min(nighttimeEnd, min(actualSleepEnd, dayEnd))
                
                if actualEnd > nighttimeStart {
                    intervals.append(StepsInterval(
                        steps: nighttimeSteps,
                        startTime: nighttimeStart,
                        endTime: actualEnd
                    ))
                    
                    stepsUsed += nighttimeSteps
                    // 起夜活动记录
                }
            }
        }
        
        // 实际睡眠期间分配步数完成
        return intervals
    }
    
    // 生成清醒期间的步数
    private static func generateWakePeriodSteps(
        date: Date,
        sleepData: SleepData,
        remainingSteps: Int,
        generator: inout SeededRandomGenerator
    ) -> [StepsInterval] {
        let calendar = Calendar.current
        let dateStart = calendar.startOfDay(for: date)
        let _ = calendar.date(byAdding: .day, value: 1, to: dateStart)!
        
        var intervals: [StepsInterval] = []
        var stepsToDistribute = remainingSteps
        
        // 获取清醒时间段
        let wakePeriods = getWakePeriods(date: date, sleepData: sleepData)
        
        // 清醒期间步数分配开始
        
        // 计算所有时间段的权重比例
        var periodRatios: [(period: WakePeriod, ratio: Double)] = []
        var totalRatio = 0.0
        
        for wakePeriod in wakePeriods {
            let ratio = getWakePeriodStepsRatio(
                startTime: wakePeriod.start,
                endTime: wakePeriod.end,
                sleepData: sleepData
            )
            periodRatios.append((period: wakePeriod, ratio: ratio))
            totalRatio += ratio
        }
        
        // 按归一化比例分配步数
        for (_, periodInfo) in periodRatios.enumerated() {
            guard stepsToDistribute > 0 else { break }
            
            let normalizedRatio = totalRatio > 0 ? periodInfo.ratio / totalRatio : 1.0 / Double(wakePeriods.count)
            let targetStepsForPeriod = Int(Double(remainingSteps) * normalizedRatio)
            let actualStepsForPeriod = min(targetStepsForPeriod, stepsToDistribute)
            
            // 时间段步数分配
            
            if actualStepsForPeriod > 0 {
                // 在这个清醒时间段内生成活动间隔
                let periodIntervals = generateWakePeriodActivityIntervals(
                    startTime: periodInfo.period.start,
                    endTime: periodInfo.period.end,
                    totalSteps: actualStepsForPeriod,
                    sleepData: sleepData,
                    generator: &generator
                )
                
                intervals.append(contentsOf: periodIntervals)
                stepsToDistribute -= actualStepsForPeriod
            }
        }
        
        return intervals
    }
    
    // 清醒时间段结构
    private struct WakePeriod {
        let start: Date
        let end: Date
    }
    
    // 获取清醒时间段
    private static func getWakePeriods(date: Date, sleepData: SleepData) -> [WakePeriod] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        var wakePeriods: [WakePeriod] = []
        
        // 获取睡眠时间在当天的实际时间点
        let bedTime = sleepData.bedTime
        let wakeTime = sleepData.wakeTime
        
        // 分析清醒时间段
        
        // 判断是否跨夜睡眠（通过小时判断更准确）
        let bedHour = calendar.component(.hour, from: bedTime)
        let wakeHour = calendar.component(.hour, from: wakeTime)
        
        if bedHour > 18 && wakeHour < 12 {  // 跨夜睡眠：晚上6点后睡，中午12点前醒
            // 清醒时间段：起床时间到睡觉时间
            let actualWakeTime = wakeTime
            let actualBedTime = bedTime
            
            // 确保时间在当天范围内
            let wakeTimeInDay = max(actualWakeTime, dayStart)
            let bedTimeInDay = min(actualBedTime, dayEnd)
            
            if wakeTimeInDay < bedTimeInDay {
                wakePeriods.append(WakePeriod(
                    start: wakeTimeInDay,
                    end: bedTimeInDay
                ))
                // 清醒时间段设置
            }
        } else {
            // 非跨夜睡眠：在同一天内睡觉和起床
            // 清醒时间段1：当天开始到睡觉时间
            if bedTime > dayStart {
                wakePeriods.append(WakePeriod(
                    start: dayStart,
                    end: bedTime
                ))
                // 清醒时间段1设置
            }
            
            // 清醒时间段2：起床时间到当天结束
            if wakeTime < dayEnd {
                wakePeriods.append(WakePeriod(
                    start: wakeTime,
                    end: dayEnd
                ))
                // 清醒时间段2设置
            }
        }
        
        return wakePeriods
    }
    
    // 获取清醒时间段的步数分配比例
    private static func getWakePeriodStepsRatio(
        startTime: Date,
        endTime: Date,
        sleepData: SleepData
    ) -> Double {
        let duration = endTime.timeIntervalSince(startTime)
        let hours = duration / 3600.0
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        
        // 根据时间段给出不同的活跃度权重
        var activityWeight = 1.0
        
        // 早晨时间段（起床后）
        if startTime == sleepData.wakeTime {
            activityWeight *= 0.8 // 刚起床相对较少活动
        }
        
        // 夜晚时间段（睡前）
        if endTime == sleepData.bedTime {
            activityWeight *= 0.7 // 睡前活动减少
        }
        
        // 根据小时调整权重
        let midHour = (startHour + endHour) / 2
        switch midHour {
        case 6...8:
            activityWeight *= 0.9 // 早晨
        case 9...11:
            activityWeight *= 1.2 // 上午活跃
        case 12...13:
            activityWeight *= 1.0 // 中午
        case 14...17:
            activityWeight *= 1.3 // 下午最活跃
        case 18...20:
            activityWeight *= 1.1 // 傍晚
        case 21...23:
            activityWeight *= 0.8 // 晚上
        default:
            activityWeight *= 0.5 // 深夜/凌晨
        }
        
        // 基础比例：时间长度 * 活跃度权重
        let rawRatio = activityWeight * hours
        // 时间段权重分析完成
        
        return rawRatio // 不在这里归一化，在上层方法中统一处理
    }
    
    // 在清醒时间段内生成活动间隔
    private static func generateWakePeriodActivityIntervals(
        startTime: Date,
        endTime: Date,
        totalSteps: Int,
        sleepData: SleepData,
        generator: inout SeededRandomGenerator
    ) -> [StepsInterval] {
        var intervals: [StepsInterval] = []
        var remainingSteps = totalSteps
        var currentTime = startTime
        
        while remainingSteps > 0 && currentTime < endTime {
            // 生成休息时间
            let restDuration = generator.nextDouble(in: 2...15) * 60 // 2-15分钟休息
            currentTime = currentTime.addingTimeInterval(restDuration)
            
            if currentTime >= endTime { break }
            
            // 生成活动时间
            let activityDuration = generator.nextDouble(in: 1...20) * 60 // 1-20分钟活动
            let activityEnd = min(currentTime.addingTimeInterval(activityDuration), endTime)
            
            // 分配步数 - 至少1步，最多剩余步数的30%或全部剩余步数（取较小值）
            let maxPossibleSteps = max(1, Int(Double(remainingSteps) * 0.3))
            let upperBound = min(remainingSteps, maxPossibleSteps)
            
            let stepsForActivity = if upperBound >= 1 {
                generator.nextInt(in: 1...upperBound)
            } else {
                remainingSteps // 如果计算出现问题，分配所有剩余步数
            }
            
            if stepsForActivity > 0 {
                intervals.append(StepsInterval(
                    steps: stepsForActivity,
                    startTime: currentTime,
                    endTime: activityEnd
                ))
                
                remainingSteps -= stepsForActivity
            }
            
            currentTime = activityEnd
        }
        
        return intervals
    }
}
