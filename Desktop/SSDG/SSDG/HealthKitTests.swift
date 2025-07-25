//
//  HealthKitTests.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation
import HealthKit

// MARK: - HealthKit集成测试
class HealthKitTests {
    
    // 测试HealthKit可用性
    static func testHealthKitAvailability() {
        print("🧪 开始测试HealthKit可用性...")
        
        if HKHealthStore.isHealthDataAvailable() {
            print("✅ HealthKit可用")
        } else {
            print("❌ HealthKit不可用")
        }
        print()
    }
    
    // 测试权限请求
    static func testHealthKitAuthorization() async {
        print("🧪 开始测试HealthKit权限请求...")
        
        let healthKitManager = await MainActor.run { HealthKitManager.shared }
        let success = await healthKitManager.requestHealthKitAuthorization()
        
        if success {
            print("✅ HealthKit权限请求成功")
        } else {
            print("❌ HealthKit权限请求失败")
        }
        
        await MainActor.run {
            print("   权限状态: \(healthKitManager.authorizationStatus.description)")
            print("   是否已授权: \(healthKitManager.isAuthorized)")
        }
        print()
    }
    
    // 测试睡眠数据生成
    static func testSleepDataGeneration() {
        print("🧪 开始测试睡眠数据生成...")
        
        let user = VirtualUserGenerator.generateRandomUser()
        let historicalData = DataGenerator.generateHistoricalData(for: user, days: 7)
        
        print("✅ 生成睡眠数据: \(historicalData.sleepData.count) 天")
        
        // 验证数据结构
        for (index, sleepData) in historicalData.sleepData.enumerated() {
            print("   第\(index + 1)天:")
            print("     日期: \(DateFormatter.localizedString(from: sleepData.date, dateStyle: .short, timeStyle: .none))")
            print("     睡眠时间: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("     入睡时间: \(DateFormatter.localizedString(from: sleepData.bedTime, dateStyle: .none, timeStyle: .short))")
            print("     起床时间: \(DateFormatter.localizedString(from: sleepData.wakeTime, dateStyle: .none, timeStyle: .short))")
            print("     睡眠阶段: \(sleepData.sleepStages.count) 个")
            
            // 验证睡眠阶段
            let stagesSummary = sleepData.sleepStages.reduce(into: [SleepStageType: TimeInterval]()) { result, stage in
                result[stage.stage, default: 0] += stage.duration
            }
            
            for (stage, duration) in stagesSummary {
                print("       \(stage.displayName): \(String(format: "%.1f", duration/3600))小时")
            }
        }
        print()
    }
    
    // 测试步数数据生成
    static func testStepsDataGeneration() {
        print("🧪 开始测试步数数据生成...")
        
        let user = VirtualUserGenerator.generateRandomUser()
        let historicalData = DataGenerator.generateHistoricalData(for: user, days: 7)
        
        print("✅ 生成步数数据: \(historicalData.stepsData.count) 天")
        
        // 验证数据结构
        for (index, stepsData) in historicalData.stepsData.enumerated() {
            print("   第\(index + 1)天:")
            print("     日期: \(DateFormatter.localizedString(from: stepsData.date, dateStyle: .short, timeStyle: .none))")
            print("     总步数: \(stepsData.totalSteps) 步")
            print("     小时数据: \(stepsData.hourlySteps.count) 个")
            
            // 找出最活跃的小时
            let maxHour = stepsData.hourlySteps.max { $0.steps < $1.steps }
            if let maxHour = maxHour {
                print("     最活跃时间: \(maxHour.hour):00 (\(maxHour.steps) 步)")
            }
        }
        print()
    }
    
    // 测试数据写入（模拟）
    static func testDataWriting() async {
        print("🧪 开始测试数据写入...")
        
        let user = VirtualUserGenerator.generateRandomUser()
        let historicalData = DataGenerator.generateHistoricalData(for: user, days: 3)
        
        print("   生成用户: \(user.gender.displayName), \(user.age)岁")
        print("   睡眠数据: \(historicalData.sleepData.count) 天")
        print("   步数数据: \(historicalData.stepsData.count) 天")
        
        let healthKitManager = await MainActor.run { HealthKitManager.shared }
        
        // 请求权限
        let authSuccess = await healthKitManager.requestHealthKitAuthorization()
        if !authSuccess {
            print("❌ 权限请求失败，跳过写入测试")
            return
        }
        
        // 写入数据
        let writeSuccess = await healthKitManager.syncUserData(
            user: user,
            sleepData: historicalData.sleepData,
            stepsData: historicalData.stepsData,
            mode: .simple
        )
        
        if writeSuccess {
            print("✅ 数据写入成功")
        } else {
            print("❌ 数据写入失败")
            await MainActor.run {
                if let error = healthKitManager.lastError {
                    print("   错误: \(error.localizedDescription)")
                }
            }
        }
        print()
    }
    
    // 测试数据一致性
    static func testDataConsistency() {
        print("🧪 开始测试数据一致性...")
        
        let user = VirtualUserGenerator.generateRandomUser()
        
        // 生成相同用户的数据两次
        let data1 = DataGenerator.generateHistoricalData(for: user, days: 10)
        let data2 = DataGenerator.generateHistoricalData(for: user, days: 10)
        
        // 比较数据一致性
        let sleep1 = data1.sleepData.map { $0.totalSleepHours }
        let sleep2 = data2.sleepData.map { $0.totalSleepHours }
        
        let steps1 = data1.stepsData.map { $0.totalSteps }
        let steps2 = data2.stepsData.map { $0.totalSteps }
        
        let sleepConsistent = sleep1 == sleep2
        let stepsConsistent = steps1 == steps2
        
        print("   睡眠数据一致性: \(sleepConsistent ? "✅" : "❌")")
        print("   步数数据一致性: \(stepsConsistent ? "✅" : "❌")")
        
        if sleepConsistent && stepsConsistent {
            print("✅ 数据一致性测试通过")
        } else {
            print("❌ 数据一致性测试失败")
        }
        print()
    }
    
    // 测试数据范围
    static func testDataRanges() {
        print("🧪 开始测试数据范围...")
        
        let user = VirtualUserGenerator.generateRandomUser()
        let historicalData = DataGenerator.generateHistoricalData(for: user, days: 30)
        
        let sleepHours = historicalData.sleepData.map { $0.totalSleepHours }
        let totalSteps = historicalData.stepsData.map { $0.totalSteps }
        
        let minSleep = sleepHours.min() ?? 0
        let maxSleep = sleepHours.max() ?? 0
        let avgSleep = sleepHours.reduce(0, +) / Double(sleepHours.count)
        
        let minSteps = totalSteps.min() ?? 0
        let maxSteps = totalSteps.max() ?? 0
        let avgSteps = totalSteps.reduce(0, +) / totalSteps.count
        
        print("   睡眠时间范围: \(String(format: "%.1f", minSleep)) - \(String(format: "%.1f", maxSleep)) 小时")
        print("   平均睡眠时间: \(String(format: "%.1f", avgSleep)) 小时")
        print("   用户基准值: \(String(format: "%.1f", user.sleepBaseline)) 小时")
        
        print("   步数范围: \(minSteps) - \(maxSteps) 步")
        print("   平均步数: \(avgSteps) 步")
        print("   用户基准值: \(user.stepsBaseline) 步")
        
        // 验证范围 (更新为合理的医学范围)
        let sleepInRange = minSleep >= 5.0 && maxSleep <= 10.0
        let stepsInRange = minSteps >= 800 && maxSteps <= 20000
        
        print("   睡眠范围验证: \(sleepInRange ? "✅" : "❌")")
        print("   步数范围验证: \(stepsInRange ? "✅" : "❌")")
        print()
    }
    
    // 运行所有测试
    static func runAllTests() async {
        print("🚀 开始运行HealthKit集成测试套件")
        print(String(repeating: "=", count: 50))
        
        testHealthKitAvailability()
        await testHealthKitAuthorization()
        testSleepDataGeneration()
        testStepsDataGeneration()
        testDataConsistency()
        testDataRanges()
        await testDataWriting()
        
        print("✅ 所有测试完成！")
        print(String(repeating: "=", count: 50))
    }
} 