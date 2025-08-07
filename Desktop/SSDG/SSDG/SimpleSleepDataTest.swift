//
//  SimpleSleepDataTest.swift
//  SSDG - 简单睡眠数据修复测试
//
//  最简单的验证脚本，无外部依赖
//

import Foundation

class SimpleSleepDataTest {
    
    /// 最简单的一键验证
    static func verify() -> Bool {
        print("⚡ 简单验证睡眠数据修复...")
        
        // 创建测试用户
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal,
            activityLevel: ActivityLevel.medium
        )
        
        let today = Date()
        
        // 测试DataGenerator
        let dataGenResult = DataGenerator.generateDailyData(
            for: testUser,
            date: today,
            recentSleepData: [],
            recentStepsData: [],
            mode: .simple
        )
        
        // 测试PersonalizedDataGenerator
        let personalizedSleep = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: testUser,
            date: today,
            mode: .simple
        )
        
        let dataGenOK = dataGenResult.sleepData != nil
        let personalizedOK = personalizedSleep.totalSleepHours > 0
        
        print("   DataGenerator今天睡眠: \(dataGenOK ? "✅" : "❌")")
        print("   PersonalizedGenerator今天睡眠: \(personalizedOK ? "✅" : "❌")")
        
        if dataGenOK && personalizedOK {
            print("   🎉 修复成功！睡眠数据生成正常")
            
            if let sleepData = dataGenResult.sleepData {
                print("   睡眠时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
                print("   入睡时间: \(formatTime(sleepData.bedTime))")
                print("   起床时间: \(formatTime(sleepData.wakeTime))")
            }
            
            print("   步数: \(dataGenResult.stepsData.totalSteps)步")
            return true
        } else {
            print("   ❌ 修复失败，仍有问题")
            return false
        }
    }
    
    /// 测试睡眠步数联动
    static func testIntegration() {
        print("\n🔗 测试睡眠步数联动...")
        
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
        
        print("   睡眠时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
        print("   计划步数: \(stepDistribution.totalSteps)步")
        print("   步数增量: \(stepDistribution.incrementalData.count)个")
        
        // 检查睡眠时段步数
        let sleepPeriodIncrements = stepDistribution.incrementalData.filter { increment in
            increment.timestamp >= sleepData.bedTime && increment.timestamp <= sleepData.wakeTime
        }
        
        let sleepSteps = sleepPeriodIncrements.reduce(0) { $0 + $1.steps }
        let sleepRatio = Double(sleepSteps) / Double(stepDistribution.totalSteps)
        
        print("   睡眠期间步数: \(sleepSteps)步 (\(String(format: "%.1f", sleepRatio * 100))%)")
        
        if sleepRatio < 0.3 {
            print("   ✅ 睡眠感知算法工作正常")
        } else {
            print("   ⚠️ 睡眠感知算法需要调整")
        }
    }
    
    /// 完整测试
    static func fullTest() {
        print("🧪 SSDG睡眠数据修复完整测试")
        print(String(repeating: "-", count: 40))
        
        let success = verify()
        
        if success {
            testIntegration()
        }
        
        print(String(repeating: "-", count: 40))
        print(success ? "🎉 测试全部通过！" : "❌ 仍有问题需要解决")
    }
    
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}