//
//  DemoScript.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation
import HealthKit

// MARK: - 演示脚本
class DemoScript {
    
    // 完整演示流程
    static func runCompleteDemo() async {
        print("🎬 开始SSDG完整功能演示")
        print(String(repeating: "=", count: 60))
        
        // 1. 生成虚拟用户
        print("\n📝 第1步：生成虚拟用户")
        let user = VirtualUserGenerator.generateRandomUser()
        print("✅ 生成虚拟用户成功")
        print(user.detailedDescription)
        
        // 2. 生成历史数据
        print("\n📊 第2步：生成历史数据")
        let days = 60
        let historicalData = DataGenerator.generateHistoricalData(for: user, days: days)
        print("✅ 生成\(days)天历史数据成功")
        print("   睡眠数据: \(historicalData.sleepData.count) 天")
        print("   步数数据: \(historicalData.stepsData.count) 天")
        
        // 3. 数据统计分析
        print("\n📈 第3步：数据统计分析")
        analyzeSleepData(historicalData.sleepData)
        analyzeStepsData(historicalData.stepsData)
        
        // 4. HealthKit集成
        print("\n🏥 第4步：HealthKit集成")
        await demonstrateHealthKit(user: user, sleepData: historicalData.sleepData, stepsData: historicalData.stepsData)
        
        // 5. 数据验证
        print("\n🔍 第5步：数据验证")
        validateDataQuality(user: user, sleepData: historicalData.sleepData, stepsData: historicalData.stepsData)
        
        // 执行清理操作
        print("🧹 执行清理操作...")
        let _ = await HealthKitManager.shared.forceCleanDuplicateData(for: Date())
        
        print("\n🎉 完整功能演示结束")
        print(String(repeating: "=", count: 60))
    }
    
    // 分析睡眠数据
    private static func analyzeSleepData(_ sleepData: [SleepData]) {
        let sleepHours = sleepData.map { $0.totalSleepHours }
        
        let minSleep = sleepHours.min() ?? 0
        let maxSleep = sleepHours.max() ?? 0
        let avgSleep = sleepHours.reduce(0, +) / Double(sleepHours.count)
        
        print("   睡眠时间分析:")
        print("     最短: \(String(format: "%.1f", minSleep)) 小时")
        print("     最长: \(String(format: "%.1f", maxSleep)) 小时")
        print("     平均: \(String(format: "%.1f", avgSleep)) 小时")
        
        // 睡眠阶段分析
        var totalStages: [SleepStageType: TimeInterval] = [:]
        for sleep in sleepData {
            for stage in sleep.sleepStages {
                totalStages[stage.stage, default: 0] += stage.duration
            }
        }
        
        print("   睡眠阶段分析:")
        for (stage, duration) in totalStages {
            let hours = duration / 3600.0
            let percentage = (duration / totalStages.values.reduce(0, +)) * 100
            print("     \(stage.displayName): \(String(format: "%.1f", hours)) 小时 (\(String(format: "%.1f", percentage))%)")
        }
    }
    
    // 分析步数数据
    private static func analyzeStepsData(_ stepsData: [StepsData]) {
        let totalSteps = stepsData.map { $0.totalSteps }
        
        let minSteps = totalSteps.min() ?? 0
        let maxSteps = totalSteps.max() ?? 0
        let avgSteps = totalSteps.reduce(0, +) / totalSteps.count
        
        print("   步数数据分析:")
        print("     最少: \(minSteps) 步")
        print("     最多: \(maxSteps) 步")
        print("     平均: \(avgSteps) 步")
        
        // 活跃时间分析
        var hourlyActivity: [Int: Int] = [:]
        for steps in stepsData {
            for hourlyStep in steps.hourlySteps {
                hourlyActivity[hourlyStep.hour, default: 0] += hourlyStep.steps
            }
        }
        
        let sortedActivity = hourlyActivity.sorted { $0.value > $1.value }
        print("   最活跃时间段:")
        for (hour, steps) in sortedActivity.prefix(5) {
            print("     \(hour):00 - \(steps) 步")
        }
    }
    
    // 演示HealthKit集成
    private static func demonstrateHealthKit(user: VirtualUser, sleepData: [SleepData], stepsData: [StepsData]) async {
        let healthKitManager = await MainActor.run { HealthKitManager.shared }
        
        print("   检查HealthKit可用性...")
        if !HKHealthStore.isHealthDataAvailable() {
            print("   ❌ HealthKit不可用")
            return
        }
        print("   ✅ HealthKit可用")
        
        print("   请求HealthKit权限...")
        let authorized = await healthKitManager.requestHealthKitAuthorization()
        
        if authorized {
            print("   ✅ HealthKit权限已授权")
            
            print("   开始同步数据到Apple Health...")
            let syncSuccess = await healthKitManager.syncUserData(
                user: user,
                sleepData: sleepData,
                stepsData: stepsData,
                mode: .simple
            )
            
            if syncSuccess {
                print("   ✅ 数据同步成功")
                print("     同步睡眠数据: \(sleepData.count) 天")
                print("     同步步数数据: \(stepsData.count) 天")
            } else {
                print("   ❌ 数据同步失败")
                await MainActor.run {
                    if let error = healthKitManager.lastError {
                        print("     错误: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            print("   ❌ HealthKit权限被拒绝")
        }
    }
    
    // 验证数据质量
    private static func validateDataQuality(user: VirtualUser, sleepData: [SleepData], stepsData: [StepsData]) {
        print("   数据质量验证:")
        
        // 验证用户数据
        let userValid = user.isValid
        print("     用户数据有效性: \(userValid ? "✅" : "❌")")
        
        // 验证睡眠数据
        let sleepValid = sleepData.allSatisfy { sleep in
            sleep.totalSleepHours >= 4.0 && sleep.totalSleepHours <= 12.0
        }
        print("     睡眠数据有效性: \(sleepValid ? "✅" : "❌")")
        
        // 验证步数数据
        let stepsValid = stepsData.allSatisfy { steps in
            steps.totalSteps >= 800 && steps.totalSteps <= 20000
        }
        print("     步数数据有效性: \(stepsValid ? "✅" : "❌")")
        
        // 验证数据一致性
        let sameUserData = DataGenerator.generateHistoricalData(for: user, days: sleepData.count)
        let consistentSleep = sleepData.map { $0.totalSleepHours } == sameUserData.sleepData.map { $0.totalSleepHours }
        let consistentSteps = stepsData.map { $0.totalSteps } == sameUserData.stepsData.map { $0.totalSteps }
        print("     数据一致性: \(consistentSleep && consistentSteps ? "✅" : "❌")")
        
        // 验证数据完整性
        let completeData = sleepData.count == stepsData.count && !sleepData.isEmpty
        print("     数据完整性: \(completeData ? "✅" : "❌")")
    }
    
    // 快速演示
    static func runQuickDemo() {
        print("🚀 快速演示SSDG功能")
        print(String(repeating: "-", count: 40))
        
        // 生成用户
        let user = VirtualUserGenerator.generateRandomUser()
        print("👤 生成用户: \(user.gender.displayName), \(user.age)岁")
        print("   BMI: \(user.formattedBMI) (\(user.bmiCategory))")
        print("   睡眠基准: \(user.formattedSleepBaseline) (\(user.sleepBaselineDescription))")
        print("   步数基准: \(user.formattedStepsBaseline) (\(user.stepsBaselineDescription))")
        
        // 生成数据
        let data = DataGenerator.generateHistoricalData(for: user, days: 7)
        print("\n📊 生成7天数据:")
        print("   睡眠数据: \(data.sleepData.count) 天")
        print("   步数数据: \(data.stepsData.count) 天")
        
        // 显示最近3天数据
        print("\n📅 最近3天数据:")
        for (index, sleep) in data.sleepData.suffix(3).enumerated() {
            let steps = data.stepsData.suffix(3)[data.stepsData.suffix(3).startIndex + index]
            print("   第\(index + 1)天: 睡眠\(String(format: "%.1f", sleep.totalSleepHours))h, 步数\(steps.totalSteps)步")
        }
        
        print("\n✅ 快速演示完成")
    }
} 