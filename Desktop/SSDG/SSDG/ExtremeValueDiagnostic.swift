//
//  ExtremeValueDiagnostic.swift
//  SSDG - 极值问题诊断工具
//
//  专门诊断为什么会产生3-50步这样的极少步数
//

import Foundation

class ExtremeValueDiagnostic {
    
    /// 全面诊断极少步数问题的根本原因
    static func diagnoseExtremelyLowStepsBug() {
        print("🔬 极少步数问题根因诊断")
        print("==========================")
        
        // 1. 测试个性化配置推断是否生成极端配置
        diagnosePersonalizedProfileInference()
        
        // 2. 测试睡眠质量因子的极端值
        diagnoseSleepQualityFactors()
        
        // 3. 测试种子生成和随机数算法
        diagnoseSeededRandomGeneration()
        
        // 4. 测试数据生成路径
        diagnoseDataGenerationPaths()
        
        // 5. 查找绕过保护机制的代码路径
        findBypassingCodePaths()
        
        print("\n🎯 诊断总结：")
        provideDiagnosisSummary()
    }
    
    /// 诊断个性化配置推断逻辑
    private static func diagnosePersonalizedProfileInference() {
        print("\n1️⃣ 个性化配置推断诊断")
        print("======================")
        
        // 测试极端baseline值是否会产生极端配置
        let extremeTestCases = [
            (sleepBaseline: 2.0, stepsBaseline: 500),   // 极少睡眠 + 极少步数
            (sleepBaseline: 15.0, stepsBaseline: 100),  // 极多睡眠 + 极少步数  
            (sleepBaseline: 3.0, stepsBaseline: 50),    // 严重失眠 + 病态步数
        ]
        
        for (index, testCase) in extremeTestCases.enumerated() {
            print("\n测试案例 \(index + 1): 睡眠\(testCase.sleepBaseline)h, 步数\(testCase.stepsBaseline)")
            
            // 创建极端用户
            let user = VirtualUser(
                id: "extreme_test_\(index)",
                age: 30,
                gender: .male,
                height: 175,
                weight: 70,
                sleepBaseline: testCase.sleepBaseline,
                stepsBaseline: testCase.stepsBaseline,
                createdAt: Date()
            )
            
            let profile = PersonalizedProfile.inferFromUser(user)
            print("   推断结果: \(profile.sleepType.displayName) + \(profile.activityLevel.displayName)")
            print("   步数范围: \(profile.activityLevel.stepRange)")
            print("   周末系数: \(profile.activityPattern.weekendMultiplier)")
            
            // 测试数据生成
            let testDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let distribution = PersonalizedDataGenerator.generatePersonalizedDailySteps(for: user, date: testDate)
            
            print("   生成结果: \(distribution.totalSteps)步")
            
            if distribution.totalSteps < 100 {
                print("   ❌ 发现极少步数！这个配置有问题")
                analyzeExtremeCase(user: user, distribution: distribution)
            } else {
                print("   ✅ 此配置正常")
            }
        }
    }
    
    /// 诊断睡眠质量因子的极端值  
    private static func diagnoseSleepQualityFactors() {
        print("\n2️⃣ 睡眠质量因子诊断")
        print("==================")
        
        let extremeSleepScenarios = [
            (duration: 1.5, description: "严重失眠（1.5小时）"),
            (duration: 2.5, description: "极少睡眠（2.5小时）"),
            (duration: 15.0, description: "过度睡眠（15小时）"),
            (duration: 20.0, description: "病态睡眠（20小时）")
        ]
        
        for scenario in extremeSleepScenarios {
            print("\n场景: \(scenario.description)")
            
            // 创建极端睡眠数据
            let now = Date()
            let bedTime = Calendar.current.date(byAdding: .hour, value: -Int(scenario.duration + 1), to: now)!
            let wakeTime = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
            
            // 创建分段很多的睡眠（模拟质量很差）
            var stages: [SleepStage] = []
            let segmentDuration = scenario.duration * 3600 / 10.0 // 分10段
            
            for i in 0..<10 {
                let startTime = bedTime.addingTimeInterval(Double(i) * segmentDuration)
                let endTime = bedTime.addingTimeInterval(Double(i + 1) * segmentDuration)
                let stageType: SleepStageType = i % 2 == 0 ? .light : .awake // 交替浅睡和清醒
                
                stages.append(SleepStage(stage: stageType, startTime: startTime, endTime: endTime))
            }
            
            let sleepData = SleepData(
                date: Calendar.current.date(byAdding: .day, value: -1, to: now)!,
                bedTime: bedTime,
                wakeTime: wakeTime,
                sleepStages: stages
            )
            
            // 计算质量因子
            let qualityFactor = calculateTestSleepQualityImpact(sleepData: sleepData)
            print("   睡眠质量因子: \(String(format: "%.3f", qualityFactor))")
            
            // 模拟对5000步基线的影响
            let baseSteps = 5000
            let adjustedSteps = Int(Double(baseSteps) * qualityFactor)
            print("   步数影响: \(baseSteps) -> \(adjustedSteps)步")
            
            if adjustedSteps < 100 {
                print("   ❌ 这个睡眠质量因子会产生极少步数！")
            }
        }
    }
    
    /// 诊断种子生成和随机数算法
    private static func diagnoseSeededRandomGeneration() {
        print("\n3️⃣ 种子生成和随机数诊断")
        print("========================")
        
        // 测试不同种子是否会产生极端随机值
        let testSeeds: [UInt64] = [0, 1, 42, 12345, UInt64.max, UInt64.max/2]
        
        for seed in testSeeds {
            print("\n种子: \(seed)")
            var generator = SeededRandomGenerator(seed: seed)
            
            // 测试步数范围生成
            let lowActivityRange = 1500...4500
            let baseSteps = generator.nextInt(in: lowActivityRange)
            print("   基础步数: \(baseSteps)")
            
            // 测试周末系数
            let weekendMultipliers: [Float] = [0.8, 1.2, 1.4, 1.6]
            for multiplier in weekendMultipliers {
                let result = Int(Float(baseSteps) * multiplier)
                let protected = max(800, min(25000, result))
                print("   系数\(multiplier): \(baseSteps) * \(multiplier) = \(result) -> \(protected)步")
            }
            
            // 测试多次生成是否有异常
            var minGenerated = Int.max
            for _ in 0..<100 {
                let steps = generator.nextInt(in: lowActivityRange)
                minGenerated = min(minGenerated, steps)
            }
            print("   100次生成最小值: \(minGenerated)")
        }
    }
    
    /// 诊断数据生成路径
    private static func diagnoseDataGenerationPaths() {
        print("\n4️⃣ 数据生成路径诊断")
        print("==================")
        
        print("检查所有可能的步数生成入口点：")
        print("1. PersonalizedDataGenerator.generatePersonalizedDailySteps() - 原始方法")
        print("2. PersonalizedDataGenerator.generateEnhancedDailySteps() - 睡眠感知方法")
        print("3. DataGenerator.generateStepsData() - 旧版方法")
        print("4. DailyStepDistribution.generate() - 核心生成逻辑")
        
        // 创建测试用户
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .irregular,
            activityLevel: .low
        )
        
        let testDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        // 路径1: 原始方法
        print("\n路径1测试 - 原始方法:")
        let originalResult = PersonalizedDataGenerator.generatePersonalizedDailySteps(for: testUser, date: testDate)
        print("   结果: \(originalResult.totalSteps)步")
        
        // 路径2: 睡眠感知方法
        print("\n路径2测试 - 睡眠感知方法:")
        let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(for: testUser, date: testDate, mode: .simple)
        let enhancedResult = PersonalizedDataGenerator.generateEnhancedDailySteps(for: testUser, date: testDate, sleepData: sleepData)
        print("   结果: \(enhancedResult.totalSteps)步")
        
        // 路径3: 旧版方法（如果还在使用）
        print("\n路径3测试 - 旧版DataGenerator:")
        var generator = SeededRandomGenerator(seed: UInt64(abs(testUser.id.hashValue)))
        let oldResult = DataGenerator.generateStepsData(date: testDate, baseline: testUser.stepsBaseline, sleepData: sleepData, mode: .simple, generator: &generator)
        print("   结果: \(oldResult.totalSteps)步")
    }
    
    /// 查找绕过保护机制的代码路径
    private static func findBypassingCodePaths() {
        print("\n5️⃣ 绕过保护机制的路径查找")
        print("========================")
        
        print("已知保护机制：")
        print("- VirtualUser.swift:267: max(800, min(25000, rawTotalSteps))")
        print("- PersonalizedDataGenerator.swift:602: max(800, baseDailySteps)")
        print("- HealthKitComplianceEnhancer.swift:47: max(800, originalTotalSteps)")
        
        print("\n可能的绕过路径：")
        print("1. 直接使用DataGenerator.generateStepsData()而不是PersonalizedDataGenerator")
        print("2. 睡眠质量因子多次叠加应用")
        print("3. 小时步数分配后重新计算总数时出现错误")
        print("4. 实时注入系统中的增量数据异常")
        print("5. HealthKit写入时的数据转换错误") 
    }
    
    /// 分析极端案例的详细信息
    private static func analyzeExtremeCase(user: VirtualUser, distribution: DailyStepDistribution) {
        print("\n🔍 极端案例详细分析:")
        print("   用户ID: \(user.id)")
        print("   睡眠基线: \(user.sleepBaseline)小时")
        print("   步数基线: \(user.stepsBaseline)步")
        
        let profile = PersonalizedProfile.inferFromUser(user)
        print("   活动等级: \(profile.activityLevel.displayName)")
        print("   步数范围: \(profile.activityLevel.stepRange)")
        print("   周末系数: \(profile.activityPattern.weekendMultiplier)")
        
        print("   生成步数: \(distribution.totalSteps)步")  
        print("   小时分布: \(distribution.hourlyDistribution)")
        print("   增量数据: \(distribution.incrementalData.count)个")
    }
    
    /// 提供诊断总结
    private static func provideDiagnosisSummary() {
        print("基于诊断结果，极少步数问题可能的根因：")
        print("1. 睡眠质量因子可以低至0.3，对步数影响巨大")
        print("2. 个性化配置推断可能产生极端活动等级")
        print("3. 多个调整因子叠加造成复合影响")
        print("4. 某些代码路径可能绕过了保护机制")
        print("5. 数据转换过程中的精度丢失")
        
        print("\n建议的修复策略：")
        print("- 限制睡眠质量因子的最小值（如0.6而不是0.3）")
        print("- 在所有关键节点添加最小值保护")  
        print("- 审计所有步数生成和修改的代码路径")
        print("- 增加运行时数据验证和异常检测")
    }
    
    /// 模拟DataGenerator中的睡眠质量影响计算（用于测试）
    private static func calculateTestSleepQualityImpact(sleepData: SleepData) -> Double {
        let sleepHours = sleepData.duration
        
        var impactFactor: Double = 1.0
        
        if sleepHours < 5.0 {
            impactFactor = 0.5 + (sleepHours / 5.0) * 0.3
        } else if sleepHours < 6.5 {
            impactFactor = 0.8 + ((sleepHours - 5.0) / 1.5) * 0.15
        } else if sleepHours <= 8.5 {
            impactFactor = 0.95 + ((sleepHours - 6.5) / 2.0) * 0.15
        } else if sleepHours <= 10.0 {
            impactFactor = 1.1 - ((sleepHours - 8.5) / 1.5) * 0.2
        } else {
            impactFactor = 0.9 - ((sleepHours - 10.0) / 2.0) * 0.3
        }
        
        // 睡眠分段影响
        let segmentCount = sleepData.sleepStages.count
        if segmentCount > 8 {
            impactFactor *= 0.85
        } else if segmentCount > 6 {
            impactFactor *= 0.95
        }
        
        // 起床时间影响
        let calendar = Calendar.current
        let wakeHour = calendar.component(.hour, from: sleepData.wakeTime)
        
        if wakeHour <= 6 {
            impactFactor *= 1.1
        } else if wakeHour >= 10 {
            impactFactor *= 0.9
        } else if wakeHour >= 11 {
            impactFactor *= 0.8
        }
        
        return max(0.3, min(2.0, impactFactor))
    }
}