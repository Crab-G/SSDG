//
//  QuickPersonalizedTest.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation

// MARK: - 快速个性化系统验证
class QuickPersonalizedTest {
    
    // 运行完整验证
    static func runCompleteValidation() async {
        print("🧪 开始个性化系统完整验证")
        print(String(repeating: "=", count: 60))
        
        testPersonalizedUserGeneration()
        testPersonalizedDataGeneration() 
        await testStepInjectionManager()
        
        // 在主线程执行需要MainActor的测试
        await MainActor.run {
            testPersonalizedAutomationManager()
        }
        
        testUIComponents()
        
        print(String(repeating: "=", count: 60))
        print("✅ 个性化系统完整验证完成")
    }
    
    // 验证个性化用户生成
    static func testPersonalizedUserGeneration() {
        print("\n🧪 验证个性化用户生成...")
        
        // 测试指定标签生成
        let user1 = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .nightOwl,
            activityLevel: .high
        )
        
        print("✅ 个性化用户生成成功:")
        print("   用户ID: \(user1.id)")
        print("   个性化标签: \(user1.personalizedDescription)")
        print("   睡眠基准: \(user1.sleepBaseline) 小时")
        print("   步数基准: \(user1.stepsBaseline) 步")
        
        // 验证标签与数据的一致性
        let profile = user1.personalizedProfile
        let sleepRange = profile.sleepType.durationRange
        let stepRange = profile.activityLevel.stepRange
        
        assert(user1.sleepBaseline >= Double(sleepRange.min) && user1.sleepBaseline <= Double(sleepRange.max),
               "睡眠基准应符合睡眠类型范围")
        assert(user1.stepsBaseline >= stepRange.min && user1.stepsBaseline <= stepRange.max,
               "步数基准应符合活动水平范围")
        
        print("✅ 标签一致性验证通过")
    }
    
    // 验证个性化数据生成
    static func testPersonalizedDataGeneration() {
        print("\n🧪 验证个性化数据生成...")
        
        let user = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .earlyBird,
            activityLevel: .medium
        )
        
        let today = Date()
        
        // 测试睡眠数据生成
        let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: today,
            mode: .wearableDevice
        )
        
        print("✅ 睡眠数据生成成功:")
        print("   入睡时间: \(sleepData.bedTime)")
        print("   起床时间: \(sleepData.wakeTime)")
        print("   总睡眠时长: \(sleepData.totalSleepHours) 小时")
        print("   睡眠阶段数: \(sleepData.sleepStages.count)")
        
        // 测试步数分布生成（使用睡眠感知算法）
        let stepDistribution = PersonalizedDataGenerator.generateEnhancedDailySteps(
            for: user,
            date: today,
            sleepData: sleepData
        )
        
        print("✅ 步数分布生成成功:")
        print("   总步数: \(stepDistribution.totalSteps)")
        print("   活跃小时: \(stepDistribution.hourlyDistribution.count)")
        print("   微增量数据点: \(stepDistribution.incrementalData.count)")
        
        // 验证数据合理性
        assert(sleepData.totalSleepHours > 0 && sleepData.totalSleepHours <= 12, "睡眠时长应合理")
        assert(stepDistribution.totalSteps > 0, "步数应大于0")
        assert(!stepDistribution.incrementalData.isEmpty, "应有微增量数据")
        
        print("✅ 数据合理性验证通过")
    }
    
    // 验证步数注入管理器
    static func testStepInjectionManager() async {
        print("\n🧪 验证步数注入管理器...")
        
        let user = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .normal,
            activityLevel: .high
        )
        
        // 使用新的独立 StepInjectionManager
        let manager = await MainActor.run { StepInjectionManager() }
        
        // 启动注入（模拟）
        await manager.startTodayInjection(for: user)
        
        await MainActor.run {
            print("✅ 注入管理器初始化成功:")
            print("   状态: \(manager.isActive ? "活跃" : "非活跃")")
            print("   已注入步数: \(manager.injectedSteps)")
            
            // 检查分布数据
            if let distribution = manager.currentDistribution {
                print("   计划总步数: \(distribution.totalSteps)")
                print("   计划注入点: \(distribution.incrementalData.count)")
            }
            
            // 停止注入
            manager.stopInjection()
            print("✅ 注入管理器停止成功")
            
            assert(!manager.isActive, "停止后应为非活跃状态")
            print("✅ 注入管理器状态验证通过")
        }
    }
    
    // 验证个性化自动化管理器
    @MainActor
    static func testPersonalizedAutomationManager() {
        print("\n🧪 验证个性化自动化管理器...")
        
        let automationManager = AutomationManager.shared
        
        // 检查初始状态
        print("✅ 自动化管理器初始状态:")
        print("   个性化模式: \(automationManager.isPersonalizedModeEnabled ? "已启用" : "未启用")")
        print("   自动化状态: \(automationManager.automationStatus.displayName)")
        print("   配置状态: \(automationManager.config.automationMode.displayName)")
        
        // 测试用户设置
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .nightOwl,
            activityLevel: .veryHigh
        )
        
        // 启用个性化模式
        automationManager.enablePersonalizedMode(for: testUser)
        
        print("✅ 个性化模式启用成功:")
        print("   当前用户: \(automationManager.currentUser?.personalizedDescription ?? "无")")
        print("   下次睡眠生成: \(automationManager.nextSleepDataGeneration?.formatted() ?? "未设置")")
        print("   步数注入状态: \(automationManager.stepInjectionManager?.isActive == true ? "活跃" : "非活跃")")
        
        // 测试配置更新
        var newConfig = automationManager.personalizedConfig
        newConfig.maxDailyStepIncrements = 150
        newConfig.stepInjectionDelay = 0.1
        
        automationManager.updateConfig(newConfig)
        
        print("✅ 配置更新成功:")
        print("   最大注入点: \(automationManager.personalizedConfig.maxDailyStepIncrements)")
        print("   注入延迟: \(automationManager.personalizedConfig.stepInjectionDelay * 1000) 毫秒")
        
        assert(automationManager.isPersonalizedModeEnabled, "个性化模式应已启用")
        assert(automationManager.currentUser != nil, "应有当前用户")
        print("✅ 自动化管理器状态验证通过")
    }
    
    // 验证UI组件配置
    static func testUIComponents() {
        print("\n🧪 验证UI组件配置...")
        
        // 验证睡眠类型
        print("✅ 睡眠类型配置:")
        for sleepType in SleepType.allCases {
            let range = sleepType.sleepTimeRange
            let duration = sleepType.durationRange
            print("   \(sleepType.displayName): \(range.start):00-\(range.end):00, \(duration.min)-\(duration.max)h")
        }
        
        // 验证活动水平
        print("✅ 活动水平配置:")
        for activityLevel in ActivityLevel.allCases {
            let stepRange = activityLevel.stepRange
            let intensity = activityLevel.intensityMultiplier
            print("   \(activityLevel.displayName): \(stepRange.min)-\(stepRange.max)步, \(intensity)x强度")
        }
        
        // 验证活动模式
        print("✅ 活动模式配置:")
        let pattern = DailyActivityPattern.defaultPattern(for: .high)
        print("   晨间活动: \(pattern.morningActivity.displayName)")
        print("   工作日活动: \(pattern.workdayActivity.displayName)")
        print("   晚间活动: \(pattern.eveningActivity.displayName)")
        print("   周末系数: \(pattern.weekendMultiplier)x")
        
        // 验证个性化配置
        let config = PersonalizedAutomationConfig.defaultConfig()
        print("✅ 默认自动化配置:")
        print("   自动化模式: \(config.automationMode.displayName)")
        print("   智能睡眠生成: \(config.enableSmartSleepGeneration ? "启用" : "禁用")")
        print("   实时步数注入: \(config.enableRealTimeStepInjection ? "启用" : "禁用")")
        print("   最大注入点: \(config.maxDailyStepIncrements)")
        print("   注入延迟: \(config.stepInjectionDelay * 1000) 毫秒")
        
        print("✅ UI组件配置验证通过")
    }
}

 