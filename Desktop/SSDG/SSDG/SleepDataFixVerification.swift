//
//  SleepDataFixVerification.swift
//  SSDG - 睡眠数据修复验证脚本
//
//  验证时间边界修复是否生效
//

import Foundation

class SleepDataFixVerification {
    
    static func runVerificationTests() {
        print("🔍 开始睡眠数据修复验证测试...")
        
        // 创建测试用户
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal,
            activityLevel: ActivityLevel.medium
        )
        
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        print("\n📅 测试日期:")
        print("   今天: \(DateFormatter.localizedString(from: today, dateStyle: .short, timeStyle: .short))")
        print("   昨天: \(DateFormatter.localizedString(from: yesterday, dateStyle: .short, timeStyle: .short))")
        
        // 测试1: 验证昨天的睡眠数据生成（应该正常工作）
        print("\n🧪 测试1: 昨天睡眠数据生成")
        testSleepDataGeneration(user: testUser, date: yesterday, testName: "昨天数据")
        
        // 测试2: 验证今天的睡眠数据生成（修复后应该工作）
        print("\n🧪 测试2: 今天睡眠数据生成（修复验证）")
        testSleepDataGeneration(user: testUser, date: today, testName: "今天数据")
        
        // 测试3: 验证个性化睡眠数据生成
        print("\n🧪 测试3: 个性化睡眠数据生成")
        testPersonalizedSleepGeneration(user: testUser, date: yesterday, testName: "昨天个性化")
        testPersonalizedSleepGeneration(user: testUser, date: today, testName: "今天个性化")
        
        // 测试4: 验证联动生成
        print("\n🧪 测试4: 睡眠步数联动生成")
        testSleepStepsIntegration(user: testUser, date: today)
        
        print("\n✅ 睡眠数据修复验证完成！")
    }
    
    private static func testSleepDataGeneration(user: VirtualUser, date: Date, testName: String) {
        print("   🔄 测试: \(testName)")
        
        // 使用DataGenerator生成数据
        let result = DataGenerator.generateDailyData(
            for: user,
            date: date,
            recentSleepData: [],
            recentStepsData: [],
            mode: .simple
        )
        
        if let sleepData = result.sleepData {
            print("   ✅ 睡眠数据生成成功")
            print("      睡眠时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("      入睡时间: \(DateFormatter.localizedString(from: sleepData.bedTime, dateStyle: .none, timeStyle: .short))")
            print("      起床时间: \(DateFormatter.localizedString(from: sleepData.wakeTime, dateStyle: .none, timeStyle: .short))")
            print("      睡眠阶段: \(sleepData.sleepStages.count)个")
        } else {
            print("   ❌ 睡眠数据生成失败 - 返回nil")
        }
        
        print("      步数数据: \(result.stepsData.totalSteps)步")
    }
    
    private static func testPersonalizedSleepGeneration(user: VirtualUser, date: Date, testName: String) {
        print("   🔄 测试: \(testName)")
        
        // 使用PersonalizedDataGenerator生成睡眠数据
        let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: date,
            mode: .simple
        )
        
        print("   ✅ 个性化睡眠数据生成成功")
        print("      睡眠时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
        print("      入睡时间: \(DateFormatter.localizedString(from: sleepData.bedTime, dateStyle: .none, timeStyle: .short))")
        print("      起床时间: \(DateFormatter.localizedString(from: sleepData.wakeTime, dateStyle: .none, timeStyle: .short))")
        print("      睡眠阶段: \(sleepData.sleepStages.count)个")
    }
    
    private static func testSleepStepsIntegration(user: VirtualUser, date: Date) {
        print("   🔄 测试睡眠步数联动")
        
        // 先生成睡眠数据
        let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: date,
            mode: .simple
        )
        
        // 再生成基于睡眠的步数分布
        let stepDistribution = PersonalizedDataGenerator.generateEnhancedDailySteps(
            for: user,
            date: date,
            sleepData: sleepData
        )
        
        print("   ✅ 睡眠步数联动成功")
        print("      睡眠时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
        print("      计划总步数: \(stepDistribution.totalSteps)步")
        print("      步数增量: \(stepDistribution.incrementalData.count)个")
        print("      首个增量: \(DateFormatter.localizedString(from: stepDistribution.incrementalData.first?.timestamp ?? Date(), dateStyle: .none, timeStyle: .short))")
        print("      最后增量: \(DateFormatter.localizedString(from: stepDistribution.incrementalData.last?.timestamp ?? Date(), dateStyle: .none, timeStyle: .short))")
    }
}

// 扩展以支持测试
extension SleepDataFixVerification {
    
    /// 快速验证修复效果的方法
    static func quickVerification() -> Bool {
        print("⚡ 快速验证睡眠数据修复...")
        
        let testUser = VirtualUserGenerator.generatePersonalizedUser(sleepType: SleepType.normal, activityLevel: ActivityLevel.medium)
        let today = Date()
        
        // 测试今天的数据生成
        let todayResult = DataGenerator.generateDailyData(
            for: testUser,
            date: today,
            recentSleepData: [],
            recentStepsData: [],
            mode: .simple
        )
        
        let personalizedSleep = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: testUser,
            date: today,
            mode: .simple
        )
        
        let hasDataGenSleep = todayResult.sleepData != nil
        let hasPersonalizedSleep = personalizedSleep.totalSleepHours > 0
        
        print("   DataGenerator今天睡眠: \(hasDataGenSleep ? "✅" : "❌")")
        print("   PersonalizedGenerator今天睡眠: \(hasPersonalizedSleep ? "✅" : "❌")")
        
        return hasDataGenSleep && hasPersonalizedSleep
    }
}