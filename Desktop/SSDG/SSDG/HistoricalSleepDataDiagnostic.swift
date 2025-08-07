//
//  HistoricalSleepDataDiagnostic.swift
//  SSDG
//
//  Created by Claude on 2025/8/1.
//

import Foundation

/// 🔍 历史睡眠数据生成诊断工具
struct HistoricalSleepDataDiagnostic {
    
    /// 🎯 运行完整诊断，找出为什么历史数据只有步数没有睡眠
    @MainActor
    static func diagnoseProblem() {
        print("\n🔍 历史睡眠数据生成诊断")
        print(String(repeating: "=", count: 60))
        
        // 1. 检查当前用户
        guard let user = SyncStateManager.shared.currentUser else {
            print("❌ 无用户数据，无法诊断")
            return
        }
        
        print("✅ 用户存在: \(user.age)岁 \(user.gender.displayName)")
        
        // 2. 测试单日历史睡眠数据生成
        print("\n🧪 测试单日历史睡眠数据生成...")
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: today))!
        
        print("   目标日期: \(DateFormatter.localizedString(from: yesterday, dateStyle: .short, timeStyle: .none))")
        
        // 直接调用 generatePersonalizedSleepData
        let singleSleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user, 
            date: yesterday, 
            mode: .simple
        )
        
        print("   单日睡眠数据生成结果:")
        print("     日期: \(singleSleepData.date)")
        print("     入睡时间: \(singleSleepData.bedTime)")
        print("     起床时间: \(singleSleepData.wakeTime)")
        print("     睡眠时长: \(String(format: "%.1f", singleSleepData.totalSleepHours))小时")
        print("     睡眠阶段数: \(singleSleepData.sleepStages.count)")
        
        // 3. 测试 HealthKit 规范验证
        print("\n🛡️ 测试 HealthKit 规范验证...")
        let validatedSleepData = HealthKitComplianceEnhancer.validateAndCorrectSleepData(singleSleepData)
        
        print("   验证后睡眠数据:")
        print("     日期: \(validatedSleepData.date)")
        print("     入睡时间: \(validatedSleepData.bedTime)")
        print("     起床时间: \(validatedSleepData.wakeTime)")
        print("     睡眠时长: \(String(format: "%.1f", validatedSleepData.totalSleepHours))小时")
        print("     睡眠阶段数: \(validatedSleepData.sleepStages.count)")
        
        // 4. 测试完整历史数据生成
        print("\n📊 测试完整历史数据生成（3天）...")
        let historicalData = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: user, 
            days: 3, 
            mode: .simple
        )
        
        print("   历史数据生成结果:")
        print("     睡眠数据: \(historicalData.sleepData.count)条")
        print("     步数数据: \(historicalData.stepsData.count)条")
        
        if historicalData.sleepData.isEmpty {
            print("     ❌ 睡眠数据为空！这就是问题所在")
        } else {
            print("     ✅ 睡眠数据正常生成")
            for (index, sleep) in historicalData.sleepData.enumerated() {
                print("       第\(index+1)天: \(DateFormatter.localizedString(from: sleep.date, dateStyle: .short, timeStyle: .none)) - \(String(format: "%.1f", sleep.totalSleepHours))小时")
            }
        }
        
        // 5. 测试 HealthKit 样本创建
        print("\n🏥 测试 HealthKit 样本创建...")
        testHealthKitSampleCreation(sleepData: validatedSleepData)
        
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 诊断完成")
        
        // 6. 给出诊断结论
        provideDiagnosisConclusion(
            singleSleepGenerated: true,
            historicalSleepCount: historicalData.sleepData.count,
            historicalStepsCount: historicalData.stepsData.count
        )
    }
    
    /// 🏥 测试 HealthKit 样本创建
    private static func testHealthKitSampleCreation(sleepData: SleepData) {
        // 模拟 HealthKitManager.createSleepSamples 的逻辑
        var samples: [String] = [] // 简化版，不使用真实的 HKCategorySample
        
        for stage in sleepData.sleepStages {
            let sampleDescription = "InBed Sample: \(stage.startTime) - \(stage.endTime)"
            samples.append(sampleDescription)
        }
        
        print("   创建的睡眠样本数: \(samples.count)")
        if samples.isEmpty {
            print("     ❌ 样本为空！这可能是问题原因")
        } else {
            print("     ✅ 样本创建正常")
            for (index, sample) in samples.enumerated() {
                print("       样本\(index+1): \(sample)")
            }
        }
    }
    
    /// 📋 给出诊断结论
    private static func provideDiagnosisConclusion(singleSleepGenerated: Bool, historicalSleepCount: Int, historicalStepsCount: Int) {
        print("\n📋 诊断结论:")
        
        if singleSleepGenerated && historicalSleepCount > 0 {
            print("✅ 睡眠数据生成功能正常")
            print("   问题可能在于:")
            print("   1. HealthKit 写入过程中睡眠数据被过滤")
            print("   2. UI 显示逻辑有问题")
            print("   3. 数据同步时机有问题")
            
        } else if singleSleepGenerated && historicalSleepCount == 0 {
            print("⚠️ 单日睡眠生成正常，但历史数据生成有问题")
            print("   问题在于 generatePersonalizedHistoricalData 方法")
            print("   建议检查该方法中的循环逻辑")
            
        } else {
            print("❌ 睡眠数据生成功能异常")
            print("   问题在于 generatePersonalizedSleepData 方法")
            print("   建议检查时间边界控制逻辑")
        }
        
        print("\n🔧 建议的修复步骤:")
        print("1. 运行此诊断工具确认问题位置")
        print("2. 检查控制台输出中的具体错误信息")
        print("3. 根据问题位置进行针对性修复")
        print("4. 再次运行诊断验证修复效果")
    }
}


// MARK: - 便捷调用函数
@MainActor
func diagnoseHistoricalSleepData() {
    HistoricalSleepDataDiagnostic.diagnoseProblem()
}