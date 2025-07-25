//
//  PersonalizedDataGenerator.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation

// MARK: - 个性化数据生成器
class PersonalizedDataGenerator {
    
    // MARK: - 辅助函数
    
    // 从字符串生成种子
    private static func generateSeed(from string: String) -> Int {
        return abs(string.hashValue) % 100000
    }
    
    // MARK: - 睡眠数据生成
    
    // 生成个性化睡眠数据（在用户起床时间点触发）
    static func generatePersonalizedSleepData(for user: VirtualUser, date: Date, mode: DataMode = .simple) -> SleepData {
        let profile = user.personalizedProfile
        let seed = generateSeed(from: user.id + date.timeIntervalSince1970.description)
        var generator = SeededRandomGenerator(seed: UInt64(abs(seed)))
        
        // 基于睡眠类型生成睡眠时间
        let sleepTiming = generateSleepTiming(for: profile.sleepType, date: date, using: &generator)
        let sleepDuration = generateSleepDuration(for: profile.sleepType, using: &generator)
        
        print("🌙 个性化睡眠生成 - \(profile.sleepType.displayName)")
        print("   入睡时间: \(DateFormatter.localizedString(from: sleepTiming.bedtime, dateStyle: .none, timeStyle: .short))")
        print("   起床时间: \(DateFormatter.localizedString(from: sleepTiming.wakeTime, dateStyle: .none, timeStyle: .short))")
        print("   睡眠时长: \(String(format: "%.1f", sleepDuration))小时")
        
        // 生成睡眠阶段数据
        if mode == .wearableDevice {
            return generateComprehensiveSleep(
                bedtime: sleepTiming.bedtime,
                wakeTime: sleepTiming.wakeTime,
                totalDuration: sleepDuration,
                consistency: profile.sleepType.consistency,
                generator: &generator
            )
        } else {
            return generateSimpleSleep(
                bedtime: sleepTiming.bedtime,
                wakeTime: sleepTiming.wakeTime,
                totalDuration: sleepDuration
            )
        }
    }
    
    // MARK: - 步数数据生成（预计算+分片注入）
    
    // 生成个性化每日步数分布
    static func generatePersonalizedDailySteps(for user: VirtualUser, date: Date) -> DailyStepDistribution {
        let profile = user.personalizedProfile
        let seed = generateSeed(from: user.id + date.timeIntervalSince1970.description + "steps")
        
        print("🚶‍♂️ 个性化步数生成 - \(profile.activityLevel.displayName)")
        
        let distribution = DailyStepDistribution.generate(for: profile, date: date, seed: UInt64(abs(seed)))
        
        print("   目标步数: \(distribution.totalSteps)")
        print("   活跃时段: \(distribution.hourlyDistribution.count)小时")
        print("   微增量数据点: \(distribution.incrementalData.count)个")
        
        // 显示时间段分布概况
        let calendar = Calendar.current
        let isWeekend = calendar.component(.weekday, from: date) == 1 || calendar.component(.weekday, from: date) == 7
        print("   作息模式: \(isWeekend ? "周末" : "工作日")")
        
        // 显示主要活跃时段
        let sortedHours = distribution.hourlyDistribution.sorted { $0.value > $1.value }
        let topHours = sortedHours.prefix(3)
        let topHoursStr = topHours.map { "\($0.key):00(\($0.value)步)" }.joined(separator: ", ")
        print("   主要活跃: \(topHoursStr)")
        
        return distribution
    }
    
    // 转换为HealthKit兼容的小时聚合数据
    static func convertToHourlySteps(from distribution: DailyStepDistribution) -> [StepsData] {
        var hourlySteps: [HourlySteps] = []
        let calendar = Calendar.current
        
        for (hour, steps) in distribution.hourlyDistribution.sorted(by: { $0.key < $1.key }) {
            var components = calendar.dateComponents([.year, .month, .day], from: distribution.date)
            components.hour = hour
            components.minute = 0
            components.second = 0
            
            if let hourStartDate = calendar.date(from: components) {
                let hourEndDate = calendar.date(byAdding: .hour, value: 1, to: hourStartDate) ?? hourStartDate
                let hourlyStep = HourlySteps(
                    hour: hour,
                    steps: steps,
                    startTime: hourStartDate,
                    endTime: hourEndDate
                )
                hourlySteps.append(hourlyStep)
            }
        }
        
        return [StepsData(date: distribution.date, hourlySteps: hourlySteps)]
    }
    
    // MARK: - 历史数据生成
    
    // 生成个性化历史数据
    static func generatePersonalizedHistoricalData(
        for user: VirtualUser,
        days: Int,
        mode: DataMode = .simple
    ) -> (sleepData: [SleepData], stepsData: [StepsData]) {
        
        let profile = user.personalizedProfile
        var allSleepData: [SleepData] = []
        var allStepsData: [StepsData] = []
        
        print("📊 生成个性化历史数据 - \(days)天")
        print("   用户标签: \(profile.sleepType.displayName) + \(profile.activityLevel.displayName)")
        
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in (1...days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            // 生成该日睡眠数据
            let sleepData = generatePersonalizedSleepData(for: user, date: date, mode: mode)
            allSleepData.append(sleepData)
            
            // 生成该日步数数据
            let stepDistribution = generatePersonalizedDailySteps(for: user, date: date)
            let hourlySteps = convertToHourlySteps(from: stepDistribution)
            allStepsData.append(contentsOf: hourlySteps)
            
            if dayOffset % 10 == 0 {
                print("   已生成: \(days - dayOffset + 1)/\(days)天")
            }
        }
        
        print("✅ 历史数据生成完成")
        print("   睡眠数据: \(allSleepData.count)条")
        print("   步数数据: \(allStepsData.count)条")
        
        return (sleepData: allSleepData, stepsData: allStepsData)
    }
    
    // MARK: - 实时步数注入系统
    
    // 步数注入管理器
    @MainActor
    class StepInjectionManager: ObservableObject {
        @Published var isActive = false
        @Published var currentDistribution: DailyStepDistribution?
        @Published var injectedSteps = 0
        @Published var isSleepMode = false
        
        private var injectionTimer: Timer?
        private var pendingIncrements: [StepIncrement] = []
        private var originalDelay: TimeInterval = 0.05 // 原始延迟
        
        // 启动今日步数注入
        func startTodayInjection(for user: VirtualUser) {
            let today = Date()
            let distribution = PersonalizedDataGenerator.generatePersonalizedDailySteps(for: user, date: today)
            
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
            
            // 实际注入到HealthKit
            Task { @MainActor in
                let success = await HealthKitManager.shared.writeStepIncrement(increment)
                if success {
                    print("✅ 步数增量已写入HealthKit")
                } else {
                    print("❌ 步数增量写入HealthKit失败")
                }
            }
        }
        
        // MARK: - 睡眠模式控制
        
        // 进入睡眠模式
        func enterSleepMode() {
            isSleepMode = true
            print("😴 步数注入进入睡眠模式")
            
            // 过滤掉睡眠时间的步数增量，或将其降至个位数
            filterSleepTimeIncrements()
            
            // 调整注入频率
            adjustInjectionFrequency(sleepMode: true)
        }
        
        // 退出睡眠模式
        func exitSleepMode() {
            isSleepMode = false
            print("🌅 步数注入退出睡眠模式")
            
            // 恢复正常注入频率
            adjustInjectionFrequency(sleepMode: false)
        }
        
        // 过滤睡眠时间的步数增量
        private func filterSleepTimeIncrements() {
            let calendar = Calendar.current
            
            // 定义睡眠时间段（晚上11点到早上6点）
            let sleepStartHour = 23
            let sleepEndHour = 6
            
            // 过滤待注入的增量
            pendingIncrements = pendingIncrements.compactMap { increment in
                let hour = calendar.component(.hour, from: increment.timestamp)
                
                // 检查是否在睡眠时间段
                let isInSleepTime = (hour >= sleepStartHour) || (hour < sleepEndHour)
                
                if isInSleepTime {
                    // 睡眠时间：95%概率为0步，5%概率为个位数步数
                    let shouldHaveSteps = Int.random(in: 1...100) <= 5 // 5%概率
                    
                    let sleepSteps: Int
                    if shouldHaveSteps {
                        // 5%概率：1-9步的个位数步数
                        sleepSteps = Int.random(in: 1...9)
                    } else {
                        // 95%概率：0步
                        sleepSteps = 0
                    }
                    
                    return StepIncrement(
                        timestamp: increment.timestamp,
                        steps: sleepSteps,
                        activityType: .idle // 标记为睡眠时间的静息活动
                    )
                } else {
                    // 非睡眠时间：保持原样
                    return increment
                }
            }
            
            print("😴 已调整睡眠时间段的步数增量 (95%为0步，5%为1-9步)")
        }
        
        // 智能调整注入频率
        private func adjustInjectionFrequency(sleepMode: Bool) {
            if sleepMode {
                // 睡眠模式：大幅降低注入频率
                originalDelay = 30.0 // 30秒一次
            } else {
                // 正常模式：恢复原始频率
                originalDelay = 0.05 // 50毫秒一次
            }
        }
    }
    
    // MARK: - 私有辅助方法
    
    private static func generateSleepTiming(for sleepType: SleepType, date: Date, using generator: inout SeededRandomGenerator) -> (bedtime: Date, wakeTime: Date) {
        let calendar = Calendar.current
        let sleepRange = sleepType.sleepTimeRange
        let consistency = sleepType.consistency
        
        // 基于一致性添加随机变化
        let variationHours = (1.0 - consistency) * 2.0 // 0-2小时变化
        let bedtimeVariation = generator.nextFloat(in: -variationHours...variationHours)
        let wakeVariation = generator.nextFloat(in: -variationHours...variationHours)
        
        // 计算入睡时间
        var bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let bedtimeHour = Float(sleepRange.start) + bedtimeVariation
        bedtimeComponents.hour = Int(bedtimeHour)
        bedtimeComponents.minute = Int((bedtimeHour - Float(Int(bedtimeHour))) * 60)
        
        // 如果入睡时间在第二天（跨日睡眠）
        if sleepRange.start < sleepRange.end {
            // 同日睡眠，不需要调整
        } else {
            // 跨日睡眠，入睡时间在前一天
            bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: -1, to: date) ?? date)
            bedtimeComponents.hour = Int(bedtimeHour)
            bedtimeComponents.minute = Int((bedtimeHour - Float(Int(bedtimeHour))) * 60)
        }
        
        let bedtime = calendar.date(from: bedtimeComponents) ?? date
        
        // 计算起床时间
        var wakeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let wakeHour = Float(sleepRange.end) + wakeVariation
        wakeComponents.hour = Int(wakeHour)
        wakeComponents.minute = Int((wakeHour - Float(Int(wakeHour))) * 60)
        
        let wakeTime = calendar.date(from: wakeComponents) ?? date
        
        return (bedtime: bedtime, wakeTime: wakeTime)
    }
    
    private static func generateSleepDuration(for sleepType: SleepType, using generator: inout SeededRandomGenerator) -> Double {
        let range = sleepType.durationRange
        return Double(generator.nextFloat(in: Float(range.min)...Float(range.max)))
    }
    
    private static func generateComprehensiveSleep(
        bedtime: Date,
        wakeTime: Date,
        totalDuration: Double,
        consistency: Float,
        generator: inout SeededRandomGenerator
    ) -> SleepData {
        
        // 生成睡眠阶段
        let cycleCount = Int(totalDuration / 1.5) // 每个周期约1.5小时
        var stages: [SleepStage] = []
        
        let stageDuration = totalDuration * 3600 / Double(cycleCount) // 秒
        var currentTime = bedtime
        let calendar = Calendar.current
        
        for cycle in 0..<cycleCount {
            let isEarlyCycle = cycle < cycleCount / 2
            
            // 早期周期更多深度睡眠，后期更多REM
            if isEarlyCycle {
                // 轻度睡眠
                stages.append(SleepStage(
                    stage: .light,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.4), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.4), to: currentTime) ?? currentTime
                
                // 深度睡眠
                stages.append(SleepStage(
                    stage: .deep,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.4), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.4), to: currentTime) ?? currentTime
                
                // REM睡眠
                stages.append(SleepStage(
                    stage: .rem,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.2), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.2), to: currentTime) ?? currentTime
            } else {
                // 后期周期
                stages.append(SleepStage(
                    stage: .light,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.3), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.3), to: currentTime) ?? currentTime
                
                stages.append(SleepStage(
                    stage: .deep,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.2), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.2), to: currentTime) ?? currentTime
                
                stages.append(SleepStage(
                    stage: .rem,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.5), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.5), to: currentTime) ?? currentTime
            }
        }
        
        // 添加少量清醒时间
        let awakeCount = Int(Float(cycleCount) * (1.0 - consistency) * 3) // 不规律的人更容易醒
        for _ in 0..<awakeCount {
            let randomIndex = generator.nextInt(in: 0...(stages.count - 1))
            let randomStage = stages[randomIndex]
            let awakeDuration = generator.nextInt(in: 60...600) // 1-10分钟
            
            let awakeTime = calendar.date(byAdding: .second, value: generator.nextInt(in: 0...Int(randomStage.duration)), to: randomStage.startTime) ?? randomStage.startTime
            
            stages.append(SleepStage(
                stage: .awake,
                startTime: awakeTime,
                endTime: calendar.date(byAdding: .second, value: awakeDuration, to: awakeTime) ?? awakeTime
            ))
        }
        
        return SleepData(
            date: bedtime,
            bedTime: bedtime,
            wakeTime: wakeTime,
            sleepStages: stages
        )
    }
    
    private static func generateSimpleSleep(
        bedtime: Date,
        wakeTime: Date,
        totalDuration: Double
    ) -> SleepData {
        let calendar = Calendar.current
        let _ = calendar.date(byAdding: .minute, value: Int.random(in: 5...30), to: bedtime) ?? bedtime
        
        return SleepData(
            date: bedtime,
            bedTime: bedtime,
            wakeTime: wakeTime,
            sleepStages: []
        )
    }
    
    // MARK: - 步数生成相关方法 (新增)
    
    /// 计算每日步数（基于用户特征和日期）
    static func calculateDailySteps(for user: VirtualUser, date: Date) -> Int {
        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(date)
        
        // 基础步数范围 (根据用户年龄和性别调整)
        let baseMin: Int
        let baseMax: Int
        
        switch user.age {
        case 18...30:
            baseMin = isWeekend ? 6000 : 8000
            baseMax = isWeekend ? 12000 : 15000
        case 31...50:
            baseMin = isWeekend ? 5000 : 7000
            baseMax = isWeekend ? 10000 : 13000
        case 51...70:
            baseMin = isWeekend ? 4000 : 6000
            baseMax = isWeekend ? 8000 : 11000
        default: // 70+
            baseMin = isWeekend ? 3000 : 4000
            baseMax = isWeekend ? 6000 : 8000
        }
        
        // 性别调整 (统计上男性平均步数略高)
        let genderMultiplier = user.gender == .male ? 1.1 : 1.0
        
        // BMI影响 (健康BMI范围内的用户步数可能更高)
        let bmi = user.weight / pow(user.height / 100, 2)
        let bmiMultiplier: Double
        switch bmi {
        case 18.5...24.9: // 正常BMI
            bmiMultiplier = 1.1
        case 25.0...29.9: // 超重
            bmiMultiplier = 0.9
        case 30...: // 肥胖
            bmiMultiplier = 0.8
        default: // 过轻
            bmiMultiplier = 0.85
        }
        
        // 应用调整因子
        let adjustedMin = Int(Double(baseMin) * genderMultiplier * bmiMultiplier)
        let adjustedMax = Int(Double(baseMax) * genderMultiplier * bmiMultiplier)
        
        // 添加每日随机变化 (±20%)
        let baseSteps = Int.random(in: adjustedMin...adjustedMax)
        let variation = Double.random(in: 0.8...1.2)
        let finalSteps = Int(Double(baseSteps) * variation)
        
        // 确保在合理范围内
        return max(800, min(25000, finalSteps))
    }
    
    /// 根据用户特征生成活动模式
    static func generateActivityPattern(for user: VirtualUser, date: Date) -> ActivityPattern {
        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(date)
        
        // 根据年龄确定活动类型
        let primaryActivity: ActivityType
        let secondaryActivity: ActivityType
        
        switch user.age {
        case 18...25: // 学生/年轻职场
            primaryActivity = isWeekend ? .exercise : .commuting
            secondaryActivity = .walking
        case 26...40: // 职场主力
            primaryActivity = .commuting
            secondaryActivity = isWeekend ? .exercise : .walking
        case 41...60: // 中年职场
            primaryActivity = .walking
            secondaryActivity = isWeekend ? .exercise : .standing
        default: // 退休人群
            primaryActivity = .walking
            secondaryActivity = .standing
        }
        
        return ActivityPattern(
            primaryActivity: primaryActivity,
            secondaryActivity: secondaryActivity,
            peakHours: isWeekend ? [10, 11, 15, 16] : [8, 9, 12, 13, 18, 19],
            lowActivityHours: [0, 1, 2, 3, 4, 5, 6, 22, 23]
        )
    }
}

/// 活动模式
struct ActivityPattern {
    let primaryActivity: ActivityType
    let secondaryActivity: ActivityType
    let peakHours: [Int]
    let lowActivityHours: [Int]
} 