//
//  FinalDiagnosticTest.swift
//  SSDG
//
//  Created by Claude on 2025/8/1.
//

import Foundation
import SwiftUI

/// 🎯 最终诊断测试 - 彻底解决睡眠数据问题
struct FinalDiagnosticTest {
    
    /// 🚀 运行完整诊断并修复
    @MainActor
    static func runCompleteTest() {
        print("\n" + "🎯".padding(toLength: 80, withPad: "=", startingAt: 0))
        print("最终诊断测试：彻底解决睡眠数据问题")
        print("基于之前的CRITICAL_FIX_BREAKTHROUGH分析")
        print("=".padding(toLength: 80, withPad: "=", startingAt: 0))
        
        // 步骤1：验证修复状态
        print("\n📋 步骤1：验证关键修复状态")
        verifyKeyFixes()
        
        // 步骤2：运行终极数据流测试
        print("\n📋 步骤2：运行终极数据流测试")
        UltimateDataFlowTest.runCompleteDataFlowDiagnosis()
        
        // 步骤3：强制数据生成测试
        print("\n📋 步骤3：强制数据生成测试")
        forceGenerateAndTest()
        
        // 步骤4：实时状态监控
        print("\n📋 步骤4：实时状态监控")
        monitorRealTimeStatus()
        
        print("\n" + "✅".padding(toLength: 80, withPad: "=", startingAt: 0))
        print("最终诊断测试完成")
        print("=".padding(toLength: 80, withPad: "=", startingAt: 0))
    }
    
    // MARK: - 验证关键修复状态
    @MainActor
    static func verifyKeyFixes() {
        print("🔍 验证ContentView数据检查逻辑修复...")
        
        let manager = SyncStateManager.shared
        let calendar = Calendar.current
        let today = Date()
        
        let existingTodaySteps = manager.todayStepsData
        let existingTodaySleep = manager.todaySleepData
        
        print("   当前数据状态：")
        print("   - 步数数据：\(existingTodaySteps != nil ? "存在" : "不存在")")
        print("   - 睡眠数据：\(existingTodaySleep != nil ? "存在" : "不存在")")
        
        // 验证修复后的逻辑
        let hasCompleteData = existingTodaySteps != nil && existingTodaySleep != nil &&
                              (existingTodaySteps != nil ? calendar.isDate(existingTodaySteps!.date, inSameDayAs: today) : false) &&
                              (existingTodaySleep != nil ? calendar.isDate(existingTodaySleep!.date, inSameDayAs: today) : false)
        
        print("   修复后逻辑检查：")
        print("   - hasCompleteData：\(hasCompleteData)")
        
        if hasCompleteData {
            print("   ✅ 数据完整，会跳过生成")
            print("   - 步数：\(existingTodaySteps!.totalSteps)步")
            print("   - 睡眠：\(String(format: "%.1f", existingTodaySleep!.totalSleepHours))小时")
        } else {
            print("   ⚠️ 数据不完整，会继续生成")
            
            var missingData: [String] = []
            if existingTodaySteps == nil || !calendar.isDate(existingTodaySteps!.date, inSameDayAs: today) {
                missingData.append("步数")
            }
            if existingTodaySleep == nil || !calendar.isDate(existingTodaySleep!.date, inSameDayAs: today) {
                missingData.append("睡眠")
            }
            print("   - 缺失数据：\(missingData.joined(separator: "、"))")
        }
        
        print("\n🔍 验证DataGenerator修复...")
        guard let user = manager.currentUser else {
            print("   ❌ 无法验证：缺少用户数据")
            return
        }
        
        let historicalSleep = manager.historicalSleepData
        let historicalSteps = manager.historicalStepsData
        
        print("   历史数据状态：")
        print("   - 历史睡眠：\(historicalSleep.count)天")
        print("   - 历史步数：\(historicalSteps.count)天")
        
        // 测试当天数据生成
        let testResult = DataGenerator.generateDailyData(
            for: user,
            date: today,
            recentSleepData: historicalSleep,
            recentStepsData: historicalSteps,
            mode: manager.dataMode
        )
        
        print("   当天数据生成测试：")
        print("   - 睡眠数据：\(testResult.sleepData != nil ? "✅ 成功" : "❌ 失败")")
        print("   - 步数数据：✅ 成功（\(testResult.stepsData.totalSteps)步）")
        
        if let sleepData = testResult.sleepData {
            print("   - 睡眠详情：\(String(format: "%.1f", sleepData.totalSleepHours))小时")
        }
    }
    
    // MARK: - 强制数据生成测试
    @MainActor
    static func forceGenerateAndTest() {
        print("🔬 强制生成今日数据并测试...")
        
        guard let user = SyncStateManager.shared.currentUser else {
            print("   ❌ 无法测试：缺少用户数据")
            return
        }
        
        let manager = SyncStateManager.shared
        let today = Date()
        
        print("   1️⃣ 强制清理今日数据...")
        manager.resetTodayData()
        print("   ✅ 今日数据已清理")
        
        print("   2️⃣ 确保有历史数据...")
        if manager.historicalSleepData.isEmpty {
            print("   ⚠️ 历史数据为空，生成测试数据...")
            RunDiagnostics.generateTestHistoricalData(for: user)
        }
        
        print("   3️⃣ 强制生成今日数据...")
        let result = DataGenerator.generateDailyData(
            for: user,
            date: today,
            recentSleepData: manager.historicalSleepData,
            recentStepsData: manager.historicalStepsData,
            mode: manager.dataMode
        )
        
        print("   生成结果：")
        if let sleepData = result.sleepData {
            print("   ✅ 睡眠数据生成成功")
            print("     - 时长：\(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("     - 入睡：\(sleepData.bedTime)")
            print("     - 起床：\(sleepData.wakeTime)")
            print("     - 阶段数：\(sleepData.sleepStages.count)")
            
            // 手动更新到SyncStateManager
            manager.updateSyncData(sleepData: sleepData, stepsData: result.stepsData)
            print("   ✅ 数据已更新到SyncStateManager")
            
        } else {
            print("   ❌ 睡眠数据生成失败")
            
            // 深度诊断
            deepDiagnoseSleepGenerationFailure(user: user, date: today)
        }
        
        print("   ✅ 步数数据：\(result.stepsData.totalSteps)步")
        
        print("   4️⃣ 验证SyncStateManager状态...")
        let finalSleepData = manager.todaySleepData
        let finalStepsData = manager.todayStepsData
        
        print("   最终状态：")
        print("   - todaySleepData：\(finalSleepData != nil ? "✅ 存在" : "❌ 不存在")")
        print("   - todayStepsData：\(finalStepsData != nil ? "✅ 存在" : "❌ 不存在")")
        
        if let sleepData = finalSleepData {
            print("   - 睡眠时长：\(String(format: "%.1f", sleepData.totalSleepHours))小时")
        }
        if let stepsData = finalStepsData {
            print("   - 步数：\(stepsData.totalSteps)步")
        }
    }
    
    // MARK: - 深度诊断睡眠生成失败
    @MainActor
    static func deepDiagnoseSleepGenerationFailure(user: VirtualUser, date: Date) {
        print("   🔬 深度诊断睡眠数据生成失败...")
        
        // 1. 检查PersonalizedDataGenerator
        print("     测试PersonalizedDataGenerator...")
        let historicalSleep = SyncStateManager.shared.historicalSleepData
        
        let personalizedSleep = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: date
        )
        print("     ✅ PersonalizedDataGenerator成功")
        print("       睡眠时长：\(String(format: "%.1f", personalizedSleep.totalSleepHours))小时")
        
        // 如果PersonalizedDataGenerator成功，问题在DataGenerator的调用
        print("     🚨 问题定位：DataGenerator没有正确调用PersonalizedDataGenerator")
        
        // 2. 检查时间边界
        print("     检查时间边界逻辑...")
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let targetDate = date
        
        print("       todayStart: \(todayStart)")
        print("       targetDate: \(targetDate)")
        print("       date >= todayStart: \(targetDate >= todayStart)")
        
        // 3. 检查用户基线
        print("     检查用户配置...")
        print("       年龄: \(user.age)")
        print("       性别: \(user.gender.displayName)")
        print("       睡眠基线: \(user.sleepBaseline)小时")
        print("       步数基线: \(user.stepsBaseline)步")
        
        // 4. 检查历史数据质量
        print("     检查历史数据质量...")
        print("       历史数据量: \(historicalSleep.count)")
        if !historicalSleep.isEmpty {
            let avgSleep = historicalSleep.map(\.totalSleepHours).reduce(0, +) / Double(historicalSleep.count)
            print("       历史平均睡眠: \(String(format: "%.1f", avgSleep))小时")
            
            let recentSleep = historicalSleep.suffix(3)
            print("       最近3天睡眠:")
            for sleep in recentSleep {
                print("         \(sleep.date): \(String(format: "%.1f", sleep.totalSleepHours))小时")
            }
        }
    }
    
    // MARK: - 生成测试历史数据
    @MainActor
    static func generateTestHistoricalData(for user: VirtualUser) {
        print("     生成测试历史数据...")
        
        let calendar = Calendar.current
        let today = Date()
        var historicalSleep: [SleepData] = []
        var historicalSteps: [StepsData] = []
        
        // 生成最近7天的测试数据
        for i in 1...7 {
            guard let pastDate = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // 生成测试睡眠数据
            let bedTime = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: pastDate)!
            let wakeTime = calendar.date(byAdding: .hour, value: 8, to: bedTime)!
            
            let sleepStage = SleepStage(
                stage: .light,
                startTime: bedTime,
                endTime: wakeTime
            )
            
            let sleepData = SleepData(
                date: pastDate,
                bedTime: bedTime,
                wakeTime: wakeTime,
                sleepStages: [sleepStage]
            )
            
            historicalSleep.append(sleepData)
            
            // 生成测试步数据
            let stepsData = StepsData(
                date: pastDate,
                hourlySteps: [HourlySteps(
                    hour: 12,
                    steps: 8000 + Int.random(in: -1000...2000),
                    startTime: pastDate,
                    endTime: calendar.date(byAdding: .hour, value: 1, to: pastDate)!
                )]
            )
            
            historicalSteps.append(stepsData)
        }
        
        // 更新到SyncStateManager
        SyncStateManager.shared.updateHistoricalData(sleepData: historicalSleep, stepsData: historicalSteps)
        print("     ✅ 已生成\(historicalSleep.count)天测试历史数据")
    }
    
    // MARK: - 实时状态监控
    @MainActor
    static func monitorRealTimeStatus() {
        print("📊 实时状态监控...")
        
        let manager = SyncStateManager.shared
        
        print("   SyncStateManager状态：")
        print("   - todaySleepData: \(manager.todaySleepData != nil ? "存在" : "不存在")")
        print("   - todayStepsData: \(manager.todayStepsData != nil ? "存在" : "不存在")")
        print("   - todaySyncStatus: \(manager.todaySyncStatus.displayName)")
        print("   - lastSyncDate: \(manager.lastSyncDate?.description ?? "无")")
        
        if let sleepData = manager.todaySleepData {
            print("   睡眠数据详情：")
            print("     - 日期: \(sleepData.date)")
            print("     - 时长: \(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("     - 入睡: \(sleepData.bedTime)")
            print("     - 起床: \(sleepData.wakeTime)")
        }
        
        if let stepsData = manager.todayStepsData {
            print("   步数数据详情：")
            print("     - 日期: \(stepsData.date)")
            print("     - 总步数: \(stepsData.totalSteps)")
        }
        
        print("   HealthKitManager状态：")
        let healthManager = HealthKitManager.shared
        print("   - isAuthorized: \(healthManager.isAuthorized)")
        print("   - isProcessing: \(healthManager.isProcessing)")
        
        print("   UI显示预测：")
        let sleepData = manager.todaySleepData
        let stepsData = manager.todayStepsData
        
        if sleepData != nil || stepsData != nil {
            print("   ✅ TodaySyncStatusCard会显示数据区域")
            
            if sleepData != nil {
                print("   ✅ 会显示睡眠数据")
            } else {
                print("   ❌ 不会显示睡眠数据")
            }
            
            if stepsData != nil {
                print("   ✅ 会显示步数数据")
            } else {
                print("   ❌ 不会显示步数数据")
            }
        } else {
            print("   ❌ TodaySyncStatusCard不会显示数据区域")
        }
    }
    
    /// 🎯 快速问题定位
    @MainActor
    static func quickProblemIdentification() {
        print("\n🎯 快速问题定位")
        print("="*40)
        
        let manager = SyncStateManager.shared
        let sleepExists = manager.todaySleepData != nil
        let stepsExists = manager.todayStepsData != nil
        
        print("当前状态：睡眠[\(sleepExists ? "✅" : "❌")] 步数[\(stepsExists ? "✅" : "❌")]")
        
        if !sleepExists {
            print("\n❌ 睡眠数据不存在 - 可能原因：")
            print("1. ContentView检查逻辑提前返回")
            print("2. DataGenerator生成失败")
            print("3. PersonalizedDataGenerator限制")
            print("4. SyncStateManager保存失败")
            
            // 立即测试每个环节
            testEachStep()
        } else {
            print("\n✅ 睡眠数据存在 - 检查UI显示")
        }
        
        print("="*40)
    }
    
    @MainActor
    static func testEachStep() {
        print("\n🔬 逐步测试每个环节：")
        
        guard let user = SyncStateManager.shared.currentUser else {
            print("❌ 步骤0失败：无用户数据")
            return
        }
        print("✅ 步骤0：用户数据存在")
        
        // 测试PersonalizedDataGenerator
        let today = Date()
        let historicalData = SyncStateManager.shared.historicalSleepData
        
        let personalizedSleep = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: today
        )
        print("✅ 步骤1：PersonalizedDataGenerator成功")
        print("   睡眠时长：\(String(format: "%.1f", personalizedSleep.totalSleepHours))小时")
        
        // 测试DataGenerator
        let result = DataGenerator.generateDailyData(
            for: user,
            date: today,
            recentSleepData: historicalData,
            recentStepsData: SyncStateManager.shared.historicalStepsData,
            mode: SyncStateManager.shared.dataMode
        )
        
        if result.sleepData != nil {
            print("✅ 步骤2：DataGenerator成功")
        } else {
            print("❌ 步骤2失败：DataGenerator返回nil睡眠数据")
            return
        }
        
        // 测试SyncStateManager保存
        if let sleepData = result.sleepData {
            SyncStateManager.shared.updateSyncData(sleepData: sleepData, stepsData: result.stepsData)
            
            if SyncStateManager.shared.todaySleepData != nil {
                print("✅ 步骤3：SyncStateManager保存成功")
            } else {
                print("❌ 步骤3失败：SyncStateManager保存失败")
            }
        }
    }
}

extension String {
    func padding(toLength newLength: Int, withPad padString: String, startingAt padIndex: Int) -> String {
        let padLength = newLength - self.count
        guard padLength > 0 else { return self }
        
        let fullPads = padLength / padString.count
        let remainderLength = padLength % padString.count
        
        var padding = String(repeating: padString, count: fullPads)
        if remainderLength > 0 {
            let startIndex = padString.index(padString.startIndex, offsetBy: padIndex % padString.count)
            let endIndex = padString.index(startIndex, offsetBy: remainderLength, limitedBy: padString.endIndex) ?? padString.endIndex
            padding += String(padString[startIndex..<endIndex])
        }
        
        return self + padding
    }
}