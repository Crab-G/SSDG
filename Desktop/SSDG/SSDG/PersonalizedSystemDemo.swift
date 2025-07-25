//
//  PersonalizedSystemDemo.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation

// MARK: - 个性化系统演示
class PersonalizedSystemDemo {
    
    // 运行完整演示
    static func runDemo() {
        print("🎯 个性化系统演示开始")
        print(String(repeating: "=", count: 50))
        
        demonstratePersonalizedUserGeneration()
        demonstratePersonalizedDataGeneration()
        demonstrateStepInjectionSystem()
        demonstrateUserProfileInference()
        
        print(String(repeating: "=", count: 50))
        print("✅ 个性化系统演示完成")
    }
    
    // 演示个性化用户生成
    static func demonstratePersonalizedUserGeneration() {
        print("\n📋 个性化用户生成演示")
        print(String(repeating: "-", count: 30))
        
        // 生成不同类型的个性化用户
        let users = [
            ("夜猫子 + 高活动量", VirtualUserGenerator.generatePersonalizedUser(sleepType: .nightOwl, activityLevel: .high)),
            ("早起者 + 低活动量", VirtualUserGenerator.generatePersonalizedUser(sleepType: .earlyBird, activityLevel: .low)),
            ("正常型 + 中等活动量", VirtualUserGenerator.generatePersonalizedUser(sleepType: .normal, activityLevel: .medium)),
            ("紊乱型 + 超高活动量", VirtualUserGenerator.generatePersonalizedUser(sleepType: .irregular, activityLevel: .veryHigh))
        ]
        
        for (description, user) in users {
            print("\n👤 \(description)")
            print("   基本信息: \(user.gender.displayName), \(user.age)岁")
            print("   身高体重: \(user.formattedHeight), \(user.formattedWeight)")
            print("   睡眠基准: \(String(format: "%.1f", user.sleepBaseline)) 小时")
            print("   步数基准: \(user.stepsBaseline) 步")
            print("   个性化标签: \(user.personalizedDescription)")
        }
    }
    
    // 演示个性化数据生成
    static func demonstratePersonalizedDataGeneration() {
        print("\n📊 个性化数据生成演示")
        print(String(repeating: "-", count: 30))
        
        let user = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .nightOwl,
            activityLevel: .high
        )
        
        print("\n🌙 睡眠数据生成 (\(user.personalizedProfile.sleepType.displayName))")
        
        let calendar = Calendar.current
        let today = Date()
        
        // 生成最近3天的睡眠数据
        for i in 0..<3 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
                for: user,
                date: date,
                mode: .simple
            )
            
            let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
            let bedtimeString = DateFormatter.localizedString(from: sleepData.bedTime, dateStyle: .none, timeStyle: .short)
            let waketimeString = DateFormatter.localizedString(from: sleepData.wakeTime, dateStyle: .none, timeStyle: .short)
            
            print("   \(dateString): \(bedtimeString) → \(waketimeString) (\(String(format: "%.1f", sleepData.totalSleepHours))h)")
        }
        
        print("\n🚶‍♂️ 步数分布生成 (\(user.personalizedProfile.activityLevel.displayName))")
        
        let distribution = PersonalizedDataGenerator.generatePersonalizedDailySteps(for: user, date: today)
        
        print("   总步数: \(distribution.totalSteps)")
        print("   活跃时段: \(distribution.hourlyDistribution.keys.sorted())")
        print("   微增量数据点: \(distribution.incrementalData.count)个")
        
        // 显示活跃时段的步数分布
        let activeHours = distribution.hourlyDistribution.sorted { $0.key < $1.key }
        print("   小时分布:")
        for (hour, steps) in activeHours {
            let bar = String(repeating: "█", count: min(steps / 200, 20))
            print("     \(String(format: "%02d", hour)):00 |\(bar) \(steps)")
        }
    }
    
    // 演示步数注入系统
    static func demonstrateStepInjectionSystem() {
        print("\n💉 步数注入系统演示")
        print(String(repeating: "-", count: 30))
        
        let user = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .normal,
            activityLevel: .medium
        )
        
        let distribution = PersonalizedDataGenerator.generatePersonalizedDailySteps(for: user, date: Date())
        
        print("准备注入的微增量数据:")
        print("   计划总步数: \(distribution.totalSteps)")
        print("   注入点数量: \(distribution.incrementalData.count)")
        
        // 显示前10个注入点
        let sortedIncrements = distribution.incrementalData.sorted { $0.timestamp < $1.timestamp }
        print("   前10个注入点:")
        
        for increment in sortedIncrements.prefix(10) {
            let timeString = DateFormatter.localizedString(from: increment.timestamp, dateStyle: .none, timeStyle: .medium)
            print("     \(timeString): +\(increment.steps)步 (\(increment.activityType.rawValue))")
        }
        
        // 模拟注入过程（仅显示概念）
        print("\n🎯 注入过程模拟:")
        let now = Date()
        var totalInjected = 0
        
        for increment in sortedIncrements.prefix(5) {
            let delay = increment.timestamp.timeIntervalSince(now)
            if delay <= 0 {
                totalInjected += increment.steps
                print("     ✅ 立即注入: +\(increment.steps)步 (累计: \(totalInjected))")
            } else {
                print("     ⏰ 计划注入: +\(increment.steps)步 (延迟: \(Int(delay))秒)")
            }
        }
    }
    
    // 演示用户配置推断
    static func demonstrateUserProfileInference() {
        print("\n🔍 用户配置推断演示")
        print(String(repeating: "-", count: 30))
        
        // 生成一些普通用户，展示推断过程
        let testUsers = (1...5).map { _ in VirtualUserGenerator.generateRandomUser() }
        
        print("从普通用户属性推断个性化标签:")
        
        for (index, user) in testUsers.enumerated() {
            let profile = user.personalizedProfile
            
            print("\n👤 用户 \(index + 1):")
            print("   原始属性: 睡眠\(String(format: "%.1f", user.sleepBaseline))h, 步数\(user.stepsBaseline)")
            print("   推断标签: \(profile.sleepType.displayName) + \(profile.activityLevel.displayName)")
            print("   个性化描述: \(user.personalizedDescription)")
            
            // 显示推断逻辑
            let sleepReasoning = getSleepTypeReasoning(baseline: user.sleepBaseline)
            let activityReasoning = getActivityLevelReasoning(baseline: user.stepsBaseline)
            
            print("   推断依据:")
            print("     睡眠: \(sleepReasoning)")
            print("     活动: \(activityReasoning)")
        }
        
        // 测试配置持久化
        print("\n💾 配置持久化测试:")
        
        let originalCount = testUsers.count
        VirtualUser.savePersonalizedProfiles()
        print("   已保存 \(originalCount) 个用户的配置")
        
        VirtualUser.clearAllPersonalizedProfiles()
        print("   已清除内存中的配置")
        
        VirtualUser.loadPersonalizedProfiles()
        print("   已从存储恢复配置")
        
        // 验证配置是否正确恢复
        let restoredUser = testUsers.first!
        let restoredProfile = restoredUser.personalizedProfile
        print("   验证用户1配置: \(restoredProfile.sleepType.displayName) + \(restoredProfile.activityLevel.displayName)")
    }
    
    // 辅助函数：获取睡眠类型推断依据
    private static func getSleepTypeReasoning(baseline: Double) -> String {
        if baseline >= 8.5 {
            return "睡眠时长≥8.5h → 夜猫型"
        } else if baseline <= 6.5 {
            return "睡眠时长≤6.5h → 早起型"
        } else {
            return "睡眠时长正常 → 正常型"
        }
    }
    
    // 辅助函数：获取活动水平推断依据
    private static func getActivityLevelReasoning(baseline: Int) -> String {
        if baseline >= 15000 {
            return "步数≥15000 → 超高活动量"
        } else if baseline >= 10000 {
            return "步数≥10000 → 高活动量"
        } else if baseline >= 5000 {
            return "步数≥5000 → 中等活动量"
        } else {
            return "步数<5000 → 低活动量"
        }
    }
}

 