//
//  RunDiagnostics.swift
//  SSDG
//
//  Created by Claude on 2025/8/1.
//

import Foundation

/// 🚀 运行所有诊断测试的入口
struct RunDiagnostics {
    
    /// 🎯 运行完整诊断
    @MainActor
    static func runAll() {
        print("🚀 开始运行完整睡眠数据诊断...")
        print("基于CRITICAL_FIX_BREAKTHROUGH.md的分析结果")
        
        // 1. 快速问题定位
        FinalDiagnosticTest.quickProblemIdentification()
        
        // 2. 快速修复验证
        UltimateDataFlowTest.quickFixVerification()
        
        // 3. 完整诊断测试
        FinalDiagnosticTest.runCompleteTest()
        
        print("\n✅ 所有诊断测试完成")
        print("如果问题仍然存在，请检查控制台输出中的具体错误信息")
    }
    
    /// 🔥 强制修复模式
    @MainActor
    static func forceFixMode() {
        print("🔥 强制修复模式启动...")
        
        // 1. 清理所有今日数据
        print("1️⃣ 清理今日数据...")
        SyncStateManager.shared.resetTodayData()
        
        // 2. 确保有用户和历史数据
        print("2️⃣ 检查基础数据...")
        if SyncStateManager.shared.currentUser == nil {
            print("❌ 缺少用户数据，请先创建用户")
            return
        }
        
        if SyncStateManager.shared.historicalSleepData.isEmpty {
            print("⚠️ 缺少历史数据，将生成测试数据")
            generateTestHistoricalData(for: SyncStateManager.shared.currentUser!)
        }
        
        // 3. 强制生成今日数据
        print("3️⃣ 强制生成今日数据...")
        let user = SyncStateManager.shared.currentUser!
        let today = Date()
        let manager = SyncStateManager.shared
        
        let result = DataGenerator.generateDailyData(
            for: user,
            date: today,
            recentSleepData: manager.historicalSleepData,
            recentStepsData: manager.historicalStepsData,
            mode: manager.dataMode
        )
        
        if let sleepData = result.sleepData {
            manager.updateSyncData(sleepData: sleepData, stepsData: result.stepsData)
            print("✅ 强制修复成功！")
            print("   睡眠：\(String(format: "%.1f", sleepData.totalSleepHours))小时")
            print("   步数：\(result.stepsData.totalSteps)步")
        } else {
            print("❌ 强制修复失败，睡眠数据仍无法生成")
            
            // 最后手段：手动创建睡眠数据
            print("🆘 使用紧急手段：手动创建睡眠数据")
            createEmergencySleepData(for: user, date: today)
        }
    }
    
    /// 🆘 紧急手段：手动创建睡眠数据
    @MainActor
    static func createEmergencySleepData(for user: VirtualUser, date: Date) {
        let calendar = Calendar.current
        
        // 创建基础睡眠时间
        let bedTime = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: date) ?? date
        let wakeTime = calendar.date(byAdding: .hour, value: Int(user.sleepBaseline), to: bedTime) ?? date
        
        // 创建睡眠阶段
        let sleepStage = SleepStage(
            stage: .light,
            startTime: bedTime,
            endTime: wakeTime
        )
        
        // 创建睡眠数据
        let emergencySleepData = SleepData(
            date: date,
            bedTime: bedTime,
            wakeTime: wakeTime,
            sleepStages: [sleepStage]
        )
        
        // 创建步数数据
        let emergencyStepsData = StepsData(
            date: date,
            hourlySteps: [HourlySteps(
                hour: 12,
                steps: user.stepsBaseline,
                startTime: date,
                endTime: calendar.date(byAdding: .hour, value: 1, to: date) ?? date
            )]
        )
        
        // 直接更新到SyncStateManager
        SyncStateManager.shared.updateSyncData(sleepData: emergencySleepData, stepsData: emergencyStepsData)
        
        print("🆘 紧急睡眠数据创建完成")
        print("   睡眠时长：\(String(format: "%.1f", emergencySleepData.totalSleepHours))小时")
        print("   入睡时间：\(bedTime)")
        print("   起床时间：\(wakeTime)")
        print("   步数：\(emergencyStepsData.totalSteps)步")
        
        // 验证是否成功
        if SyncStateManager.shared.todaySleepData != nil {
            print("✅ 紧急修复成功！睡眠数据现在应该可以在UI中显示")
        } else {
            print("❌ 紧急修复失败，问题可能更深层")
        }
    }
    
    /// 生成测试历史数据
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
}

// MARK: - 便捷测试函数
@MainActor
func runQuickDiagnosis() {
    FinalDiagnosticTest.quickProblemIdentification()
}

@MainActor
func runFullDiagnosis() {
    RunDiagnostics.runAll()
}

@MainActor
func forceFixSleepData() {
    RunDiagnostics.forceFixMode()
}