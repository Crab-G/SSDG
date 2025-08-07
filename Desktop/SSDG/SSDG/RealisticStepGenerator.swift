import Foundation

/// 真实步数生成器 - 基于苹果健康数据的真实模式
struct RealisticStepGenerator {
    
    // MARK: - 活动类型定义
    
    enum ActivityEvent {
        case majorActivity(type: MajorActivityType, steps: Int)
        case minorMovement(type: MinorMovementType, steps: Int)
        case microMovement(steps: Int)  // 1-10步的微小移动
        
        var steps: Int {
            switch self {
            case .majorActivity(_, let steps): return steps
            case .minorMovement(_, let steps): return steps
            case .microMovement(let steps): return steps
            }
        }
        
        var duration: TimeInterval {
            switch self {
            case .majorActivity(let type, _): return type.durationRange.lowerBound
            case .minorMovement(let type, _): return type.durationRange.lowerBound
            case .microMovement(_): return 60 // 1分钟
            }
        }
    }
    
    enum MajorActivityType {
        case morningExercise    // 晨练
        case commute           // 通勤
        case lunch             // 午餐活动
        case shopping          // 购物
        case eveningWalk       // 晚间散步
        case gym               // 健身房
        case sports            // 运动
        
        var durationRange: ClosedRange<TimeInterval> {
            switch self {
            case .morningExercise: return 1800...3600    // 30-60分钟
            case .commute: return 600...1800             // 10-30分钟
            case .lunch: return 300...900                // 5-15分钟
            case .shopping: return 1800...5400           // 30-90分钟
            case .eveningWalk: return 1200...3600        // 20-60分钟
            case .gym: return 2400...5400                // 40-90分钟
            case .sports: return 1800...7200             // 30-120分钟
            }
        }
        
        var stepRange: ClosedRange<Int> {
            switch self {
            case .morningExercise: return 1500...4000
            case .commute: return 300...1500
            case .lunch: return 200...800
            case .shopping: return 2000...6000
            case .eveningWalk: return 1000...4000
            case .gym: return 500...2000
            case .sports: return 3000...10000
            }
        }
    }
    
    enum MinorMovementType {
        case bathroom          // 上厕所
        case water            // 接水/咖啡
        case roomToRoom       // 房间之间移动
        case shortWalk        // 短距离行走
        case stairs           // 上下楼梯
        
        var durationRange: ClosedRange<TimeInterval> {
            switch self {
            case .bathroom: return 60...180         // 1-3分钟
            case .water: return 30...120            // 0.5-2分钟
            case .roomToRoom: return 20...60        // 20秒-1分钟
            case .shortWalk: return 60...300        // 1-5分钟
            case .stairs: return 30...120           // 0.5-2分钟
            }
        }
        
        var stepRange: ClosedRange<Int> {
            switch self {
            case .bathroom: return 20...80
            case .water: return 30...120
            case .roomToRoom: return 10...40
            case .shortWalk: return 50...300
            case .stairs: return 40...150
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 检查时间是否在睡眠期间
    private static func isInSleepPeriod(_ time: Date, sleepData: SleepData) -> Bool {
        _ = Calendar.current
        
        // 处理跨天睡眠
        if sleepData.bedTime > sleepData.wakeTime {
            // 跨天睡眠（如23:00睡到第二天7:00）
            return time >= sleepData.bedTime || time <= sleepData.wakeTime
        } else {
            // 同一天睡眠（如午睡）
            return time >= sleepData.bedTime && time <= sleepData.wakeTime
        }
    }
    
    // MARK: - 主要生成方法
    
    /// 生成一天的真实步数活动
    static func generateDailyStepEvents(
        for profile: PersonalizedProfile,
        date: Date,
        totalTargetSteps: Int,
        sleepData: SleepData,
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        var events: [(time: Date, event: ActivityEvent)] = []
        _ = Calendar.current
        
        // 1. 生成主要活动（1-4个大型活动）
        let majorEvents = generateMajorActivities(
            profile: profile,
            date: date,
            sleepData: sleepData,
            targetSteps: Int(Double(totalTargetSteps) * 0.85), // 85%的步数来自主要活动
            generator: &generator
        )
        events.append(contentsOf: majorEvents)
        
        // 2. 生成次要移动（5-15个中等移动）
        let minorEvents = generateMinorMovements(
            profile: profile,
            date: date,
            sleepData: sleepData,
            existingEvents: events,
            targetSteps: Int(Double(totalTargetSteps) * 0.12), // 12%的步数
            generator: &generator
        )
        events.append(contentsOf: minorEvents)
        
        // 3. 生成微小移动（10-30个极小移动）
        let microEvents = generateMicroMovements(
            profile: profile,
            date: date,
            sleepData: sleepData,
            existingEvents: events,
            targetSteps: Int(Double(totalTargetSteps) * 0.03), // 3%的步数
            generator: &generator
        )
        events.append(contentsOf: microEvents)
        
        // 4. 转换为步数增量
        return convertEventsToIncrements(events: events, generator: &generator)
    }
    
    // MARK: - 主要活动生成
    
    private static func generateMajorActivities(
        profile: PersonalizedProfile,
        date: Date,
        sleepData: SleepData,
        targetSteps: Int,
        generator: inout SeededRandomGenerator
    ) -> [(time: Date, event: ActivityEvent)] {
        
        var events: [(time: Date, event: ActivityEvent)] = []
        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(date)
        let wakeTime = sleepData.wakeTime
        
        // 根据活动水平决定主要活动数量
        // 注：活动数量当前由具体的活动类型决定，而不是预设数量
        
        var remainingSteps = targetSteps
        
        // 早晨活动（如果不是夜猫子）
        if profile.sleepType != .nightOwl && generator.nextBool(probability: 0.4) {
            let morningTime = wakeTime.addingTimeInterval(generator.nextDouble(in: 1800...5400)) // 起床后30-90分钟
            let steps = generator.nextInt(in: MajorActivityType.morningExercise.stepRange)
            events.append((time: morningTime, event: .majorActivity(type: .morningExercise, steps: steps)))
            remainingSteps -= steps
        }
        
        // 通勤（工作日）
        if !isWeekend && generator.nextBool(probability: 0.8) {
            // 确保通勤时间在醒来之后
            let commuteHour = max(calendar.component(.hour, from: wakeTime) + 1, generator.nextInt(in: 7...9))
            if let commuteTime = calendar.date(bySettingHour: commuteHour, minute: generator.nextInt(in: 0...59), second: 0, of: date),
               !isInSleepPeriod(commuteTime, sleepData: sleepData) {
                let steps = generator.nextInt(in: MajorActivityType.commute.stepRange)
                events.append((time: commuteTime, event: .majorActivity(type: .commute, steps: steps)))
                remainingSteps -= steps
            }
        }
        
        // 午间活动
        if generator.nextBool(probability: 0.6) {
            if let lunchTime = calendar.date(bySettingHour: 12, minute: generator.nextInt(in: 0...59), second: 0, of: date),
               !isInSleepPeriod(lunchTime, sleepData: sleepData) {
                let steps = generator.nextInt(in: MajorActivityType.lunch.stepRange)
                events.append((time: lunchTime, event: .majorActivity(type: .lunch, steps: steps)))
                remainingSteps -= steps
            }
        }
        
        // 晚间活动（最大的活动量）
        let bedtimeHour = calendar.component(.hour, from: sleepData.bedTime)
        let maxEveningHour = bedtimeHour > 17 ? min(bedtimeHour - 1, 20) : 20
        let eveningHour = generator.nextInt(in: 17...maxEveningHour)
        guard let eveningTime = calendar.date(bySettingHour: eveningHour, minute: generator.nextInt(in: 0...59), second: 0, of: date),
              !isInSleepPeriod(eveningTime, sleepData: sleepData) else { return events }
        
        // 选择晚间活动类型
        let eveningActivity: MajorActivityType
        let activityRandom = generator.nextFloat(in: 0...1)
        if activityRandom < 0.3 {
            eveningActivity = .eveningWalk
        } else if activityRandom < 0.5 {
            eveningActivity = .shopping
        } else if activityRandom < 0.7 {
            eveningActivity = .gym
        } else {
            eveningActivity = .sports
        }
        
        // 确保晚间活动获得剩余的大部分步数
        let eveningSteps = max(remainingSteps, generator.nextInt(in: eveningActivity.stepRange))
        events.append((time: eveningTime, event: .majorActivity(type: eveningActivity, steps: eveningSteps)))
        
        return events
    }
    
    // MARK: - 次要移动生成
    
    private static func generateMinorMovements(
        profile: PersonalizedProfile,
        date: Date,
        sleepData: SleepData,
        existingEvents: [(time: Date, event: ActivityEvent)],
        targetSteps: Int,
        generator: inout SeededRandomGenerator
    ) -> [(time: Date, event: ActivityEvent)] {
        
        var events: [(time: Date, event: ActivityEvent)] = []
        let calendar = Calendar.current
        
        // 生成5-15个次要移动
        let movementCount = generator.nextInt(in: 5...15)
        var remainingSteps = targetSteps
        
        for _ in 0..<movementCount {
            guard remainingSteps > 0 else { break }
            
            // 随机选择时间（避开睡眠和主要活动时间）
            var attempts = 0
            var validTime: Date?
            
            while attempts < 10 && validTime == nil {
                // 根据醒来和睡觉时间生成合理的活动时间
                let wakeHour = calendar.component(.hour, from: sleepData.wakeTime)
                let sleepHour = calendar.component(.hour, from: sleepData.bedTime)
                
                let validHourRange: ClosedRange<Int>
                if sleepHour > wakeHour {
                    // 正常作息
                    validHourRange = (wakeHour + 1)...max(wakeHour + 1, sleepHour - 1)
                } else {
                    // 夜猫子作息
                    validHourRange = 10...22
                }
                
                let hour = generator.nextInt(in: validHourRange)
                let minute = generator.nextInt(in: 0...59)
                if let candidateTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) {
                    // 检查是否在睡眠时间内
                    if isInSleepPeriod(candidateTime, sleepData: sleepData) {
                        attempts += 1
                        continue
                    }
                    
                    // 检查是否与现有事件冲突
                    let hasConflict = existingEvents.contains { event in
                        abs(event.time.timeIntervalSince(candidateTime)) < 300 // 5分钟内
                    }
                    
                    if !hasConflict {
                        validTime = candidateTime
                    }
                }
                attempts += 1
            }
            
            guard let eventTime = validTime else { continue }
            
            // 随机选择移动类型
            let movementType: MinorMovementType
            let typeRandom = generator.nextFloat(in: 0...1)
            if typeRandom < 0.3 {
                movementType = .bathroom
            } else if typeRandom < 0.5 {
                movementType = .water
            } else if typeRandom < 0.7 {
                movementType = .roomToRoom
            } else if typeRandom < 0.9 {
                movementType = .shortWalk
            } else {
                movementType = .stairs
            }
            
            let steps = min(remainingSteps, generator.nextInt(in: movementType.stepRange))
            events.append((time: eventTime, event: .minorMovement(type: movementType, steps: steps)))
            remainingSteps -= steps
        }
        
        return events
    }
    
    // MARK: - 微小移动生成
    
    private static func generateMicroMovements(
        profile: PersonalizedProfile,
        date: Date,
        sleepData: SleepData,
        existingEvents: [(time: Date, event: ActivityEvent)],
        targetSteps: Int,
        generator: inout SeededRandomGenerator
    ) -> [(time: Date, event: ActivityEvent)] {
        
        var events: [(time: Date, event: ActivityEvent)] = []
        
        // 在主要活动前后生成微小移动（准备活动）
        for existingEvent in existingEvents {
            if case .majorActivity = existingEvent.event {
                // 活动前的准备（1-3个微小移动）
                let preMoveCount = generator.nextInt(in: 1...3)
                for i in 0..<preMoveCount {
                    let preTime = existingEvent.time.addingTimeInterval(Double(-60 * (i + 1))) // 活动前1-3分钟
                    // 确保不在睡眠时段
                    if !isInSleepPeriod(preTime, sleepData: sleepData) {
                        let steps = generator.nextInt(in: 1...10)
                        events.append((time: preTime, event: .microMovement(steps: steps)))
                    }
                }
            }
        }
        
        // 早晨起床后的微小移动（只在醒来后生成）
        let morningMoveCount = generator.nextInt(in: 3...8)
        for i in 0..<morningMoveCount {
            let moveTime = sleepData.wakeTime.addingTimeInterval(Double(60 * (i + 1))) // 醒来后的每分钟
            let steps = generator.nextInt(in: 1...15)
            events.append((time: moveTime, event: .microMovement(steps: steps)))
        }
        
        // 睡眠期间的夜间活动（极少）
        if generator.nextBool(probability: 0.25) { // 25%概率有夜间活动
            // 生成1次夜间起夜
            let sleepDuration = sleepData.wakeTime.timeIntervalSince(sleepData.bedTime)
            let nightTime = sleepData.bedTime.addingTimeInterval(generator.nextDouble(in: sleepDuration * 0.3...sleepDuration * 0.7))
            let bathroomSteps = generator.nextInt(in: 20...50) // 起夜上厕所的步数
            events.append((time: nightTime, event: .minorMovement(type: .bathroom, steps: bathroomSteps)))
        }
        
        return events
    }
    
    // MARK: - 转换为步数增量
    
    private static func convertEventsToIncrements(
        events: [(time: Date, event: ActivityEvent)],
        generator: inout SeededRandomGenerator
    ) -> [StepIncrement] {
        
        var increments: [StepIncrement] = []
        
        // 按时间排序
        let sortedEvents = events.sorted { $0.time < $1.time }
        
        for (time, event) in sortedEvents {
            switch event {
            case .majorActivity(let type, let totalSteps):
                // 大活动分解为多个增量
                let duration = generator.nextDouble(in: type.durationRange)
                let incrementCount = max(3, totalSteps / 200) // 每200步一个增量
                let baseStepsPerIncrement = totalSteps / incrementCount
                
                for i in 0..<incrementCount {
                    let incrementTime = time.addingTimeInterval(duration * Double(i) / Double(incrementCount))
                    let variance = generator.nextInt(in: -50...50)
                    let steps = max(10, baseStepsPerIncrement + variance)
                    
                    increments.append(StepIncrement(
                        timestamp: incrementTime,
                        steps: steps,
                        activityType: mapToActivityType(type)
                    ))
                }
                
            case .minorMovement(let type, let steps):
                // 次要移动通常是单个增量
                increments.append(StepIncrement(
                    timestamp: time,
                    steps: steps,
                    activityType: mapToActivityType(type)
                ))
                
            case .microMovement(let steps):
                // 微小移动
                increments.append(StepIncrement(
                    timestamp: time,
                    steps: steps,
                    activityType: .idle
                ))
            }
        }
        
        return increments
    }
    
    // MARK: - 辅助方法
    
    private static func mapToActivityType(_ major: MajorActivityType) -> StepIncrement.ActivityType {
        switch major {
        case .morningExercise, .gym, .sports: return .running
        case .commute, .eveningWalk: return .walking
        case .lunch, .shopping: return .walking
        }
    }
    
    private static func mapToActivityType(_ minor: MinorMovementType) -> StepIncrement.ActivityType {
        switch minor {
        case .bathroom, .water, .roomToRoom: return .idle
        case .shortWalk: return .walking
        case .stairs: return .stairs
        }
    }
}

// MARK: - Extensions

extension SeededRandomGenerator {
    mutating func nextBool(probability: Double) -> Bool {
        return nextDouble(in: 0...1) < probability
    }
}
