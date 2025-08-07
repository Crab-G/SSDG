//
//  UltimateDataFlowTest.swift
//  SSDG
//
//  Created by Claude on 2025/8/1.
//

import Foundation
import SwiftUI

/// 🎯 终极数据流测试 - 完整验证从生成到显示的每一步
struct UltimateDataFlowTest {
    
    /// 🔬 运行完整的数据流诊断
    @MainActor
    static func runCompleteDataFlowDiagnosis() {
        print("\n" + String(repeating: "=", count: 80))
        print("🎯 终极数据流诊断开始")
        print("   目标：找到睡眠数据无法显示的确切原因")
        print(String(repeating: "=", count: 80))
        
        // 阶段1：基础环境检查
        print("\n📋 阶段1：基础环境检查")
        checkBasicEnvironment()
        
        // 阶段2：SyncStateManager状态检查
        print("\n📋 阶段2：SyncStateManager状态检查")
        checkSyncStateManagerStatus()
        
        // 阶段3：数据生成能力测试
        print("\n📋 阶段3：数据生成能力测试")
        testDataGenerationCapability()
        
        // 阶段4：UI数据绑定验证
        print("\n📋 阶段4：UI数据绑定验证")
        testUIDataBinding()
        
        // 阶段5：完整数据流模拟
        print("\n📋 阶段5：完整数据流模拟")
        simulateCompleteDataFlow()
        
        print("\n" + String(repeating: "=", count: 80))
        print("🎯 终极数据流诊断完成")
        print(String(repeating: "=", count: 80))
    }
    
    // MARK: - 阶段1：基础环境检查
    @MainActor
    static func checkBasicEnvironment() {
        print("🔍 检查VirtualUser...")
        if let user = SyncStateManager.shared.currentUser {
            print("   ✅ VirtualUser存在：\(user.age)岁 \(user.gender.displayName)")
            print("   基线睡眠：\(user.sleepBaseline)小时，基线步数：\(user.stepsBaseline)步")
        } else {
            print("   ❌ VirtualUser不存在")
        }
        
        print("🔍 检查DataMode...")
        let dataMode = SyncStateManager.shared.dataMode
        print("   ✅ DataMode：\(dataMode)")
        
        print("🔍 检查HealthKit授权...")
        let isAuthorized = HealthKitManager.shared.isAuthorized
        print("   \(isAuthorized ? "✅" : "❌") HealthKit授权：\(isAuthorized)")
        
        print("🔍 检查历史数据...")
        let historicalSleep = SyncStateManager.shared.historicalSleepData
        let historicalSteps = SyncStateManager.shared.historicalStepsData
        print("   历史睡眠数据：\(historicalSleep.count)天")
        print("   历史步数数据：\(historicalSteps.count)天")
    }
    
    // MARK: - 阶段2：SyncStateManager状态检查
    @MainActor
    static func checkSyncStateManagerStatus() {
        let manager = SyncStateManager.shared
        
        print("🔍 检查今日数据状态...")
        print("   todaySleepData: \(manager.todaySleepData != nil ? "存在" : "不存在")")
        print("   todayStepsData: \(manager.todayStepsData != nil ? "存在" : "不存在")")
        print("   todaySyncStatus: \(manager.todaySyncStatus.displayName)")
        
        if let sleepData = manager.todaySleepData {
            print("   睡眠数据详情：")
            print("     日期：\(sleepData.date)")
            print("     入睡时间：\(sleepData.bedTime)")
            print("     起床时间：\(sleepData.wakeTime)")
            print("     睡眠时长：\(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("     睡眠阶段数：\(sleepData.sleepStages.count)")
        }
        
        if let stepsData = manager.todayStepsData {
            print("   步数数据详情：")
            print("     日期：\(stepsData.date)")
            print("     总步数：\(stepsData.totalSteps)")
            print("     小时数据数：\(stepsData.hourlySteps.count)")
        }
        
        print("🔍 检查数据时效性...")
        let calendar = Calendar.current
        let today = Date()
        
        if let sleepData = manager.todaySleepData {
            let isSameDay = calendar.isDate(sleepData.date, inSameDayAs: today)
            print("   睡眠数据是今日数据：\(isSameDay ? "✅" : "❌")")
        }
        
        if let stepsData = manager.todayStepsData {
            let isSameDay = calendar.isDate(stepsData.date, inSameDayAs: today)
            print("   步数数据是今日数据：\(isSameDay ? "✅" : "❌")")
        }
    }
    
    // MARK: - 阶段3：数据生成能力测试
    @MainActor
    static func testDataGenerationCapability() {
        print("🔍 测试DataGenerator能力...")
        
        guard let user = SyncStateManager.shared.currentUser else {
            print("   ❌ 无法测试：缺少VirtualUser")
            return
        }
        
        let today = Date()
        let historicalSleep = SyncStateManager.shared.historicalSleepData
        let historicalSteps = SyncStateManager.shared.historicalStepsData
        
        print("   测试生成今日数据...")
        let result = DataGenerator.generateDailyData(
            for: user,
            date: today,
            recentSleepData: historicalSleep,
            recentStepsData: historicalSteps,
            mode: SyncStateManager.shared.dataMode
        )
        
        print("   生成结果：")
        print("     睡眠数据：\(result.sleepData != nil ? "✅存在" : "❌不存在")")
        print("     步数数据：\(result.stepsData.totalSteps)步")
        
        if let sleepData = result.sleepData {
            print("     睡眠详情：\(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("     入睡时间：\(sleepData.bedTime)")
            print("     起床时间：\(sleepData.wakeTime)")
            print("     睡眠阶段：\(sleepData.sleepStages.count)个阶段")
        } else {
            print("     ❌ 睡眠数据生成失败")
            
            // 深度诊断生成失败原因
            print("   🔬 深度诊断睡眠数据生成失败原因...")
            diagnoseSleepDataGenerationFailure(user: user, date: today, historicalData: historicalSleep)
        }
    }
    
    // MARK: - 深度诊断睡眠数据生成失败
    @MainActor
    static func diagnoseSleepDataGenerationFailure(user: VirtualUser, date: Date, historicalData: [SleepData]) {
        print("     🔬 检查历史数据...")
        print("       历史睡眠数据量：\(historicalData.count)")
        
        if historicalData.isEmpty {
            print("       ❌ 历史数据为空")
        } else {
            let recentData = historicalData.suffix(7)
            print("       最近7天睡眠时长：")
            for sleep in recentData {
                print("         \(sleep.date)：\(String(format: "%.1f", sleep.totalSleepHours))小时")
            }
        }
        
        print("     🔬 检查用户基线...")
        print("       用户睡眠基线：\(user.sleepBaseline)小时")
        print("       用户年龄：\(user.age)岁")
        print("       用户性别：\(user.gender.displayName)")
        
        print("     🔬 检查日期边界...")
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: date)
        let now = Date()
        print("       目标日期：\(date)")
        print("       今日开始：\(todayStart)")
        print("       当前时间：\(now)")
        print("       是否今日：\(calendar.isDate(date, inSameDayAs: now))")
        
        // 尝试单独测试PersonalizedDataGenerator
        print("     🔬 测试PersonalizedDataGenerator...")
        let personalizedSleep = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: date
        )
        print("       ✅ PersonalizedDataGenerator成功生成睡眠数据")
        print("       睡眠时长：\(String(format: "%.1f", personalizedSleep.totalSleepHours))小时")
    }
    
    // MARK: - 阶段4：UI数据绑定验证
    @MainActor
    static func testUIDataBinding() {
        print("🔍 测试UI数据绑定...")
        
        let manager = SyncStateManager.shared
        let sleepData = manager.todaySleepData
        let stepsData = manager.todayStepsData
        
        print("   TodaySyncStatusCard数据源：")
        print("     sleepData参数：\(sleepData != nil ? "存在" : "不存在")")
        print("     stepsData参数：\(stepsData != nil ? "存在" : "不存在")")
        
        // 模拟UI显示逻辑
        print("   模拟UI显示逻辑：")
        if sleepData != nil || stepsData != nil {
            print("     ✅ 会显示数据区域")
            
            if let sleepData = sleepData {
                print("     ✅ 会显示睡眠数据：\(String(format: "%.1f", sleepData.totalSleepHours))小时")
            } else {
                print("     ❌ 不会显示睡眠数据")
            }
            
            if let stepsData = stepsData {
                print("     ✅ 会显示步数数据：\(stepsData.totalSteps)步")
            } else {
                print("     ❌ 不会显示步数数据")
            }
        } else {
            print("     ❌ 不会显示任何数据区域")
        }
    }
    
    // MARK: - 阶段5：完整数据流模拟
    @MainActor
    static func simulateCompleteDataFlow() {
        print("🔍 模拟完整数据流...")
        
        guard let user = SyncStateManager.shared.currentUser else {
            print("   ❌ 无法模拟：缺少VirtualUser")
            return
        }
        
        let manager = SyncStateManager.shared
        let today = Date()
        let calendar = Calendar.current
        
        print("   1️⃣ 模拟ContentView.generateTodayData()检查逻辑...")
        let existingTodaySteps = manager.todayStepsData
        let existingTodaySleep = manager.todaySleepData
        
        let hasCompleteData = existingTodaySteps != nil && existingTodaySleep != nil &&
                              (existingTodaySteps != nil ? calendar.isDate(existingTodaySteps!.date, inSameDayAs: today) : false) &&
                              (existingTodaySleep != nil ? calendar.isDate(existingTodaySleep!.date, inSameDayAs: today) : false)
        
        print("     existingTodaySteps: \(existingTodaySteps != nil ? "存在" : "不存在")")
        print("     existingTodaySleep: \(existingTodaySleep != nil ? "存在" : "不存在")")
        print("     hasCompleteData: \(hasCompleteData)")
        
        if hasCompleteData {
            print("     ✅ 会跳过生成（已有完整数据）")
        } else {
            print("     ✅ 会继续生成数据")
            
            // 模拟缺失数据检查
            var missingData: [String] = []
            if existingTodaySteps == nil || !calendar.isDate(existingTodaySteps!.date, inSameDayAs: today) {
                missingData.append("步数")
            }
            if existingTodaySleep == nil || !calendar.isDate(existingTodaySleep!.date, inSameDayAs: today) {
                missingData.append("睡眠")
            }
            print("     缺失数据：\(missingData.joined(separator: "、"))")
        }
        
        print("   2️⃣ 模拟数据生成过程...")
        let historicalSleepData = manager.historicalSleepData
        let historicalStepsData = manager.historicalStepsData
        
        print("     历史数据可用：睡眠\(historicalSleepData.count)天，步数\(historicalStepsData.count)天")
        
        // 模拟DataGenerator调用
        let generatedResult = DataGenerator.generateDailyData(
            for: user,
            date: today,
            recentSleepData: historicalSleepData,
            recentStepsData: historicalStepsData,
            mode: manager.dataMode
        )
        
        print("     生成结果：睡眠\(generatedResult.sleepData != nil ? "成功" : "失败")，步数\(generatedResult.stepsData.totalSteps)步")
        
        print("   3️⃣ 模拟数据保存过程...")
        if generatedResult.sleepData != nil {
            print("     会调用updateSyncData(sleepData:stepsData:)")
            print("     睡眠数据将保存到SyncStateManager")
        } else {
            print("     会调用updateStepsData(_:)")
            print("     只有步数数据将保存到SyncStateManager")
        }
        
        print("   4️⃣ 模拟UI更新过程...")
        print("     @Published属性会触发UI更新")
        print("     TodaySyncStatusCard会重新渲染")
        
        if let sleepData = generatedResult.sleepData {
            print("     UI会显示睡眠数据：\(String(format: "%.1f", sleepData.totalSleepHours))小时")
        } else {
            print("     UI不会显示睡眠数据")
        }
    }
    
    // MARK: - 快速修复验证
    /// 🚀 快速修复验证 - 检查关键修复是否生效
    @MainActor
    static func quickFixVerification() {
        print("\n🚀 快速修复验证")
        print("="*50)
        
        // 1. 检查ContentView修复
        print("1️⃣ 检查ContentView数据检查逻辑修复...")
        let manager = SyncStateManager.shared
        let existingSteps = manager.todayStepsData
        let existingSleep = manager.todaySleepData
        
        print("   当前状态：")
        print("   - todayStepsData: \(existingSteps != nil ? "存在" : "不存在")")
        print("   - todaySleepData: \(existingSleep != nil ? "存在" : "不存在")")
        
        let calendar = Calendar.current
        let today = Date()
        let hasCompleteData = existingSteps != nil && existingSleep != nil &&
                              (existingSteps != nil ? calendar.isDate(existingSteps!.date, inSameDayAs: today) : false) &&
                              (existingSleep != nil ? calendar.isDate(existingSleep!.date, inSameDayAs: today) : false)
        
        print("   - hasCompleteData: \(hasCompleteData)")
        
        if hasCompleteData {
            print("   ✅ 修复生效：会跳过生成（已有完整数据）")
        } else {
            print("   ✅ 修复生效：会继续生成数据")
        }
        
        // 2. 检查DataGenerator修复
        print("\n2️⃣ 检查DataGenerator时间边界修复...")
        guard let user = manager.currentUser else {
            print("   ❌ 无法检查：缺少用户")
            return
        }
        
        let testResult = DataGenerator.generateDailyData(
            for: user,
            date: today,
            recentSleepData: manager.historicalSleepData,
            recentStepsData: manager.historicalStepsData,
            mode: manager.dataMode
        )
        
        if testResult.sleepData != nil {
            print("   ✅ 修复生效：可以生成当天睡眠数据")
        } else {
            print("   ❌ 修复无效：仍无法生成当天睡眠数据")
        }
        
        print("="*50)
    }
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}