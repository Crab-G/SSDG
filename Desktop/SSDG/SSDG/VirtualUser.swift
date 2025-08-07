//
//  VirtualUser.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation

// MARK: - 睡眠类型标签
enum SleepType: String, CaseIterable, Codable {
    case nightOwl = "夜猫型"      // 凌晨2-3点睡，下午醒
    case earlyBird = "早起型"     // 晚上10-11点睡，早上6-7点醒
    case irregular = "紊乱型"     // 不规律作息
    case normal = "正常型"        // 晚上11-12点睡，早上7-8点醒
    
    var displayName: String {
        return rawValue
    }
    
    // 睡眠时间范围定义
    var sleepTimeRange: (start: Int, end: Int) {
        switch self {
        case .nightOwl:
            return (start: 2, end: 14)    // 凌晨2点-下午2点
        case .earlyBird:
            return (start: 22, end: 6)    // 晚上10点-早上6点
        case .irregular:
            return (start: 23, end: 8)    // 基础范围，会有更大随机变化
        case .normal:
            return (start: 23, end: 7)    // 晚上11点-早上7点
        }
    }
    
    // 睡眠时长范围定义
    var durationRange: (min: Int, max: Int) {
        switch self {
        case .nightOwl:
            return (min: 6, max: 10)      // 6-10小时
        case .earlyBird:
            return (min: 7, max: 9)       // 7-9小时
        case .irregular:
            return (min: 5, max: 11)      // 5-11小时，变化大
        case .normal:
            return (min: 7, max: 9)       // 7-9小时
        }
    }
    
    // 一致性系数 (0.0-1.0，1.0表示非常规律)
    var consistency: Float {
        switch self {
        case .nightOwl:
            return 0.8                    // 夜猫子通常很规律
        case .earlyBird:
            return 0.9                    // 早起者最规律
        case .irregular:
            return 0.3                    // 紊乱型最不规律
        case .normal:
            return 0.7                    // 正常型比较规律
        }
    }
}

// MARK: - 活动水平标签
enum ActivityLevel: String, CaseIterable, Codable {
    case low = "低活动量"         // 2000-5000步
    case medium = "中等活动量"    // 5000-8000步
    case high = "高活动量"        // 8000-12000步
    case veryHigh = "超高活动量"  // 12000-15000步
    
    var displayName: String {
        return rawValue
    }
    
    // 步数范围定义
    var stepRange: (min: Int, max: Int) {
        switch self {
        case .low:
            return (min: 1500, max: 4500)   // 久坐族：1500-4500步
        case .medium:
            return (min: 4500, max: 8500)   // 普通上班族：4500-8500步
        case .high:
            return (min: 8500, max: 13000)  // 爱运动人群：8500-13000步
        case .veryHigh:
            return (min: 13000, max: 18000) // 专业运动员/健身达人：13000-18000步
        }
    }
    
    // 活动强度系数
    var intensityMultiplier: Float {
        switch self {
        case .low:
            return 0.7
        case .medium:
            return 1.0
        case .high:
            return 1.3
        case .veryHigh:
            return 1.6
        }
    }
}

// MARK: - 个性化用户配置
struct PersonalizedProfile: Codable {
    let sleepType: SleepType
    let activityLevel: ActivityLevel
    let activityPattern: DailyActivityPattern
    let createdDate: Date
    
    init(sleepType: SleepType, activityLevel: ActivityLevel) {
        self.sleepType = sleepType
        self.activityLevel = activityLevel
        self.activityPattern = DailyActivityPattern.defaultPattern(for: activityLevel)
        self.createdDate = Date()
    }
    
    // 从现有用户数据推断个性化配置
    static func inferFromUser(_ user: VirtualUser) -> PersonalizedProfile {
        // 基于睡眠基准推断睡眠类型
        let sleepType: SleepType
        switch user.sleepBaseline {
        case 5.0...6.5:
            sleepType = .irregular
        case 6.5...7.5:
            sleepType = .normal
        case 7.5...9.0:
            sleepType = .earlyBird
        default:
            sleepType = .nightOwl
        }
        
        // 基于步数基准推断活动水平
        let activityLevel: ActivityLevel
        switch user.stepsBaseline {
        case 0...5000:
            activityLevel = .low
        case 5001...8000:
            activityLevel = .medium
        case 8001...12000:
            activityLevel = .high
        default:
            activityLevel = .veryHigh
        }
        
        return PersonalizedProfile(sleepType: sleepType, activityLevel: activityLevel)
    }
}

// MARK: - 简化版活动模式
struct DailyActivityPattern: Codable {
    let morningActivity: ActivityIntensity      // 6-12点晨间活动
    let workdayActivity: ActivityIntensity      // 12-18点工作日活动
    let eveningActivity: ActivityIntensity      // 18-22点晚间活动
    let weekendMultiplier: Float               // 周末系数
    
    // 默认活动模式
    static func defaultPattern(for activityLevel: ActivityLevel) -> DailyActivityPattern {
        switch activityLevel {
        case .low:
            return DailyActivityPattern(
                morningActivity: .low,
                workdayActivity: .normal,
                eveningActivity: .low,
                weekendMultiplier: 0.8
            )
        case .medium:
            return DailyActivityPattern(
                morningActivity: .normal,
                workdayActivity: .normal,
                eveningActivity: .normal,
                weekendMultiplier: 1.2
            )
        case .high:
            return DailyActivityPattern(
                morningActivity: .high,
                workdayActivity: .normal,
                eveningActivity: .high,
                weekendMultiplier: 1.4
            )
        case .veryHigh:
            return DailyActivityPattern(
                morningActivity: .veryHigh,
                workdayActivity: .high,
                eveningActivity: .veryHigh,
                weekendMultiplier: 1.6
            )
        }
    }
    
    // 获取指定时间的活动强度
    func getIntensity(for hour: Int, isWeekend: Bool) -> ActivityIntensity {
        let baseIntensity: ActivityIntensity
        
        switch hour {
        case 6..<12:
            baseIntensity = morningActivity
        case 12..<18:
            baseIntensity = workdayActivity
        case 18..<22:
            baseIntensity = eveningActivity
        default:
            baseIntensity = .low  // 夜间和早晨低活动
        }
        
        // 周末调整
        if isWeekend {
            let adjustedValue = baseIntensity.rawValue * weekendMultiplier
            return ActivityIntensity(rawValue: min(adjustedValue, ActivityIntensity.veryHigh.rawValue)) ?? baseIntensity
        }
        
        return baseIntensity
    }
}

// MARK: - 活动强度
enum ActivityIntensity: Float, CaseIterable, Codable {
    case low = 0.5
    case normal = 1.0
    case high = 1.5
    case veryHigh = 2.0
    
    var displayName: String {
        switch self {
        case .low: return "低强度"
        case .normal: return "正常强度"
        case .high: return "高强度"
        case .veryHigh: return "超高强度"
        }
    }
}

// MARK: - 步数微增量数据
struct StepIncrement: Codable {
    let timestamp: Date
    let steps: Int
    let activityType: ActivityType
    
    enum ActivityType: String, Codable {
        case walking = "步行"
        case running = "跑步"
        case stairs = "爬楼梯"
        case standing = "站立"
        case idle = "静止"
    }
}

// MARK: - 预计算步数分布
struct DailyStepDistribution: Codable {
    let date: Date
    let totalSteps: Int
    let hourlyDistribution: [Int: Int]  // 小时 -> 步数
    let incrementalData: [StepIncrement] // 微增量数据
    
    // 生成一天的步数分布
    static func generate(for profile: PersonalizedProfile, date: Date, seed: UInt64) -> DailyStepDistribution {
        var generator = SeededRandomGenerator(seed: seed)
        let calendar = Calendar.current
        let isWeekend = calendar.component(.weekday, from: date) == 1 || calendar.component(.weekday, from: date) == 7
        
        // 检查是否是今天
        let now = Date()
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let currentHour = calendar.component(.hour, from: now)
        
        // 基于活动水平生成总步数
        let stepRange = profile.activityLevel.stepRange
        let baseSteps = generator.nextInt(in: stepRange.min...stepRange.max)
        let rawTotalSteps = Int(Float(baseSteps) * (isWeekend ? profile.activityPattern.weekendMultiplier : 1.0))
        
        // 🔧 关键修复：确保最小步数下限，防止极少步数bug
        let totalSteps = max(800, min(25000, rawTotalSteps))
        
        // 生成每小时分布
        var hourlyDistribution: [Int: Int] = [:]
        var activeHours = getActiveHours(pattern: profile.activityPattern, isWeekend: isWeekend)
        
        // 如果是今天，过滤掉未来的小时
        if isToday {
            activeHours = activeHours.filter { $0 <= currentHour }
        }
        
        // 使用更真实的时间段权重分配步数
        let hourlyWeights = getRealisticHourlyWeights(activeHours: activeHours, isWeekend: isWeekend)
        let totalWeight = hourlyWeights.values.reduce(0, +)
        
        for hour in activeHours {
            guard let weight = hourlyWeights[hour], totalWeight > 0 else { continue }
            
            // 基于权重分配基础步数
            let baseHourSteps = Int(Float(totalSteps) * weight / totalWeight)
            
            // 添加更大的自然波动（±40%）和偶尔的异常值
            let variation = Int(Float(baseHourSteps) * 0.4)
            var hourSteps = max(0, baseHourSteps + generator.nextInt(in: -variation...variation))
            
            // 根据时间段调整步数
            let isWorkHour = (hour >= 9 && hour <= 11) || (hour >= 14 && hour <= 16)
            
            if isWorkHour {
                // 工作时间：70%概率几乎没有步数
                if generator.nextFloat(in: 0...1) < 0.7 {
                    hourSteps = generator.nextInt(in: 0...50)  // 极少步数
                }
            } else {
                // 非工作时间：正常波动
                // 10%概率出现异常高值（比如突然的运动）
                if generator.nextFloat(in: 0...1) < 0.1 {
                    hourSteps = Int(Float(hourSteps) * generator.nextFloat(in: 1.5...2.5))
                }
                
                // 5%概率出现异常低值（比如会议、看电影等）
                if generator.nextFloat(in: 0...1) < 0.05 {
                    hourSteps = Int(Float(hourSteps) * generator.nextFloat(in: 0.1...0.3))
                }
            }
            
            hourlyDistribution[hour] = hourSteps
        }
        
        // 生成微增量数据
        let incrementalData = generateHourlyIncrements(hourlyDistribution: hourlyDistribution, date: date, generator: &generator)
        
        return DailyStepDistribution(
            date: date,
            totalSteps: totalSteps,
            hourlyDistribution: hourlyDistribution,
            incrementalData: incrementalData
        )
    }
    
    // 获取活跃小时 - 更符合真人作息
    private static func getActiveHours(pattern: DailyActivityPattern, isWeekend: Bool) -> [Int] {
        if isWeekend {
            // 周末：起床较晚，活动时间较散
            return Array(8...23) // 8点到23点
        } else {
            // 工作日：规律作息
            return Array(7...22) // 7点到22点
        }
    }
    
    // 获取更真实的时间段权重分配
    private static func getRealisticHourlyWeights(activeHours: [Int], isWeekend: Bool) -> [Int: Float] {
        var weights: [Int: Float] = [:]
        
        for hour in activeHours {
            let weight: Float
            
            if isWeekend {
                // 周末权重分配 - 更自由的时间安排
                switch hour {
                case 8...9:   weight = 0.8   // 缓慢起床
                case 10...11: weight = 1.2   // 晨间活动
                case 12...13: weight = 1.0   // 午餐时间
                case 14...16: weight = 1.5   // 下午活跃期
                case 17...18: weight = 1.3   // 傍晚散步
                case 19...20: weight = 1.1   // 晚餐活动
                case 21...22: weight = 0.7   // 晚间放松
                case 23:      weight = 0.3   // 深夜少量活动
                default:      weight = 0.5
                }
            } else {
                // 工作日权重分配 - 符合上班族作息
                switch hour {
                case 7...8:   weight = 1.8   // 早晨高峰：上班通勤
                case 9:       weight = 0.2   // 刚到公司：少量活动
                case 10...11: weight = 0.1   // 上午工作：几乎不动
                case 12...13: weight = 1.4   // 午餐时间：外出就餐
                case 14:      weight = 0.2   // 午后：回到工位
                case 15...16: weight = 0.1   // 下午工作：继续久坐
                case 17...18: weight = 1.9   // 下班高峰：通勤回家
                case 19...20: weight = 1.2   // 晚餐后活动
                case 21...22: weight = 0.8   // 晚间休闲
                default:      weight = 0.3
                }
            }
            
            weights[hour] = weight
        }
        
        return weights
    }
    
    // 生成每小时的微增量数据
    private static func generateHourlyIncrements(hourlyDistribution: [Int: Int], date: Date, generator: inout SeededRandomGenerator) -> [StepIncrement] {
        var increments: [StepIncrement] = []
        let calendar = Calendar.current
        
        // 检查是否是今天，如果是今天则限制到当前时间
        let now = Date()
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let currentHour = calendar.component(.hour, from: now)
        
        for (hour, steps) in hourlyDistribution {
            // 如果是今天，跳过未来的小时
            if isToday && hour > currentHour {
                continue
            }
            
            guard steps > 0 else { 
                // 添加睡眠时间的处理：即使是0步数的小时，也可能有极少量活动
                if isSleepHour(hour) {
                    addSleepTimeIncrements(hour: hour, date: date, generator: &generator, increments: &increments)
                }
                continue 
            }
            
            // 根据小时和步数决定增量密度
            let incrementCount = getIncrementCount(for: hour, steps: steps, generator: &generator)
            
            // 创建更不规律的步数分布
            var stepsToDistribute = steps
            var hourIncrements = [StepIncrement]()
            var usedMinutes = Set<Int>()
            
            for i in 0..<incrementCount {
                // 生成不重复的随机分钟
                var minute: Int
                repeat {
                    minute = generator.nextInt(in: 0...59)
                } while usedMinutes.contains(minute)
                usedMinutes.insert(minute)
                
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = minute
                components.second = generator.nextInt(in: 0...59) // 添加秒级随机性
                
                if let timestamp = calendar.date(from: components) {
                    // 🔥 额外时间安全检查：如果是今天且时间戳超过当前时间，跳过
                    if isToday && timestamp > now {
                        continue
                    }
                    
                    // 计算这个增量的步数，使用更大的变化范围
                    let isLastIncrement = (i == incrementCount - 1)
                    var stepAmount: Int
                    
                    if isLastIncrement {
                        // 最后一个增量获得剩余的所有步数
                        stepAmount = stepsToDistribute
                    } else {
                        // 使用更不规则的分配：20%到180%的平均值
                        let avgStepsPerIncrement = stepsToDistribute / (incrementCount - i)
                        let minSteps = max(1, Int(Float(avgStepsPerIncrement) * 0.2))
                        let maxSteps = min(stepsToDistribute - (incrementCount - i - 1), Int(Float(avgStepsPerIncrement) * 1.8))
                        stepAmount = generator.nextInt(in: minSteps...maxSteps)
                    }
                    
                    stepsToDistribute -= stepAmount
                    
                    // 更智能的活动类型判断
                    let activityType = determineActivityType(hour: hour, steps: stepAmount, generator: &generator)
                    
                    if stepAmount > 0 {
                        hourIncrements.append(StepIncrement(
                            timestamp: timestamp,
                            steps: stepAmount,
                            activityType: activityType
                        ))
                    }
                }
            }
            
            // 将本小时的增量添加到总列表
            increments.append(contentsOf: hourIncrements)
        }
        
        return increments.sorted { $0.timestamp < $1.timestamp }
    }
    
    // 判断是否为睡眠时间
    private static func isSleepHour(_ hour: Int) -> Bool {
        return hour >= 23 || hour <= 6 // 晚上11点到早上6点
    }
    
    // 添加睡眠时间的微量活动
    private static func addSleepTimeIncrements(hour: Int, date: Date, generator: inout SeededRandomGenerator, increments: inout [StepIncrement]) {
        // 95%概率无活动，5%概率有1-9步的微量活动
        let shouldHaveActivity = generator.nextDouble(in: 0...1) < 0.05
        
        if shouldHaveActivity {
            let calendar = Calendar.current
            let minute = generator.nextInt(in: 0...59)
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = 0
            
            if let timestamp = calendar.date(from: components) {
                let steps = generator.nextInt(in: 1...9) // 1-9步的微量活动
                increments.append(StepIncrement(
                    timestamp: timestamp,
                    steps: steps,
                    activityType: .idle
                ))
            }
        }
    }
    
    // 获取更真实的增量数量 - 大幅减少分散程度
    private static func getIncrementCount(for hour: Int, steps: Int, generator: inout SeededRandomGenerator) -> Int {
        // 通勤时段(7-9, 17-19)使用更多段落
        let isCommutingHour = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)
        // 运动时段
        let isExerciseHour = (hour >= 6 && hour <= 7) || (hour >= 19 && hour <= 21)
        
        // 工作时段大部分时间是静止的
        let isWorkHour = (hour >= 9 && hour <= 11) || (hour >= 14 && hour <= 16)
        
        // 基于时间段和步数的增量数量
        let baseCount: Int
        
        if isWorkHour {
            // 工作时间：极少的活动次数
            switch steps {
            case 0...50:     baseCount = 1                              // 仅一次活动（去洗手间）
            case 51...150:   baseCount = generator.nextInt(in: 1...2)   // 1-2次活动
            default:         baseCount = generator.nextInt(in: 2...3)   // 2-3次活动
            }
        } else if isCommutingHour {
            // 通勤时间：持续活动
            switch steps {
            case 0...200:    baseCount = generator.nextInt(in: 2...4)   // 2-4个增量
            case 201...500:  baseCount = generator.nextInt(in: 3...6)   // 3-6个增量
            case 501...1000: baseCount = generator.nextInt(in: 4...8)   // 4-8个增量
            default:         baseCount = generator.nextInt(in: 5...10)  // 5-10个增量
            }
        } else if isExerciseHour {
            // 运动时间：集中的高强度活动
            switch steps {
            case 0...500:    baseCount = generator.nextInt(in: 1...3)   // 1-3个增量
            case 501...1500: baseCount = generator.nextInt(in: 2...4)   // 2-4个增量
            default:         baseCount = generator.nextInt(in: 3...5)   // 3-5个增量
            }
        } else {
            // 其他时间：零散活动
            switch steps {
            case 0...50:     baseCount = 1                              // 仅一次活动
            case 51...200:   baseCount = generator.nextInt(in: 1...3)   // 1-3个增量
            case 201...500:  baseCount = generator.nextInt(in: 2...4)   // 2-4个增量
            default:         baseCount = generator.nextInt(in: 3...5)   // 3-5个增量
            }
        }
        
        return baseCount
    }
    
    // 更智能的活动类型判断
    private static func determineActivityType(hour: Int, steps: Int, generator: inout SeededRandomGenerator) -> StepIncrement.ActivityType {
        // 睡眠时间
        if isSleepHour(hour) {
            return .idle
        }
        
        // 根据步数和时间段判断活动类型
        switch steps {
        case 0...10:
            return .idle
        case 11...30:
            return .standing
        case 31...80:
            return .walking
        case 81...150:
            // 通勤高峰期(7-8点, 17-18点)更可能是快走
            if (hour >= 7 && hour <= 8) || (hour >= 17 && hour <= 18) {
                return generator.nextDouble(in: 0...1) < 0.7 ? .walking : .running
            } else {
                return .walking
            }
        default:
            // 大量步数时，根据时间段判断
            if (hour >= 7 && hour <= 8) || (hour >= 17 && hour <= 18) {
                // 通勤时间：70%跑步/快走
                return generator.nextDouble(in: 0...1) < 0.7 ? .running : .walking
            } else if hour >= 14 && hour <= 16 {
                // 下午时段：可能是运动时间
                return generator.nextDouble(in: 0...1) < 0.6 ? .running : .walking
            } else {
                // 其他时间：主要是走路
                return generator.nextDouble(in: 0...1) < 0.8 ? .walking : .running
            }
        }
    }
}

// MARK: - 虚拟用户模型
struct VirtualUser: Codable {
    let id: String
    let age: Int
    let gender: Gender
    let height: Double // cm
    let weight: Double // kg
    let sleepBaseline: Double // 小时
    let stepsBaseline: Int // 步数
    let createdAt: Date
    
    // 设备信息（固定绑定）
    let deviceModel: String       // 如 "iPhone 14 Pro"
    let deviceSerialNumber: String // 如 "F2LJH7J1"
    let deviceUUID: String        // 设备UUID
    
    // 计算BMI
    var bmi: Double {
        let heightInM = height / 100.0
        return weight / (heightInM * heightInM)
    }
    
    // BMI类别
    var bmiCategory: String {
        switch bmi {
        case ..<18.5:
            return "偏瘦"
        case 18.5..<24:
            return "正常"
        case 24..<28:
            return "偏胖"
        default:
            return "肥胖"
        }
    }
    
    // 睡眠基准值描述
    var sleepBaselineDescription: String {
        switch sleepBaseline {
        case ..<7:
            return "短睡眠型"
        case 7..<8:
            return "标准睡眠型"
        case 8..<9:
            return "长睡眠型"
        default:
            return "超长睡眠型"
        }
    }
    
    // 步数基准值描述
    var stepsBaselineDescription: String {
        switch stepsBaseline {
        case ..<5000:
            return "低活跃度"
        case 5000..<8000:
            return "中等活跃度"
        case 8000..<12000:
            return "高活跃度"
        default:
            return "极高活跃度"
        }
    }
    

}

// MARK: - 性别枚举
enum Gender: String, CaseIterable, Codable {
    case male = "男"
    case female = "女"
    case other = "其他"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - 虚拟用户生成器
class VirtualUserGenerator {
    
    // 生成单个虚拟用户
    static func generateRandomUser() -> VirtualUser {
        let userID = UUID().uuidString
        let seed = generateSeed(from: userID)
        
        // 使用种子生成一致性随机数
        var generator = SeededRandomGenerator(seed: seed)
        
        // 生成基本属性
        let age = generator.nextInt(in: 20...45)
        let gender = Gender.allCases.randomElement(using: &generator) ?? .male
        let height = generateHeight(for: gender, using: &generator)
        let weight = generateWeight(for: height, gender: gender, using: &generator)
        
        // 生成基准值
        let sleepBaseline = generator.nextDouble(in: 7.0...9.0)
        let stepsBaseline = generator.nextInt(in: 5000...15000)
        
        // 生成设备信息
        let deviceInfo = generateDeviceInfo(using: &generator)
        
        return VirtualUser(
            id: userID,
            age: age,
            gender: gender,
            height: height,
            weight: weight,
            sleepBaseline: sleepBaseline,
            stepsBaseline: stepsBaseline,
            createdAt: Date(),
            deviceModel: deviceInfo.model,
            deviceSerialNumber: deviceInfo.serialNumber,
            deviceUUID: deviceInfo.uuid
        )
    }
    
    // 批量生成虚拟用户
    static func generateMultipleUsers(count: Int) -> [VirtualUser] {
        return (0..<count).map { _ in generateRandomUser() }
    }
    
    // 生成种子（基于用户ID的哈希）
    private static func generateSeed(from userID: String) -> UInt64 {
        let hash = userID.hashValue
        return UInt64(abs(hash))
    }
    
    // 根据性别生成身高
    private static func generateHeight(for gender: Gender, using generator: inout SeededRandomGenerator) -> Double {
        switch gender {
        case .male:
            // 男性身高范围：160-185cm
            return generator.nextDouble(in: 160.0...185.0)
        case .female:
            // 女性身高范围：150-170cm
            return generator.nextDouble(in: 150.0...170.0)
        case .other:
            // 其他性别：155-180cm
            return generator.nextDouble(in: 155.0...180.0)
        }
    }
    
    // 根据身高和性别生成合理的体重
    private static func generateWeight(for height: Double, gender: Gender, using generator: inout SeededRandomGenerator) -> Double {
        // 基于BMI 18.5-28的范围计算体重
        let heightInM = height / 100.0
        let minWeight = 18.5 * heightInM * heightInM
        let maxWeight = 28.0 * heightInM * heightInM
        
        // 根据性别调整体重分布
        let weightRange = maxWeight - minWeight
        let weightOffset: Double
        
        switch gender {
        case .male:
            // 男性倾向于更高的体重
            weightOffset = generator.nextDouble(in: 0.3...1.0) * weightRange
        case .female:
            // 女性倾向于更低的体重
            weightOffset = generator.nextDouble(in: 0.0...0.7) * weightRange
        case .other:
            // 其他性别均匀分布
            weightOffset = generator.nextDouble(in: 0.0...1.0) * weightRange
        }
        
        let weight = minWeight + weightOffset
        
        // 确保体重在合理范围内
        return max(50.0, min(100.0, weight))
    }
    
    // 生成设备信息
    private static func generateDeviceInfo(using generator: inout SeededRandomGenerator) -> (model: String, serialNumber: String, uuid: String) {
        // iPhone 型号列表（2023-2024年常见型号）
        let deviceModels = [
            "iPhone 15 Pro Max",
            "iPhone 15 Pro", 
            "iPhone 15 Plus",
            "iPhone 15",
            "iPhone 14 Pro Max",
            "iPhone 14 Pro",
            "iPhone 14 Plus", 
            "iPhone 14",
            "iPhone 13 Pro Max",
            "iPhone 13 Pro",
            "iPhone 13",
            "iPhone 13 mini",
            "iPhone SE (3rd generation)"
        ]
        
        // 随机选择一个型号
        let model = deviceModels[generator.nextInt(in: 0...(deviceModels.count - 1))]
        
        // 生成序列号（格式：F2LJXXXXX）
        let serialNumber = generateSerialNumber(using: &generator)
        
        // 生成UUID
        let uuid = generateDeviceUUID(using: &generator)
        
        return (model: model, serialNumber: serialNumber, uuid: uuid)
    }
    
    // 生成设备序列号
    private static func generateSerialNumber(using generator: inout SeededRandomGenerator) -> String {
        let prefixes = ["F2L", "F4L", "G0N", "G5N", "DX3", "F17", "F93", "DN6"]
        let prefix = prefixes[generator.nextInt(in: 0...(prefixes.count - 1))]
        
        // 生成5个字母数字字符
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789"
        var suffix = ""
        for _ in 0..<5 {
            let index = generator.nextInt(in: 0...(chars.count - 1))
            suffix.append(chars[chars.index(chars.startIndex, offsetBy: index)])
        }
        
        return prefix + suffix
    }
    
    // 生成设备UUID
    private static func generateDeviceUUID(using generator: inout SeededRandomGenerator) -> String {
        // 生成标准格式的UUID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
        let segments = [8, 4, 4, 4, 12]
        var uuid = ""
        
        for (index, length) in segments.enumerated() {
            if index > 0 {
                uuid.append("-")
            }
            
            for _ in 0..<length {
                let hex = generator.nextInt(in: 0...15)
                uuid.append(String(format: "%X", hex))
            }
        }
        
        return uuid
    }
    
    // MARK: - 个性化用户生成
    
    // 生成具有指定个性化标签的用户
    static func generatePersonalizedUser(sleepType: SleepType, activityLevel: ActivityLevel) -> VirtualUser {
        let userID = UUID().uuidString
        let seed = generateSeed(from: userID)
        
        // 使用种子生成一致性随机数
        var generator = SeededRandomGenerator(seed: seed)
        
        // 生成基本属性
        let age = generator.nextInt(in: 20...45)
        let gender = Gender.allCases.randomElement(using: &generator) ?? .male
        let height = generateHeight(for: gender, using: &generator)
        let weight = generateWeight(for: height, gender: gender, using: &generator)
        
        // 基于个性化标签生成基准值
        let sleepBaseline = generatePersonalizedSleepBaseline(for: sleepType, using: &generator)
        let stepsBaseline = generatePersonalizedStepsBaseline(for: activityLevel, using: &generator)
        
        // 生成设备信息
        let deviceInfo = generateDeviceInfo(using: &generator)
        
        let user = VirtualUser(
            id: userID,
            age: age,
            gender: gender,
            height: height,
            weight: weight,
            sleepBaseline: sleepBaseline,
            stepsBaseline: stepsBaseline,
            createdAt: Date(),
            deviceModel: deviceInfo.model,
            deviceSerialNumber: deviceInfo.serialNumber,
            deviceUUID: deviceInfo.uuid
        )
        
        // 设置个性化配置
        let profile = PersonalizedProfile(sleepType: sleepType, activityLevel: activityLevel)
        VirtualUser.setPersonalizedProfile(for: userID, profile: profile)
        
        return user
    }
    
    // 生成随机个性化用户
    static func generateRandomPersonalizedUser() -> VirtualUser {
        let sleepType = SleepType.allCases.randomElement() ?? .normal
        let activityLevel = ActivityLevel.allCases.randomElement() ?? .medium
        return generatePersonalizedUser(sleepType: sleepType, activityLevel: activityLevel)
    }
    
    // 基于睡眠类型生成睡眠基准值
    private static func generatePersonalizedSleepBaseline(for sleepType: SleepType, using generator: inout SeededRandomGenerator) -> Double {
        let range = sleepType.durationRange
        return Double(generator.nextFloat(in: Float(range.min)...Float(range.max)))
    }
    
    // 基于活动水平生成步数基准值
    private static func generatePersonalizedStepsBaseline(for activityLevel: ActivityLevel, using generator: inout SeededRandomGenerator) -> Int {
        let range = activityLevel.stepRange
        return generator.nextInt(in: range.min...range.max)
    }
    

}

// MARK: - 种子随机数生成器
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // 使用线性同余生成器算法
        state = state &* 1664525 &+ 1013904223
        return state
    }
    
    // 生成指定范围内的整数
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let random = next()
        let rangeSize = UInt64(range.upperBound - range.lowerBound + 1)
        let result = Int(random % rangeSize) + range.lowerBound
        return result
    }
    
    // 生成指定范围内的浮点数
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let random = next()
        let normalized = Double(random) / Double(UInt64.max)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
    
    // 生成指定范围内的Float
    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        let random = next()
        let normalized = Float(random) / Float(UInt64.max)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
    
    // 生成0.0到1.0之间的Float
    mutating func nextFloat() -> Float {
        let random = next()
        return Float(random) / Float(UInt64.max)
    }
}

// MARK: - 用户统计信息
struct UserStatistics {
    let totalUsers: Int
    let averageAge: Double
    let genderDistribution: [Gender: Int]
    let averageHeight: Double
    let averageWeight: Double
    let averageBMI: Double
    let averageSleepBaseline: Double
    let averageStepsBaseline: Double
    
    init(users: [VirtualUser]) {
        self.totalUsers = users.count
        
        if users.isEmpty {
            self.averageAge = 0
            self.genderDistribution = [:]
            self.averageHeight = 0
            self.averageWeight = 0
            self.averageBMI = 0
            self.averageSleepBaseline = 0
            self.averageStepsBaseline = 0
        } else {
            self.averageAge = users.map { Double($0.age) }.reduce(0, +) / Double(users.count)
            
            var genderCount: [Gender: Int] = [:]
            for user in users {
                genderCount[user.gender, default: 0] += 1
            }
            self.genderDistribution = genderCount
            
            self.averageHeight = users.map { $0.height }.reduce(0, +) / Double(users.count)
            self.averageWeight = users.map { $0.weight }.reduce(0, +) / Double(users.count)
            self.averageBMI = users.map { $0.bmi }.reduce(0, +) / Double(users.count)
            self.averageSleepBaseline = users.map { $0.sleepBaseline }.reduce(0, +) / Double(users.count)
            self.averageStepsBaseline = users.map { Double($0.stepsBaseline) }.reduce(0, +) / Double(users.count)
        }
    }
}

// MARK: - 扩展：格式化显示和验证
extension VirtualUser {
    // 格式化显示
    var formattedHeight: String {
        return String(format: "%.1f cm", height)
    }
    
    var formattedWeight: String {
        return String(format: "%.1f kg", weight)
    }
    
    var formattedBMI: String {
        return String(format: "%.1f", bmi)
    }
    
    var formattedSleepBaseline: String {
        return String(format: "%.1f 小时", sleepBaseline)
    }
    
    var formattedStepsBaseline: String {
        return String(format: "%d 步", stepsBaseline)
    }
    
    // 用户详细信息
    var detailedDescription: String {
        return """
        用户ID: \(id.prefix(8))
        年龄: \(age)岁
        性别: \(gender.displayName)
        身高: \(formattedHeight)
        体重: \(formattedWeight)
        BMI: \(formattedBMI) (\(bmiCategory))
        睡眠基准: \(formattedSleepBaseline) (\(sleepBaselineDescription))
        步数基准: \(formattedStepsBaseline) (\(stepsBaselineDescription))
        创建时间: \(DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short))
        """
    }
    
    // 验证用户数据的有效性
    var isValid: Bool {
        return age >= 20 && age <= 45 &&
               height >= 150.0 && height <= 185.0 &&
               weight >= 50.0 && weight <= 100.0 &&
               sleepBaseline >= 7.0 && sleepBaseline <= 9.0 &&
               stepsBaseline >= 5000 && stepsBaseline <= 15000
    }
    
    // 获取验证错误信息
    var validationErrors: [String] {
        var errors: [String] = []
        
        if age < 20 || age > 45 {
            errors.append("年龄应在20-45岁之间")
        }
        
        if height < 150.0 || height > 185.0 {
            errors.append("身高应在150.0-185.0厘米之间")
        }
        
        if weight < 50.0 || weight > 100.0 {
            errors.append("体重应在50.0-100.0公斤之间")
        }
        
        if sleepBaseline < 7.0 || sleepBaseline > 9.0 {
            errors.append("睡眠基准值应在7.0-9.0小时之间")
        }
        
        if stepsBaseline < 5000 || stepsBaseline > 15000 {
            errors.append("步数基准值应在5000-15000步之间")
        }
        
        return errors
    }
    
}

// MARK: - VirtualUser 个性化扩展
extension VirtualUser {
    
    // 个性化配置存储
    private static var personalizedProfiles: [String: PersonalizedProfile] = [:]
    
    // 获取个性化配置
    var personalizedProfile: PersonalizedProfile {
        get {
            if let existing = VirtualUser.personalizedProfiles[id] {
                return existing
            } else {
                // 从现有属性推断配置
                let inferred = PersonalizedProfile.inferFromUser(self)
                VirtualUser.personalizedProfiles[id] = inferred
                return inferred
            }
        }
        set {
            VirtualUser.personalizedProfiles[id] = newValue
        }
    }
    
    // 检查是否有个性化配置
    var hasPersonalizedProfile: Bool {
        return VirtualUser.personalizedProfiles[id] != nil
    }
    
    // 个性化描述
    var personalizedDescription: String {
        let profile = personalizedProfile
        return "\(profile.sleepType.displayName) · \(profile.activityLevel.displayName)"
    }
    
    // 设置个性化配置
    static func setPersonalizedProfile(for userID: String, profile: PersonalizedProfile) {
        personalizedProfiles[userID] = profile
    }
    
    // 清除个性化配置（用于测试）
    static func clearAllPersonalizedProfiles() {
        personalizedProfiles.removeAll()
    }
    
    // 保存个性化配置
    static func savePersonalizedProfiles() {
        do {
            let data = try JSONEncoder().encode(personalizedProfiles)
            UserDefaults.standard.set(data, forKey: "PersonalizedProfiles")
            print("✅ 个性化配置保存成功")
        } catch {
            print("❌ 个性化配置保存失败: \(error.localizedDescription)")
        }
    }
    
    // 加载个性化配置
    static func loadPersonalizedProfiles() {
        guard let data = UserDefaults.standard.data(forKey: "PersonalizedProfiles") else {
            // 未找到已保存的个性化配置
            return
        }
        
        do {
            let profiles = try JSONDecoder().decode([String: PersonalizedProfile].self, from: data)
            personalizedProfiles = profiles
            // 个性化配置加载成功
        } catch {
            // 个性化配置加载失败，重置
            personalizedProfiles = [:] // 重置为空字典
        }
    }
} 