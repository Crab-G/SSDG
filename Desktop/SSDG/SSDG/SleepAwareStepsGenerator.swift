//
//  SleepAwareStepsGenerator.swift
//  SSDG - 睡眠感知步数生成器
//
//  优化睡眠时段的步数分布算法，提供更自然的生理性活动模拟
//

import Foundation

// MARK: - 睡眠感知步数生成器
class SleepAwareStepsGenerator {
    
    // MARK: - 生理活动类型
    enum PhysiologicalActivity: String, CaseIterable {
        case restroom = "如厕"           // 起夜上厕所：15-45步
        case water = "接水"              // 夜间接水：8-20步
        case tossing = "翻身调整"        // 翻身调整：1-5步
        case brief_wake = "短暂清醒"     // 短暂清醒站立：3-12步
        case partner_disturbance = "伴侣影响" // 伴侣活动影响：2-8步
        
        var stepRange: ClosedRange<Int> {
            switch self {
            case .restroom: return 15...45
            case .water: return 8...20
            case .tossing: return 1...5
            case .brief_wake: return 3...12
            case .partner_disturbance: return 2...8
            }
        }
        
        var probability: Double {  // 在苹果手机无穿戴设备情况下的发生概率
            switch self {
            case .restroom: return 0.15        // 15%概率起夜
            case .water: return 0.08           // 8%概率夜间接水
            case .tossing: return 0.25         // 25%概率翻身被检测到
            case .brief_wake: return 0.12      // 12%概率短暂清醒
            case .partner_disturbance: return 0.06  // 6%概率伴侣影响
            }
        }
        
        var activityDuration: ClosedRange<Int> {  // 活动持续时间（秒）
            switch self {
            case .restroom: return 120...300   // 2-5分钟
            case .water: return 30...90        // 30秒-1.5分钟
            case .tossing: return 5...15       // 5-15秒
            case .brief_wake: return 20...60   // 20秒-1分钟
            case .partner_disturbance: return 10...30  // 10-30秒
            }
        }
    }
    
    // MARK: - 主要生成方法
    
    /// 生成基于睡眠数据的精准步数分配 - 严格匹配睡眠时段
    static func generateSleepBasedStepDistribution(
        sleepData: SleepData,
        totalDailySteps: Int,
        date: Date,
        userProfile: PersonalizedProfile,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        var stepIncrements: [StepIncrement] = []
        
        print("🛏️ 开始精确睡眠数据匹配")
        print("   睡眠时段: \(DateFormatter.localizedString(from: sleepData.bedTime, dateStyle: .none, timeStyle: .short)) - \(DateFormatter.localizedString(from: sleepData.wakeTime, dateStyle: .none, timeStyle: .short))")
        
        // 1. 精确识别所有卧床时段（包括主睡眠+碎片化睡眠）
        let allSleepPeriods = extractAllSleepPeriods(from: sleepData)
        print("   识别到 \(allSleepPeriods.count) 个卧床时段")
        
        // 2. 计算极少的睡眠时段步数预算
        let sleepStepsBudget = calculateMinimalSleepStepsBudget(
            totalDailySteps: totalDailySteps,
            sleepDuration: sleepData.duration,
            generator: &generator
        )
        
        print("🌙 方案A卧床步数预算: \(sleepStepsBudget)步 (3-18步范围内)")
        
        // 3. 在实际卧床时段内分配极少步数
        let sleepIncrements = generatePreciseSleepSteps(
            sleepPeriods: allSleepPeriods,
            stepsBudget: sleepStepsBudget,
            userProfile: userProfile,
            generator: &generator
        )
        
        stepIncrements.append(contentsOf: sleepIncrements)
        
        // 4. 在完全清醒时段分配剩余步数
        let remainingSteps = totalDailySteps - sleepStepsBudget
        let wakeSteps = generatePreciseWakeTimeSteps(
            sleepPeriods: allSleepPeriods,
            remainingSteps: remainingSteps,
            date: date,
            userProfile: userProfile,
            generator: &generator
        )
        
        stepIncrements.append(contentsOf: wakeSteps)
        
        // 按时间排序
        stepIncrements.sort { $0.timestamp < $1.timestamp }
        
        print("✅ 方案A分配完成: 卧床时段\(sleepStepsBudget)步 + 清醒时段\(wakeSteps.reduce(0, { $0 + $1.steps }))步 (清醒步数已分片，最多50步/次)")
        
        return stepIncrements
    }
    
    // MARK: - 精确睡眠时段识别和步数分配
    
    /// 提取所有卧床时段（主睡眠+碎片化睡眠）
    private static func extractAllSleepPeriods(from sleepData: SleepData) -> [(start: Date, end: Date, type: String)] {
        var periods: [(start: Date, end: Date, type: String)] = []
        
        // 主睡眠时段
        periods.append((
            start: sleepData.bedTime,
            end: sleepData.wakeTime,
            type: "主睡眠"
        ))
        
        // 如果有睡眠阶段数据，识别碎片化睡眠
        if !sleepData.sleepStages.isEmpty {
            // 按时间排序睡眠阶段
            let sortedStages = sleepData.sleepStages.sorted { $0.startTime < $1.startTime }
            
            // 识别连续的卧床时段
            var currentBedPeriodStart: Date?
            
            for stage in sortedStages {
                if stage.stage != .awake {
                    // 睡眠阶段开始
                    if currentBedPeriodStart == nil {
                        currentBedPeriodStart = stage.startTime
                    }
                } else {
                    // 清醒阶段，结束当前卧床时段
                    if let bedStart = currentBedPeriodStart {
                        periods.append((
                            start: bedStart,
                            end: stage.startTime,
                            type: "睡眠片段"
                        ))
                        currentBedPeriodStart = nil
                    }
                }
            }
            
            // 处理最后一个卧床时段
            if let bedStart = currentBedPeriodStart,
               let lastStage = sortedStages.last {
                periods.append((
                    start: bedStart,
                    end: lastStage.endTime,
                    type: "睡眠片段"
                ))
            }
        }
        
        // 去重和合并重叠时段
        return mergeOverlappingPeriods(periods)
    }
    
    /// 合并重叠的睡眠时段
    private static func mergeOverlappingPeriods(_ periods: [(start: Date, end: Date, type: String)]) -> [(start: Date, end: Date, type: String)] {
        guard !periods.isEmpty else { return [] }
        
        let sortedPeriods = periods.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date, type: String)] = []
        
        var currentStart = sortedPeriods[0].start
        var currentEnd = sortedPeriods[0].end
        var currentType = sortedPeriods[0].type
        
        for i in 1..<sortedPeriods.count {
            let period = sortedPeriods[i]
            
            if period.start <= currentEnd {
                // 重叠，合并
                currentEnd = max(currentEnd, period.end)
                if period.type == "主睡眠" {
                    currentType = "主睡眠"
                }
            } else {
                // 不重叠，保存当前时段
                merged.append((start: currentStart, end: currentEnd, type: currentType))
                currentStart = period.start
                currentEnd = period.end
                currentType = period.type
            }
        }
        
        // 添加最后一个时段
        merged.append((start: currentStart, end: currentEnd, type: currentType))
        
        return merged
    }
    
    /// 🔧 方案A：计算符合生理真实性的卧床步数预算
    private static func calculateMinimalSleepStepsBudget(
        totalDailySteps: Int,
        sleepDuration: Double,
        generator: inout SeededRandomGenerator
    ) -> Int {
        
        // 🔧 更少的夜间步数：大部分人整晚不起床
        // 70%概率：整晚没有步数
        // 25%概率：起夜一次（10-30步）
        // 5%概率：起夜两次
        
        let nightActivityProbability = generator.nextDouble(in: 0...1)
        let finalBudget: Int
        
        if nightActivityProbability < 0.7 {
            // 70%：没有夜间活动
            finalBudget = 0
        } else if nightActivityProbability < 0.95 {
            // 25%：起夜一次
            finalBudget = generator.nextInt(in: 10...30)
        } else {
            // 5%：起夜两次
            finalBudget = generator.nextInt(in: 20...50)
        }
        
        return finalBudget
    }
    
    /// 在精确的卧床时段内分配极少步数
    private static func generatePreciseSleepSteps(
        sleepPeriods: [(start: Date, end: Date, type: String)],
        stepsBudget: Int,
        userProfile: PersonalizedProfile,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        var sleepIncrements: [StepIncrement] = []
        var remainingBudget = stepsBudget
        
        for period in sleepPeriods {
            guard remainingBudget > 0 else { break }
            
            let periodDuration = period.end.timeIntervalSince(period.start)
            let periodHours = periodDuration / 3600.0
            
            print("   处理\(period.type): \(DateFormatter.localizedString(from: period.start, dateStyle: .none, timeStyle: .short))-\(DateFormatter.localizedString(from: period.end, dateStyle: .none, timeStyle: .short)) (\(String(format: "%.1f", periodHours))小时)")
            
            // 计算这个时段的步数分配
            let periodBudget = min(remainingBudget, Int(Double(stepsBudget) * (periodDuration / (sleepPeriods.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }))))
            
            // 在这个时段内生成极少的生理活动
            let periodIncrements = generateMinimalNightActivities(
                startTime: period.start,
                endTime: period.end,
                periodType: period.type,
                stepsBudget: periodBudget,
                generator: &generator
            )
            
            sleepIncrements.append(contentsOf: periodIncrements)
            remainingBudget -= periodIncrements.reduce(0) { $0 + $1.steps }
        }
        
        return sleepIncrements
    }
    
    /// 生成极少的夜间生理活动
    private static func generateMinimalNightActivities(
        startTime: Date,
        endTime: Date,
        periodType: String,
        stepsBudget: Int,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        guard stepsBudget > 0 else { return [] }
        
        var increments: [StepIncrement] = []
        let periodDuration = endTime.timeIntervalSince(startTime)
        let periodHours = periodDuration / 3600.0
        
        // 根据时段类型和时长决定活动频率
        // 大幅减少夜间活动
        let maxActivities: Int
        if periodType == "主睡眠" {
            // 主睡眠时段：平均每4-5小时最多1次活动（起夜）
            if periodHours > 4 {
                // 80%概率没有任何活动
                maxActivities = generator.nextDouble(in: 0...1) < 0.8 ? 0 : 1
            } else {
                maxActivities = 0  // 短睡眠无活动
            }
        } else {
            // 碎片化睡眠：通常无活动
            maxActivities = 0
        }
        
        let actualActivities = maxActivities
        
        print("     时段预算: \(stepsBudget)步, 最多\(actualActivities)次活动")
        
        for i in 0..<actualActivities {
            guard stepsBudget > increments.reduce(0, { $0 + $1.steps }) else { break }
            
            // 生成活动时间（避免刚入睡和即将醒来的时间）
            let safeZone = periodDuration * 0.1 // 前后10%时间为安全区
            let activityTime = startTime.addingTimeInterval(
                safeZone + generator.nextDouble(in: 0...(periodDuration - 2 * safeZone))
            )
            
            // 生成极少量步数：起夜通常是5-20步（去上厕所）
            let activitySteps = generator.nextInt(in: 5...20)
            let actualSteps = min(activitySteps, stepsBudget - increments.reduce(0, { $0 + $1.steps }))
            
            if actualSteps > 0 {
                increments.append(StepIncrement(
                    timestamp: activityTime,
                    steps: actualSteps,
                    activityType: .idle
                ))
                
                print("     活动\(i+1): \(DateFormatter.localizedString(from: activityTime, dateStyle: .none, timeStyle: .medium)) +\(actualSteps)步")
            }
        }
        
        return increments
    }
    
    /// 在精确的清醒时段分配步数
    private static func generatePreciseWakeTimeSteps(
        sleepPeriods: [(start: Date, end: Date, type: String)],
        remainingSteps: Int,
        date: Date,
        userProfile: PersonalizedProfile,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        // 🔥 关键修复：检查是否是今天，如果是今天则限制到当前时间
        let now = Date()
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let actualDayEnd = isToday ? min(now, dayEnd) : dayEnd
        
        // 创建清醒时段列表（排除所有卧床时段）
        var wakeIntervals: [(start: Date, end: Date)] = []
        
        // 从一天开始扫描到实际结束时间
        var currentTime = dayStart
        
        for sleepPeriod in sleepPeriods.sorted(by: { $0.start < $1.start }) {
            // 添加睡眠前的清醒时段
            if currentTime < sleepPeriod.start {
                let intervalEnd = min(sleepPeriod.start, actualDayEnd)
                if currentTime < intervalEnd {
                    wakeIntervals.append((start: currentTime, end: intervalEnd))
                }
            }
            
            // 跳过睡眠时段
            currentTime = max(currentTime, sleepPeriod.end)
            
            // 如果已经超过实际结束时间，停止处理
            if currentTime >= actualDayEnd {
                break
            }
        }
        
        // 添加最后的清醒时段（限制到实际结束时间）
        if currentTime < actualDayEnd {
            wakeIntervals.append((start: currentTime, end: actualDayEnd))
        }
        
        print("🌅 识别到 \(wakeIntervals.count) 个清醒时段")
        
        // 在清醒时段内分配步数
        var wakeIncrements: [StepIncrement] = []
        
        for interval in wakeIntervals {
            let intervalDuration = interval.end.timeIntervalSince(interval.start)
            let intervalHours = intervalDuration / 3600.0
            
            if intervalHours > 0.1 { // 只处理超过6分钟的清醒时段
                let intervalSteps = Int(Double(remainingSteps) * (intervalDuration / wakeIntervals.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }))
                
                print("   清醒时段: \(DateFormatter.localizedString(from: interval.start, dateStyle: .none, timeStyle: .short))-\(DateFormatter.localizedString(from: interval.end, dateStyle: .none, timeStyle: .short)) → \(intervalSteps)步")
                
                let intervalIncrements = generateWakeIntervalSteps(
                    startTime: interval.start,
                    endTime: interval.end,
                    stepsBudget: intervalSteps,
                    userProfile: userProfile,
                    generator: &generator
                )
                
                wakeIncrements.append(contentsOf: intervalIncrements)
            }
        }
        
        return wakeIncrements
    }
    
    /// 🔧 方案A：在清醒时段内生成小块分片步数，避免单次大量导入
    private static func generateWakeIntervalSteps(
        startTime: Date,
        endTime: Date,
        stepsBudget: Int,
        userProfile: PersonalizedProfile,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        guard stepsBudget > 0 else { return [] }
        
        // 立即获取当前时间，避免在循环中重复获取
        let now = Date()
        let calendar = Calendar.current
        let isToday = calendar.isDate(startTime, inSameDayAs: now)
        
        // 如果是今天，限制结束时间不超过当前时间
        let actualEndTime = isToday ? min(endTime, now) : endTime
        
        // 如果开始时间已经超过当前时间（今天的情况），直接返回空
        if isToday && startTime > now {
            return []
        }
        
        let intervalDuration = actualEndTime.timeIntervalSince(startTime)
        
        // 使用更大的间隔和更集中的步数分布
        // 模拟真实的活动模式：大部分时间静止，少数时间集中活动
        let baseMaxSteps = generator.nextInt(in: 50...150)
        let minIncrementInterval = generator.nextDouble(in: 600...1800) // 10-30分钟间隔
        
        // 根据时间段决定活动模式
        let hour = calendar.component(.hour, from: startTime)
        let isActiveHour = (hour >= 7 && hour <= 9) || // 早晨活动
                          (hour >= 12 && hour <= 13) || // 午餐时间
                          (hour >= 18 && hour <= 20)    // 晚上活动
        
        // 计算需要的增量数量
        let minIncrementCount: Int
        let timeBasedIncrementCount: Int
        
        if isActiveHour {
            // 活跃时段：更多次数的活动
            minIncrementCount = max(3, (stepsBudget + baseMaxSteps - 1) / baseMaxSteps)
            timeBasedIncrementCount = max(3, Int(intervalDuration / 300)) // 每5分钟一次
        } else {
            // 非活跃时段：少量集中的活动
            minIncrementCount = max(1, min(3, (stepsBudget + 200 - 1) / 200))
            timeBasedIncrementCount = max(1, Int(intervalDuration / minIncrementInterval))
        }
        
        let incrementCount = max(minIncrementCount, min(timeBasedIncrementCount, 5))
        
        var increments: [StepIncrement] = []
        var remainingSteps = stepsBudget
        
        for i in 0..<incrementCount {
            // 在时间段内分布，使用更大的随机偏移
            let baseTimeOffset = Double(i) * intervalDuration / Double(incrementCount)
            let maxRandomOffset = min(intervalDuration * 0.3, 600.0) // 最多10分钟偏移
            let randomOffset = generator.nextDouble(in: -maxRandomOffset...maxRandomOffset)
            
            let incrementTime = startTime.addingTimeInterval(baseTimeOffset + randomOffset)
            
            // 确保时间戳在有效范围内
            let finalTimestamp = min(max(incrementTime, startTime), actualEndTime)
            
            // 只在时间戳不超过当前时间时创建增量
            if finalTimestamp <= actualEndTime {
                // 为每个增量生成不同的步数，使用更大的变化范围
                let isLastIncrement = (i == incrementCount - 1)
                let actualSteps: Int
                
                if isLastIncrement {
                    // 最后一个增量获得剩余的所有步数
                    actualSteps = remainingSteps
                } else {
                    // 使用更不规则的分配
                    let avgStepsPerIncrement = remainingSteps / (incrementCount - i)
                    let minSteps = max(1, Int(Double(avgStepsPerIncrement) * 0.3))
                    let maxSteps = min(remainingSteps - (incrementCount - i - 1), Int(Double(avgStepsPerIncrement) * 1.7))
                    
                    // 根据活动类型生成步数
                    if isActiveHour {
                        // 活跃时段：步数变化大
                        if generator.nextDouble(in: 0...1) < 0.3 {
                            // 30%概率产生较大值（快走或跑步）
                            actualSteps = min(remainingSteps / 2, generator.nextInt(in: 100...300))
                        } else {
                            actualSteps = generator.nextInt(in: minSteps...maxSteps)
                        }
                    } else {
                        // 非活跃时段：大部分是小量步数
                        if generator.nextDouble(in: 0...1) < 0.7 {
                            // 70%概率只有很少步数（去洗手间等）
                            actualSteps = generator.nextInt(in: 10...50)
                        } else {
                            actualSteps = generator.nextInt(in: minSteps...maxSteps)
                        }
                    }
                }
                
                remainingSteps -= actualSteps
                
                if actualSteps > 0 {
                    // 根据步数选择活动类型
                    let activityType: StepIncrement.ActivityType
                    if actualSteps < 20 {
                        activityType = generator.nextDouble(in: 0...1) < 0.7 ? .walking : .standing
                    } else if actualSteps < 50 {
                        activityType = .walking
                    } else {
                        activityType = generator.nextDouble(in: 0...1) < 0.8 ? .walking : .running
                    }
                    
                    increments.append(StepIncrement(
                        timestamp: finalTimestamp,
                        steps: actualSteps,
                        activityType: activityType
                    ))
                }
            }
        }
        
        return increments
    }
    
    // MARK: - 睡眠步数预算计算 (保留兼容性)
    
    private static func calculateSleepStepsBudget(
        totalDailySteps: Int,
        sleepType: SleepType,
        generator: inout SeededRandomGenerator
    ) -> Int {
        
        // 基础睡眠步数比例
        let baseRatio: ClosedRange<Double>
        
        switch sleepType {
        case .earlyBird:
            baseRatio = 0.02...0.05  // 早起型睡眠较深，夜间活动少
        case .normal:
            baseRatio = 0.03...0.06  // 正常型中等夜间活动
        case .nightOwl:
            baseRatio = 0.04...0.07  // 夜猫子可能夜间活动略多
        case .irregular:
            baseRatio = 0.03...0.08  // 紊乱型变化最大
        }
        
        let ratio = generator.nextDouble(in: baseRatio)
        return Int(Double(totalDailySteps) * ratio)
    }
    
    // MARK: - 基于睡眠阶段的夜间活动生成
    
    private static func generateStageBasedNightActivities(
        sleepStages: [SleepStage],
        stepsBudget: Int,
        userProfile: PersonalizedProfile,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        var activities: [StepIncrement] = []
        var remainingBudget = stepsBudget
        
        for stage in sleepStages {
            guard remainingBudget > 0 else { break }
            
            let stageActivities = generateActivitiesForSleepStage(
                stage: stage,
                availableBudget: remainingBudget,
                userProfile: userProfile,
                generator: &generator
            )
            
            let usedSteps = stageActivities.reduce(0) { $0 + $1.steps }
            remainingBudget -= usedSteps
            activities.append(contentsOf: stageActivities)
        }
        
        return activities
    }
    
    private static func generateActivitiesForSleepStage(
        stage: SleepStage,
        availableBudget: Int,
        userProfile: PersonalizedProfile,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        var activities: [StepIncrement] = []
        
        // 根据睡眠阶段调整活动概率
        let stageMultiplier: Double
        switch stage.stage {
        case .awake:
            stageMultiplier = 1.0      // 清醒阶段正常概率
        case .light:
            stageMultiplier = 0.4      // 轻度睡眠40%概率
        case .deep:
            stageMultiplier = 0.1      // 深度睡眠10%概率
        case .rem:
            stageMultiplier = 0.2      // REM睡眠20%概率
        }
        
        // 生成可能的生理活动
        for activityType in PhysiologicalActivity.allCases {
            let adjustedProbability = activityType.probability * stageMultiplier
            
            if generator.nextDouble(in: 0...1) < adjustedProbability {
                let steps = min(
                    generator.nextInt(in: activityType.stepRange),
                    availableBudget
                )
                
                if steps > 0 {
                    let activityTime = generateActivityTimestamp(
                        within: stage,
                        activityType: activityType,
                        generator: &generator
                    )
                    
                    activities.append(StepIncrement(
                        timestamp: activityTime,
                        steps: steps,
                        activityType: .idle  // 睡眠期间都标记为静息
                    ))
                }
            }
        }
        
        return activities
    }
    
    // MARK: - 基于时间段的夜间活动生成（简化版）
    
    private static func generateTimeBasedNightActivities(
        bedTime: Date,
        wakeTime: Date,
        stepsBudget: Int,
        userProfile: PersonalizedProfile,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        var activities: [StepIncrement] = []
        var remainingBudget = stepsBudget
        
        let sleepDuration = wakeTime.timeIntervalSince(bedTime)
        
        // 将睡眠时间分为4个时段
        let quarterDuration = sleepDuration / 4.0
        
        for quarter in 0..<4 {
            guard remainingBudget > 0 else { break }
            
            let periodStart = bedTime.addingTimeInterval(Double(quarter) * quarterDuration)
            let periodEnd = periodStart.addingTimeInterval(quarterDuration)
            
            // 不同时段的活动倾向
            let periodMultiplier: Double
            switch quarter {
            case 0: periodMultiplier = 0.3  // 入睡初期活动较少
            case 1: periodMultiplier = 0.8  // 前半夜活动相对较多
            case 2: periodMultiplier = 1.0  // 后半夜正常
            case 3: periodMultiplier = 0.5  // 接近醒来活动减少
            default: periodMultiplier = 0.5
            }
            
            let periodActivities = generateActivitiesInTimePeriod(
                startTime: periodStart,
                endTime: periodEnd,
                availableBudget: remainingBudget,
                multiplier: periodMultiplier,
                generator: &generator
            )
            
            let usedSteps = periodActivities.reduce(0) { $0 + $1.steps }
            remainingBudget -= usedSteps
            activities.append(contentsOf: periodActivities)
        }
        
        return activities
    }
    
    private static func generateActivitiesInTimePeriod(
        startTime: Date,
        endTime: Date,
        availableBudget: Int,
        multiplier: Double,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        var activities: [StepIncrement] = []
        
        for activityType in PhysiologicalActivity.allCases {
            let adjustedProbability = activityType.probability * multiplier
            
            if generator.nextDouble(in: 0...1) < adjustedProbability {
                let steps = min(
                    generator.nextInt(in: activityType.stepRange),
                    availableBudget
                )
                
                if steps > 0 {
                    let randomTime = Date(
                        timeIntervalSince1970: generator.nextDouble(in: 
                            startTime.timeIntervalSince1970...endTime.timeIntervalSince1970
                        )
                    )
                    
                    activities.append(StepIncrement(
                        timestamp: randomTime,
                        steps: steps,
                        activityType: .idle
                    ))
                }
            }
        }
        
        return activities
    }
    
    // MARK: - 清醒时段步数分配（基于睡眠质量影响）
    
    private static func generateWakeTimeStepDistribution(
        sleepData: SleepData,
        remainingSteps: Int,
        date: Date,
        userProfile: PersonalizedProfile,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        // 计算睡眠质量影响因子
        let sleepQualityFactor = calculateSleepQualityFactor(sleepData: sleepData)
        
        print("💤 睡眠质量因子: \(String(format: "%.2f", sleepQualityFactor)) (影响清醒时段活动)")
        
        // 基于睡眠质量调整活动模式
        let adjustedActivityPattern = adjustActivityPatternBySleepQuality(
            originalPattern: userProfile.activityPattern,
            sleepQualityFactor: sleepQualityFactor
        )
        
        // 生成清醒时段的步数分布
        return generateWakeTimeActivities(
            remainingSteps: remainingSteps,
            date: date,
            activityPattern: adjustedActivityPattern,
            sleepEndTime: sleepData.wakeTime,
            generator: &generator
        )
    }
    
    private static func calculateSleepQualityFactor(sleepData: SleepData) -> Double {
        let actualDuration = sleepData.duration
        
        // 基于睡眠时长评估质量（7-9小时为最佳）
        let durationScore: Double
        switch actualDuration {
        case 7...9:
            durationScore = 1.0  // 最佳睡眠时长
        case 6..<7, 9..<10:
            durationScore = 0.8  // 稍短或稍长
        case 5..<6, 10..<11:
            durationScore = 0.6  // 明显不足或过长
        default:
            durationScore = 0.4  // 严重不足或过度
        }
        
        // 如果有睡眠阶段数据，进一步评估质量
        if !sleepData.sleepStages.isEmpty {
            let awakeTime = sleepData.sleepStages
                .filter { $0.stage == .awake }
                .reduce(0) { $0 + $1.duration }
            
            let awakeRatio = awakeTime / (sleepData.duration * 3600)
            let continuityScore = max(0.4, 1.0 - awakeRatio * 3) // 清醒时间越多质量越差
            
            return (durationScore + continuityScore) / 2.0
        }
        
        return durationScore
    }
    
    private static func adjustActivityPatternBySleepQuality(
        originalPattern: DailyActivityPattern,
        sleepQualityFactor: Double
    ) -> DailyActivityPattern {
        
        // 睡眠质量差会降低活动强度
        let adjustment = Float(sleepQualityFactor)
        
        return DailyActivityPattern(
            morningActivity: ActivityIntensity(rawValue: originalPattern.morningActivity.rawValue * adjustment) ?? .low,
            workdayActivity: ActivityIntensity(rawValue: originalPattern.workdayActivity.rawValue * adjustment) ?? .normal,
            eveningActivity: ActivityIntensity(rawValue: originalPattern.eveningActivity.rawValue * adjustment) ?? .low,
            weekendMultiplier: originalPattern.weekendMultiplier * adjustment
        )
    }
    
    private static func generateWakeTimeActivities(
        remainingSteps: Int,
        date: Date,
        activityPattern: DailyActivityPattern,
        sleepEndTime: Date,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        // 这里复用现有的PersonalizedDataGenerator逻辑
        // 但基于调整后的活动模式生成步数分布
        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(date)
        
        // 生成简化版的清醒时段步数分布
        var wakeActivities: [StepIncrement] = []
        
        // 分时段分配剩余步数
        let wakeHour = calendar.component(.hour, from: sleepEndTime)
        let activeHours = Array((wakeHour + 1)...22) // 从起床后1小时到晚上10点
        
        for hour in activeHours {
            let intensity = activityPattern.getIntensity(for: hour, isWeekend: isWeekend)
            let hourSteps = Int(Double(remainingSteps) * Double(intensity.rawValue) / Double(activeHours.count))
            
            if hourSteps > 0 {
                let incrementCount = generator.nextInt(in: 2...6)
                let stepsPerIncrement = hourSteps / incrementCount
                
                for i in 0..<incrementCount {
                    let minute = generator.nextInt(in: 0...59)
                    var components = calendar.dateComponents([.year, .month, .day], from: date)
                    components.hour = hour
                    components.minute = minute
                    
                    if let timestamp = calendar.date(from: components) {
                        wakeActivities.append(StepIncrement(
                            timestamp: timestamp,
                            steps: stepsPerIncrement + (i == 0 ? hourSteps % incrementCount : 0),
                            activityType: .walking
                        ))
                    }
                }
            }
        }
        
        return wakeActivities
    }
    
    // MARK: - 辅助方法
    
    private static func generateActivityTimestamp(
        within stage: SleepStage,
        activityType: PhysiologicalActivity,
        generator: inout SeededRandomGenerator
    ) -> Date {
        
        let stageDuration = stage.endTime.timeIntervalSince(stage.startTime)
        let randomOffset = generator.nextDouble(in: 0...stageDuration)
        
        return stage.startTime.addingTimeInterval(randomOffset)
    }
}

// MARK: - 苹果健康数据规范增强
extension SleepAwareStepsGenerator {
    
    /// 确保步数数据符合HealthKit规范
    static func validateHealthKitCompliance(stepIncrements: [StepIncrement]) -> [StepIncrement] {
        return stepIncrements.map { increment in
            // 确保时间戳精度为秒级
            let roundedTimestamp = Date(timeIntervalSince1970: 
                round(increment.timestamp.timeIntervalSince1970))
            
            // 确保步数在合理范围内（HealthKit限制）
            let validatedSteps = max(0, min(increment.steps, 10000)) // 单次最多10000步
            
            return StepIncrement(
                timestamp: roundedTimestamp,
                steps: validatedSteps,
                activityType: increment.activityType
            )
        }
    }
    
    /// 生成HealthKit兼容的设备元数据
    static func generateDeviceMetadata() -> [String: Any] {
        return [
            "HKDevice": [
                "name": "iPhone",
                "manufacturer": "Apple Inc.",
                "model": "iPhone", // 不指定具体型号以保护隐私
                "hardwareVersion": "Unknown",
                "softwareVersion": ProcessInfo.processInfo.operatingSystemVersionString
            ],
            "HKMetadataKey": [
                "HKWasUserEntered": false,
                "HKTimeZone": TimeZone.current.identifier
            ]
        ]
    }
}