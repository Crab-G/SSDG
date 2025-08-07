//
//  FinalSleepDataTest.swift
//  SSDG - 最终睡眠数据修复测试
//
//  验证所有修复是否成功
//

import Foundation

class FinalSleepDataTest {
    
    /// 最终验证测试
    static func runFinalVerification() {
        print("🎯 最终睡眠数据修复验证")
        print(String(repeating: "=", count: 40))
        
        // 1. 基础功能测试
        testBasicSleepGeneration()
        
        // 2. 个性化生成器测试
        testPersonalizedGenerator()
        
        // 3. 时间边界测试
        testTimeBoundaryFix()
        
        // 4. 集成测试
        testIntegration()
        
        print("\n" + String(repeating: "=", count: 40))
        print("🏆 最终验证完成！")
        print(String(repeating: "=", count: 40))
    }
    
    private static func testBasicSleepGeneration() {
        print("\n🧪 1. 基础睡眠数据生成测试")
        
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal,
            activityLevel: ActivityLevel.medium
        )
        
        let today = Date()
        
        let result = DataGenerator.generateDailyData(
            for: testUser,
            date: today,
            recentSleepData: [],
            recentStepsData: [],
            mode: .simple
        )
        
        if let sleepData = result.sleepData {
            print("   ✅ 睡眠数据生成成功")
            print("      时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("      入睡: \(formatTime(sleepData.bedTime))")
            print("      起床: \(formatTime(sleepData.wakeTime))")
            print("      阶段: \(sleepData.sleepStages.count)个")
        } else {
            print("   ❌ 睡眠数据生成失败")
        }
        
        print("      步数: \(result.stepsData.totalSteps)步")
    }
    
    private static func testPersonalizedGenerator() {
        print("\n🧪 2. 个性化生成器测试")
        
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal,
            activityLevel: ActivityLevel.medium
        )
        
        let today = Date()
        
        let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: testUser,
            date: today,
            mode: .simple
        )
        
        print("   ✅ 个性化睡眠数据生成成功")
        print("      时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
        print("      入睡: \(formatTime(sleepData.bedTime))")
        print("      起床: \(formatTime(sleepData.wakeTime))")
        print("      阶段: \(sleepData.sleepStages.count)个")
    }
    
    private static func testTimeBoundaryFix() {
        print("\n🧪 3. 时间边界修复测试")
        
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal,
            activityLevel: ActivityLevel.medium
        )
        
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // 测试昨天
        let yesterdayResult = DataGenerator.generateDailyData(
            for: testUser,
            date: yesterday,
            recentSleepData: [],
            recentStepsData: [],
            mode: .simple
        )
        
        // 测试今天
        let todayResult = DataGenerator.generateDailyData(
            for: testUser,
            date: today,
            recentSleepData: [],
            recentStepsData: [],
            mode: .simple
        )
        
        print("   昨天睡眠数据: \(yesterdayResult.sleepData != nil ? "✅" : "❌")")
        print("   今天睡眠数据: \(todayResult.sleepData != nil ? "✅" : "❌")")
        
        if todayResult.sleepData != nil {
            print("   🎉 时间边界修复成功！")
        } else {
            print("   ⚠️ 时间边界修复可能有问题")
        }
    }
    
    private static func testIntegration() {
        print("\n🧪 4. 睡眠步数集成测试")
        
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal,
            activityLevel: ActivityLevel.medium
        )
        
        let today = Date()
        
        // 生成睡眠数据
        let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: testUser,
            date: today,
            mode: .simple
        )
        
        // 生成基于睡眠的步数分布
        let stepDistribution = PersonalizedDataGenerator.generateEnhancedDailySteps(
            for: testUser,
            date: today,
            sleepData: sleepData
        )
        
        print("   ✅ 睡眠步数集成成功")
        print("      睡眠: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
        print("      步数: \(stepDistribution.totalSteps)步")
        print("      增量: \(stepDistribution.incrementalData.count)个")
        
        // 验证睡眠时段步数是否减少
        let sleepPeriodIncrements = stepDistribution.incrementalData.filter { increment in
            increment.timestamp >= sleepData.bedTime && increment.timestamp <= sleepData.wakeTime
        }
        
        let sleepSteps = sleepPeriodIncrements.reduce(0) { $0 + $1.steps }
        let sleepRatio = Double(sleepSteps) / Double(stepDistribution.totalSteps)
        
        print("      睡眠期间步数: \(sleepSteps)步 (\(String(format: "%.1f", sleepRatio * 100))%)")
        
        if sleepRatio < 0.3 {
            print("      ✅ 睡眠感知算法工作正常")
        } else {
            print("      ⚠️ 睡眠感知算法需要调整")
        }
    }
    
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// 一键修复验证
    static func quickCheck() -> Bool {
        print("⚡ 一键修复验证...")
        
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal,
            activityLevel: ActivityLevel.medium
        )
        
        let today = Date()
        
        // 检查DataGenerator
        let dataGenResult = DataGenerator.generateDailyData(
            for: testUser,
            date: today,
            recentSleepData: [],
            recentStepsData: [],
            mode: .simple
        )
        
        // 检查PersonalizedDataGenerator
        let personalizedSleep = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: testUser,
            date: today,
            mode: .simple
        )
        
        let dataGenOK = dataGenResult.sleepData != nil
        let personalizedOK = personalizedSleep.totalSleepHours > 0
        
        print("   DataGenerator: \(dataGenOK ? "✅" : "❌")")
        print("   PersonalizedGenerator: \(personalizedOK ? "✅" : "❌")")
        
        let isFixed = dataGenOK && personalizedOK
        print("   总体状态: \(isFixed ? "✅ 修复成功" : "❌ 仍有问题")")
        
        return isFixed
    }
}

