//
//  QuickSleepDataTest.swift
//  SSDG - 快速睡眠数据修复测试
//
//  简单验证睡眠数据修复是否生效
//

import Foundation

class QuickSleepDataTest {
    
    /// 快速测试修复效果
    static func testSleepDataFix() {
        print("🔧 快速测试睡眠数据修复效果...")
        
        // 创建测试用户
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal, 
            activityLevel: ActivityLevel.medium
        )
        
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        print("\n📅 测试日期:")
        print("   今天: \(DateFormatter.localizedString(from: today, dateStyle: .short, timeStyle: .none))")
        print("   昨天: \(DateFormatter.localizedString(from: yesterday, dateStyle: .short, timeStyle: .none))")
        
        // 测试1: 昨天的数据（应该正常）
        print("\n🧪 测试1: 昨天数据生成")
        testDataGeneration(user: testUser, date: yesterday, name: "昨天")
        
        // 测试2: 今天的数据（修复后应该正常）
        print("\n🧪 测试2: 今天数据生成（关键测试）")
        testDataGeneration(user: testUser, date: today, name: "今天")
        
        print("\n🔍 修复效果总结:")
        let todayResult = DataGenerator.generateDailyData(
            for: testUser, 
            date: today, 
            recentSleepData: [], 
            recentStepsData: [], 
            mode: .simple
        )
        
        if todayResult.sleepData != nil {
            print("✅ 修复成功！现在可以生成当天睡眠数据")
            print("   睡眠时长: \(String(format: "%.1f", todayResult.sleepData!.totalSleepHours))小时")
        } else {
            print("❌ 修复失败！当天睡眠数据仍为nil")
        }
        
        print("   当天步数: \(todayResult.stepsData.totalSteps)步")
    }
    
    private static func testDataGeneration(user: VirtualUser, date: Date, name: String) {
        let result = DataGenerator.generateDailyData(
            for: user,
            date: date,
            recentSleepData: [],
            recentStepsData: [],
            mode: .simple
        )
        
        print("   \(name)数据:")
        
        if let sleepData = result.sleepData {
            print("     ✅ 睡眠: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("        入睡: \(DateFormatter.localizedString(from: sleepData.bedTime, dateStyle: .none, timeStyle: .short))")
            print("        起床: \(DateFormatter.localizedString(from: sleepData.wakeTime, dateStyle: .none, timeStyle: .short))")
        } else {
            print("     ❌ 睡眠: nil（无数据）")
        }
        
        print("     📊 步数: \(result.stepsData.totalSteps)步")
    }
    
    /// 测试个性化睡眠生成器
    static func testPersonalizedSleepGenerator() {
        print("\n🧪 测试个性化睡眠生成器...")
        
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: SleepType.normal,
            activityLevel: ActivityLevel.medium
        )
        
        let today = Date()
        
        print("   生成今天的个性化睡眠数据...")
        
        let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: testUser,
            date: today,
            mode: .simple
        )
        
        print("   ✅ 个性化睡眠生成成功")
        print("     睡眠时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
        print("     入睡时间: \(DateFormatter.localizedString(from: sleepData.bedTime, dateStyle: .none, timeStyle: .short))")
        print("     起床时间: \(DateFormatter.localizedString(from: sleepData.wakeTime, dateStyle: .none, timeStyle: .short))")
        print("     睡眠阶段: \(sleepData.sleepStages.count)个")
    }
}

// 扩展：提供简单的命令行测试接口
extension QuickSleepDataTest {
    
    /// 全面测试（包含错误处理）
    static func runFullTest() {
        print(String(repeating: "=", count: 50))
        print("🔬 SSDG睡眠数据修复全面测试")
        print(String(repeating: "=", count: 50))
        
        // 基本数据生成测试
        testSleepDataFix()
        
        // 个性化生成器测试
        testPersonalizedSleepGenerator()
        
        // 联动测试
        testSleepStepsIntegration()
        
        print("\n" + String(repeating: "=", count: 50))
        print("🎉 全面测试完成！")
        print(String(repeating: "=", count: 50))
    }
    
    private static func testSleepStepsIntegration() {
        print("\n🧪 测试睡眠步数联动...")
        
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
        
        print("   ✅ 睡眠步数联动测试成功")
        print("     参考睡眠: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
        print("     计划步数: \(stepDistribution.totalSteps)步")
        print("     分布增量: \(stepDistribution.incrementalData.count)个")
        
        // 检查睡眠时段的步数是否减少
        let sleepPeriodIncrements = stepDistribution.incrementalData.filter { increment in
            increment.timestamp >= sleepData.bedTime && increment.timestamp <= sleepData.wakeTime
        }
        
        let sleepPeriodSteps = sleepPeriodIncrements.reduce(0) { $0 + $1.steps }
        let totalSteps = stepDistribution.totalSteps
        let sleepRatio = Double(sleepPeriodSteps) / Double(totalSteps)
        
        print("     睡眠时段步数: \(sleepPeriodSteps)步 (\(String(format: "%.1f", sleepRatio * 100))%)")
        
        if sleepRatio < 0.2 { // 睡眠时段步数应该少于总步数的20%
            print("     ✅ 睡眠感知算法工作正常")
        } else {
            print("     ⚠️ 睡眠感知算法可能需要调整")
        }
    }
}

