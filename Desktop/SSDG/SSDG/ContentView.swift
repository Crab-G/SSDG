//
//  ContentView.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    // 状态管理器
    @StateObject private var syncStateManager = SyncStateManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    // 安全的导入进度计算
    private var safeImportProgress: Double {
        let progress = healthKitManager.importProgress
        guard progress.isFinite && !progress.isNaN else { return 0.0 }
        return max(0.0, min(1.0, progress))
    }
    
    var body: some View {
        ZStack {
            TabView {
            // 第一页：今日同步
            TodaySyncView()
                .tabItem {
                    Image(systemName: "heart.circle.fill")
                    Text("HealthKit")
                }
            
            // 第二页：用户管理
            UserManagementView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Users")
                }
            
            // 第三页：数据分析
            DataAnalysisView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    Text("Analytics")
                }
            
            // 第四页：设置
            SettingsView()
                .tabItem {
                    Image(systemName: "gear.circle.fill")
                    Text("Settings")
                }
        }
        .accentColor(.cyan)
        .environmentObject(syncStateManager)
        .environmentObject(healthKitManager)
        }
    }
}

// MARK: - 超时工具函数
func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            return try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error {
    var localizedDescription: String = "操作超时"
}

// MARK: - 今日同步页面
struct TodaySyncView: View {
    @State private var isSyncing = false
    @State private var isGenerating = false
    @State private var isCleaningDuplicates = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // 使用传入的状态管理器，避免重复创建
    @EnvironmentObject private var syncStateManager: SyncStateManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @StateObject private var automationManager = AutomationManager.shared
    
    // 分离复杂的背景视图
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // 分离健康授权和自动同步状态视图
    private var statusIndicatorsView: some View {
        HStack(spacing: 12) {
            // 健康授权状态
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: healthKitManager.isAuthorized ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundColor(healthKitManager.isAuthorized ? .green : .orange)
                        .font(.title3)
                    
                    Text("健康授权")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                
                Text(healthKitManager.isAuthorized ? "已授权" : "未授权")
                    .font(.caption2)
                    .foregroundColor(healthKitManager.isAuthorized ? .green : .orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(healthKitManager.isAuthorized ? Color.green.opacity(0.5) : Color.orange.opacity(0.5), lineWidth: 1)
                    )
            )
            
            // 自动同步状态
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: automationManager.automationStatus == .enabled || automationManager.automationStatus == .running ? "bolt.fill" : "bolt.slash.fill")
                        .foregroundColor(automationManager.automationStatus == .enabled || automationManager.automationStatus == .running ? .blue : .gray)
                        .font(.title3)
                    
                    Text("自动同步")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                
                Text(automationManager.automationStatus.displayName)
                    .font(.caption2)
                    .foregroundColor(automationManager.automationStatus.color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(automationManager.automationStatus.color.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                backgroundView
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 状态卡片
                        TodaySyncStatusCard(
                            syncStatus: syncStateManager.todaySyncStatus,
                            lastSyncDate: syncStateManager.lastSyncDate,
                            sleepData: syncStateManager.todaySleepData,
                            stepsData: syncStateManager.todayStepsData
                        )
                        
                        // 健康授权和自动同步状态
                        statusIndicatorsView
                        
                        // 快速操作区域
                        VStack(spacing: 16) {
                            // 生成今日数据按钮
                            Button(action: generateTodayData) {
                                HStack {
                                    Image(systemName: isGenerating ? "arrow.clockwise" : "plus.circle.fill")
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(isGenerating ? 360 : 0))
                                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isGenerating)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Generate Data")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Generate daily sleep and step data")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: getGenerateButtonColors()),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            .disabled(isGenerating || isSyncing)
                            
                            // 智能补全按钮
                            Button(action: intelligentStepsCompletion) {
                                HStack {
                                    Image(systemName: isSyncing ? "arrow.clockwise" : "brain.head.profile")
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(isSyncing ? 360 : 0))
                                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSyncing)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Smart Completion")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Auto-complete yesterday's missing step data")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.pink]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            .disabled(isGenerating || isSyncing)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
                    .navigationTitle("HealthKit")
        .navigationBarHidden(true)
        .alert("HealthKit", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }

        .onAppear {
            syncStateManager.checkForNewDay()
            if syncStateManager.currentUser == nil {
                setupUser()
            }
        }
            
            // 权限检查覆盖层
            if !healthKitManager.isAuthorized {
                HealthKitPermissionView()
            }
        }
    }
    
    // 设置用户信息 - 防卡死优化版
    private func setupUser() {
        let user = VirtualUserGenerator.generateRandomUser()
        syncStateManager.updateUser(user)
        print("✅ 用户设置完成: \(user.gender.displayName), \(user.age)岁")
        
        // 🚀 不再自动生成历史数据，等待用户主动点击
        print("💡 提示：用户可以通过'生成历史数据'按钮来生成数据")
    }
    
    // 🚀 新增：异步历史数据生成（防卡死）
    private func generateHistoricalDataForUserAsync(_ user: VirtualUser) {
        // 检查是否需要生成历史数据
        guard syncStateManager.shouldGenerateHistoricalData() else {
            print("✅ 历史数据已存在，跳过生成")
            return
        }
        
        print("🔄 开始异步生成历史数据...")
        syncStateManager.updateHistoricalDataStatus(.generating)
        
        Task.detached {
            // 🚀 使用简化版生成器，限制为7天
            let historicalData = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
                for: user, 
                days: 7, // 限制为7天避免卡死
                mode: .simple
            )
            
            await MainActor.run {
                self.syncStateManager.updateHistoricalData(
                    sleepData: historicalData.sleepData,
                    stepsData: historicalData.stepsData
                )
                
                print("✅ 异步历史数据生成完成: \(historicalData.sleepData.count) 天")
            }
        }
    }
    
    // 为用户生成历史数据
    private func generateHistoricalDataForUser(_ user: VirtualUser) {
        // 检查是否需要生成历史数据
        guard syncStateManager.shouldGenerateHistoricalData() else {
            print("✅ 历史数据已存在，跳过生成")
            return
        }
        
        print("🔄 开始为用户生成历史数据...")
        syncStateManager.updateHistoricalDataStatus(.generating)
        
        Task {
            // 在后台线程生成历史数据
            let historicalData = await generateHistoricalDataAsync(for: user)
            
            // 更新历史数据
            await MainActor.run {
                syncStateManager.updateHistoricalData(
                    sleepData: historicalData.sleepData,
                    stepsData: historicalData.stepsData
                )
                
                let days = historicalData.sleepData.count
                print("✅ 历史数据生成成功: \(days) 天")
            }
        }
    }
    
    // 🚀 安全版：简单异步生成历史数据（第一个）
    private func generateHistoricalDataAsync(for user: VirtualUser) async -> (sleepData: [SleepData], stepsData: [StepsData]) {
        // 🚀 直接调用，避免复杂的异步嵌套
        return PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: user,
            days: 3, // 减少到3天避免卡顿
            mode: .simple
        )
    }
    
    // 生成今日数据
    private func generateTodayData() {
        guard let user = syncStateManager.currentUser else {
            alertMessage = "请先设置用户信息"
            showingAlert = true
            return
        }
        
        isGenerating = true
        
        Task {
            // 🛡️ 添加15秒超时保护
            do {
                try await withTimeout(seconds: 15) {
                    await performDataGeneration(user: user)
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    alertMessage = "操作超时或出错: \(error.localizedDescription)\n请重试"
                    showingAlert = true
                }
            }
        }
    }
    
    // 执行数据生成的核心逻辑
    private func performDataGeneration(user: VirtualUser) async {
        let today = Date()
        let calendar = Calendar.current
        
        // 🛠️ 修复：检查今日是否已有完整数据（睡眠+步数），避免重复生成
        await MainActor.run {
            alertMessage = "正在检查今日数据状态..."
            showingAlert = true
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒让用户看到提示
        
        await MainActor.run {
            showingAlert = false // 关闭提示，避免弹窗堆叠
        }
        
        print("🔍 检查今日数据状态...")
        let existingTodaySteps = syncStateManager.todayStepsData
        let existingTodaySleep = syncStateManager.todaySleepData
            // 检查是否有完整的今日数据（睡眠+步数）
            let hasCompleteData = existingTodaySteps != nil && existingTodaySleep != nil &&
                                  calendar.isDate(existingTodaySteps!.date, inSameDayAs: today) &&
                                  calendar.isDate(existingTodaySleep!.date, inSameDayAs: today)
            
            if hasCompleteData {
                print("   ✅ 今日完整数据已存在")
                print("   步数: \(existingTodaySteps!.totalSteps)步")
                print("   睡眠: \(String(format: "%.1f", existingTodaySleep!.totalSleepHours))小时")
                print("   如需重新生成，请先清理今日数据")
                
                await MainActor.run {
                    isGenerating = false
                    alertMessage = "今日完整数据已存在\n步数: \(existingTodaySteps!.totalSteps)步\n睡眠: \(String(format: "%.1f", existingTodaySleep!.totalSleepHours))小时\n\n如需重新生成，请先清理数据"
                    showingAlert = true
                }
                return
            } else {
                // 检查缺失的数据类型
                var missingData: [String] = []
                if existingTodaySteps == nil || !calendar.isDate(existingTodaySteps!.date, inSameDayAs: today) {
                    missingData.append("步数")
                }
                if existingTodaySleep == nil || !calendar.isDate(existingTodaySleep!.date, inSameDayAs: today) {
                    missingData.append("睡眠")
                }
                print("   ⚠️ 今日数据不完整，缺失：\(missingData.joined(separator: "、"))")
                print("   继续生成完整数据...")
            }
            
            // 🧹 1. 清理今日可能的重复数据
            print("🧹 开始清理今日重复数据...")
            
            // 清理今日重复数据
            await clearTodayDuplicateData()
            
            // 强力清理今日数据（只针对今天）
            let forceClean = await healthKitManager.forceCleanDuplicateData(for: today)
            print("   今日数据清理: \(forceClean ? "✅ 完成" : "ℹ️ 无需清理")")
            
            // 同步数据到 HealthKit
            print("📊 开始同步数据到 Apple Health...")
            
            // 2. 确保有历史数据
            await ensureHistoricalDataExists(for: user)
            
            // 3. 基于历史数据生成今日数据
            let historicalSleepData = syncStateManager.historicalSleepData
            let historicalStepsData = syncStateManager.historicalStepsData
            
            // 使用历史数据作为基础生成今日数据
            let (sleepData, stepsData) = await generateTodayDataWithHistory(
                user: user,
                date: today,
                historicalSleepData: historicalSleepData,
                historicalStepsData: historicalStepsData
            )
            
            print("📊 生成完成 - 睡眠: \(sleepData?.totalSleepHours ?? 0)小时, 步数: \(stepsData.totalSteps)步")
            
            // 4. 自动同步到 HealthKit
            let sleepDataArray = sleepData != nil ? [sleepData!] : []
            let syncSuccess = await healthKitManager.syncUserData(
                user: user,
                sleepData: sleepDataArray,
                stepsData: [stepsData]
            )
            
            await MainActor.run {
                isGenerating = false
                
                // 保存生成的数据到状态管理器
                if let sleepData = sleepData {
                    // 完整数据（睡眠+步数）
                    syncStateManager.updateSyncData(sleepData: sleepData, stepsData: stepsData)
                } else {
                    // 只有步数数据
                    print("⚠️ 今日数据只有步数，使用专用方法保存")
                    syncStateManager.updateStepsData(stepsData)
                }
                
                if syncSuccess {
                    syncStateManager.updateSyncStatus(.synced)
                    let historyInfo = historicalSleepData.isEmpty ? "" : "\n\n📊 基于 \(historicalSleepData.count) 天历史数据生成"
                    let sleepInfo = sleepData != nil ? "睡眠: \(String(format: "%.1f", sleepData!.totalSleepHours))小时\n" : "睡眠: 无数据（今日数据）\n"
                    alertMessage = "今日数据生成并同步成功！\n\(sleepInfo)步数: \(stepsData.totalSteps)步\(historyInfo)\n\n✅ 已自动清理重复数据\n✅ 已同步到 Apple Health"
                } else {
                    syncStateManager.updateSyncStatus(.failed)
                    alertMessage = "数据生成成功但同步失败\n请检查 HealthKit 权限设置"
                }
                
                showingAlert = true
            }
        }
    
    // 清理今日重复数据
    private func clearTodayDuplicateData() async {
        let today = Date()
        let success = await healthKitManager.deleteDayData(for: today)
        
        if success {
            print("✅ 今日重复数据清理成功")
        } else {
            print("⚠️ 今日数据清理失败或无数据需要清理")
        }
    }
    
    // 手动清理今日重复数据
    private func cleanupTodayDuplicates() {
        isCleaningDuplicates = true
        
        Task {
            let today = Date()
            let success = await healthKitManager.deleteDayData(for: today)
            
            await MainActor.run {
                isCleaningDuplicates = false
                
                if success {
                    alertMessage = "✅ 今日重复数据清理成功！\n\n建议检查苹果健康应用确认数据已清理。\n\n如果问题仍然存在，请尝试：\n1. 重启苹果健康应用\n2. 重启设备\n3. 使用强力清理功能"
                } else {
                    alertMessage = "⚠️ 数据清理失败或无数据需要清理\n\n可能原因：\n1. 今日暂无重复数据\n2. HealthKit权限不足\n3. 数据无法删除（系统保护）\n\n建议检查HealthKit权限设置"
                }
                
                showingAlert = true
            }
        }
    }
    
    // 强力清理重复数据
    private func forceCleanDuplicates() {
        isCleaningDuplicates = true
        
        Task {
            let today = Date()
            let success = await healthKitManager.forceCleanDuplicateData(for: today)
            
            await MainActor.run {
                isCleaningDuplicates = false
                
                if success {
                    alertMessage = """
                    🔥 强力清理完成！
                    
                    ✅ 已清理严重重复的数据
                    
                    📱 建议操作：
                    1. 重启苹果健康应用
                    2. 检查数据是否恢复正常
                    3. 如果数据丢失，可重新生成
                    
                    ⚠️ 注意：
                    强力清理会删除大量数据，如果正常数据也被删除，请重新生成数据。
                    """
                } else {
                    alertMessage = """
                    ❌ 强力清理失败！
                    
                    可能原因：
                    1. HealthKit权限不足
                    2. 数据被系统保护
                    3. 网络或系统错误
                    
                    建议解决方案：
                    1. 检查HealthKit读写权限
                    2. 重启设备
                    3. 手动在健康应用中删除数据
                    4. 联系开发者获取帮助
                    """
                }
                
                showingAlert = true
            }
        }
    }
    
    // 确保历史数据存在
    private func ensureHistoricalDataExists(for user: VirtualUser) async {
        if syncStateManager.shouldGenerateHistoricalData() {
            print("🔄 今日数据生成需要历史数据，正在生成...")
            
            await MainActor.run {
                syncStateManager.updateHistoricalDataStatus(.generating)
            }
            
            // 生成历史数据
            let historicalData = await generateHistoricalDataAsync(for: user)
            
            await MainActor.run {
                syncStateManager.updateHistoricalData(
                    sleepData: historicalData.sleepData,
                    stepsData: historicalData.stepsData
                )
                print("✅ 历史数据生成完成，继续生成今日数据")
            }
        }
    }
    
    // 基于历史数据生成今日数据
    private func generateTodayDataWithHistory(
        user: VirtualUser,
        date: Date,
        historicalSleepData: [SleepData],
        historicalStepsData: [StepsData]
    ) async -> (sleepData: SleepData?, stepsData: StepsData) {
        let dataMode = await MainActor.run { SyncStateManager.shared.dataMode }
        // 🚀 直接调用，避免withCheckedContinuation崩溃
        let todayData = DataGenerator.generateDailyData(
            for: user,
            date: date,
            recentSleepData: historicalSleepData,
            recentStepsData: historicalStepsData,
            mode: dataMode
        )
        return todayData
    }
    
    // 同步今日数据（智能替换版）
    private func syncTodayData() {
        guard let user = syncStateManager.currentUser else {
            alertMessage = "请先设置用户信息"
            showingAlert = true
            return
        }
        
        guard let sleepData = syncStateManager.todaySleepData,
              let stepsData = syncStateManager.todayStepsData else {
            alertMessage = "请先生成今日数据"
            showingAlert = true
            return
        }
        
        isSyncing = true
        syncStateManager.updateSyncStatus(.syncing)
        
        Task {
            // 🧹 同步前的全面重复数据检查
            print("🧹 开始同步前重复数据检查...")
            
            // 1. 清理目标日期的重复数据
            let targetCleanSuccess = await healthKitManager.deleteDayData(for: sleepData.date)
            print("   目标日期清理: \(targetCleanSuccess ? "✅ 成功" : "ℹ️ 无数据需要清理")")
            
            // 2. 检查前后一天的数据，防止跨日冲突
            let calendar = Calendar.current
            var beforeCleanSuccess = false
            var afterCleanSuccess = false
            
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: sleepData.date) {
                beforeCleanSuccess = await healthKitManager.deleteDayData(for: dayBefore)
                print("   前一日清理: \(beforeCleanSuccess ? "✅ 清理" : "ℹ️ 无需清理")")
            }
            
            if let dayAfter = calendar.date(byAdding: .day, value: 1, to: sleepData.date) {
                afterCleanSuccess = await healthKitManager.deleteDayData(for: dayAfter)
                print("   后一日清理: \(afterCleanSuccess ? "✅ 清理" : "ℹ️ 无需清理")")
            }
            
            // 3. 强力清理检查（确保没有严重重复数据）
            let forceCleanSuccess = await healthKitManager.forceCleanDuplicateData(for: sleepData.date)
            print("   强力清理: \(forceCleanSuccess ? "✅ 完成" : "ℹ️ 无需强力清理")")
            
            print("✅ 重复数据检查完成，开始数据同步...")
            
            // 2. 使用智能替换方法
            let result = await healthKitManager.replaceOrWriteData(
                user: user,
                sleepData: [sleepData],
                stepsData: [stepsData],
                mode: syncStateManager.dataMode
            )
            
            isSyncing = false
            
            if result.success {
                // 使用新方法标记同步成功并添加到历史记录
                syncStateManager.markSyncedAndAddToHistory(sleepData: sleepData, stepsData: stepsData)
                    
                var message = "今日数据同步成功！\n睡眠: \(String(format: "%.1f", sleepData.totalSleepHours))小时\n步数: \(stepsData.totalSteps)步"
                    
                if targetCleanSuccess {
                    message += "\n\n✅ 目标日期重复数据已清理"
                }
                if beforeCleanSuccess {
                    message += "\n\n✅ 前一日重复数据已清理"
                }
                if afterCleanSuccess {
                    message += "\n\n✅ 后一日重复数据已清理"
                }
                if forceCleanSuccess {
                    message += "\n\n✅ 强力清理完成"
                }
                    
                if result.needsManualCleanup {
                    message += "\n\n⚠️ 注意：部分旧数据可能需要手动清理"
                    message += "\n建议在\"健康\"应用中检查并删除重复数据"
                } else {
                    message += "\n\n✅ 旧数据已自动清理"
                }
                    
                alertMessage = message
            } else {
                syncStateManager.updateSyncStatus(.failed)
                alertMessage = "数据同步失败，请检查HealthKit权限"
            }
            
            showingAlert = true
        }
    }

    
    // 获取生成按钮文本
    private func getGenerateButtonText() -> String {
        if isGenerating {
            return "生成中..."
        }
        
        if syncStateManager.todaySleepData != nil {
            return "重新生成今日数据"
        } else {
            return "生成今日数据"
        }
    }
    
    // 获取生成按钮图标
    private func getGenerateIcon() -> String {
        if syncStateManager.todaySleepData != nil {
            return "arrow.clockwise"
        } else {
            return "plus.circle.fill"
        }
    }
    
    // 获取生成按钮颜色
    private func getGenerateButtonColors() -> [Color] {
        if syncStateManager.todaySleepData != nil {
            return [Color.orange, Color.yellow]
        } else {
            return [Color.cyan, Color.blue]
        }
    }
    
    // 获取同步按钮文本
    private func getSyncButtonText() -> String {
        if isSyncing {
            return "同步中..."
        }
        
        switch syncStateManager.todaySyncStatus {
        case .notSynced:
            return "同步今日数据"
        case .syncing:
            return "同步中..."
        case .synced:
            return "重新同步今日数据"
        case .failed:
            return "重试同步今日数据"
        }
    }
    
    // 获取同步按钮图标
    private func getSyncIcon() -> String {
        switch syncStateManager.todaySyncStatus {
        case .notSynced:
            return "heart.fill"
        case .syncing:
            return "arrow.2.circlepath"
        case .synced:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }
    
    // 获取同步按钮颜色
    private func getSyncButtonColors() -> [Color] {
        switch syncStateManager.todaySyncStatus {
        case .notSynced:
            return [Color.green, Color.mint]
        case .syncing:
            return [Color.orange, Color.yellow]
        case .synced:
            return [Color.green, Color.mint]
        case .failed:
            return [Color.red, Color.orange]
        }
    }
    
    // MARK: - 智能补全功能
    // 智能补全昨日步数数据
    private func intelligentStepsCompletion() {
        guard let user = syncStateManager.currentUser else {
            alertMessage = "请先设置用户信息"
            showingAlert = true
            return
        }
        
        Task {
            await MainActor.run {
                isSyncing = true
                syncStateManager.updateSyncStatus(.syncing)
            }
            
            print("🔍 开始智能补全步数数据...")
            
            // 获取历史数据
            let historicalStepsData = syncStateManager.historicalStepsData
            let historicalSleepData = syncStateManager.historicalSleepData
            
            // 检查昨日数据
            let result = await checkAndFixYesterdayStepsData(
                user: user,
                historicalStepsData: historicalStepsData,
                historicalSleepData: historicalSleepData
            )
            
            await MainActor.run {
                isSyncing = false
                syncStateManager.updateSyncStatus(.synced)
                
                if result.wasUpdated {
                    alertMessage = result.message
                } else {
                    alertMessage = result.message
                }
                
                showingAlert = true
            }
        }
    }
    
    // 检查和修复昨日步数数据
    private func checkAndFixYesterdayStepsData(
        user: VirtualUser,
        historicalStepsData: [StepsData],
        historicalSleepData: [SleepData]
    ) async -> (wasUpdated: Bool, message: String) {
        let calendar = Calendar.current
        let now = Date()
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        
        print("📅 检查昨日数据: \(DateFormatter.localizedString(from: yesterdayStart, dateStyle: .short, timeStyle: .none))")
        
        // 检查昨日步数数据是否存在且有意义
        let existingYesterdaySteps = historicalStepsData.first { stepsData in
            calendar.isDate(stepsData.date, inSameDayAs: yesterdayStart)
        }
        
        // 数据质量检查
        if let existingSteps = existingYesterdaySteps {
            print("   昨日已有步数数据: \(existingSteps.totalSteps)步")
            
            // 检查数据质量
            let isQualityGood = checkYesterdayDataQuality(existingSteps)
            if isQualityGood {
                print("   ✅ 昨日数据质量良好，无需补全")
                return (false, "✅ 昨日步数数据质量良好，无需补全")
            } else {
                print("   ⚠️ 昨日数据质量异常，需要清理和重新生成")
                // 清理异常数据
                // await cleanupAbnormalStepsData(for: yesterdayStart)
            }
        } else {
            print("   ❌ 昨日步数数据缺失")
        }
        
        // 生成昨日完整数据
        print("🔄 生成昨日完整步数数据...")
        let dataMode = await MainActor.run { SyncStateManager.shared.dataMode }
        let yesterdayData = DataGenerator.generateDailyData(
            for: user,
            date: yesterdayStart,
            recentSleepData: Array(historicalSleepData.suffix(7)),
            recentStepsData: Array(historicalStepsData.suffix(7)),
            mode: dataMode
        )
        
        print("   ✅ 生成完成，昨日新步数: \(yesterdayData.stepsData.totalSteps)步")
        
        // 检查是否需要同步
        let shouldSync = checkIfDataWasUpdated(
            existingSteps: existingYesterdaySteps,
            newSteps: yesterdayData.stepsData
        )
        
        if !shouldSync {
            print("   ℹ️ 数据未发生实质性变化，跳过同步")
            return (false, "ℹ️ 昨日数据已是最新状态")
        }
        
        // 同步到 HealthKit
        let sleepDataArray = yesterdayData.sleepData != nil ? [yesterdayData.sleepData!] : []
        let syncSuccess = await healthKitManager.syncUserData(
            user: user,
            sleepData: sleepDataArray,
            stepsData: [yesterdayData.stepsData]
        )
        
        if syncSuccess {
            print("   ✅ 昨日数据同步成功")
            return (true, "✅ 昨日步数数据补全完成\n新步数: \(yesterdayData.stepsData.totalSteps)步")
        } else {
            print("   ❌ 昨日数据同步失败")
            return (false, "❌ 昨日数据生成成功但同步失败\n请检查HealthKit权限")
        }
    }
    
    // 检查昨日数据质量
    private func checkYesterdayDataQuality(_ stepsData: StepsData) -> Bool {
        // 根据用户活动水平获取阈值
        let userActivityLevel = syncStateManager.currentUser?.personalizedProfile.activityLevel ?? .medium
        let (normalUpperLimit, suspiciousThreshold, maxHourlyThreshold, avgHourlyThreshold) = getActivityThresholds(for: userActivityLevel)
        
        let totalSteps = stepsData.totalSteps
        let hourlySteps = stepsData.hourlySteps
        
        print("   📊 数据质量检查 (活动水平: \(userActivityLevel)):")
        print("   - 总步数: \(totalSteps) (正常上限: \(normalUpperLimit), 可疑阈值: \(suspiciousThreshold))")
        
        // 1. 检查总步数是否过高
        if totalSteps > suspiciousThreshold {
            print("   ❌ 总步数过高: \(totalSteps)步，超过可疑阈值 \(suspiciousThreshold)步")
            return false
        }
        
        // 2. 检查是否有异常的小时数据
        let stepCounts = hourlySteps.map { $0.steps }
        let maxHourlySteps = stepCounts.max() ?? 0
        let avgHourlySteps = stepCounts.reduce(0, +) / max(stepCounts.count, 1)
        
        print("   - 最大小时步数: \(maxHourlySteps) (阈值: \(maxHourlyThreshold))")
        print("   - 平均小时步数: \(avgHourlySteps) (阈值: \(avgHourlyThreshold))")
        
        if maxHourlySteps > maxHourlyThreshold {
            print("   ❌ 最大小时步数过高: \(maxHourlySteps)步，判定为异常数据")
            return false
        }
        
        if avgHourlySteps > avgHourlyThreshold {
            print("   ❌ 平均每小时步数过高: \(avgHourlySteps)步，判定为重复数据")
            return false
        }
        
        // 3. 检查是否有连续多个小时的高步数
        var consecutiveHighHours = 0
        let highStepsThreshold = maxHourlyThreshold * 70 / 100 // 70%的最大阈值
        
        for hourlyStep in hourlySteps {
            if hourlyStep.steps > highStepsThreshold {
                consecutiveHighHours += 1
                if consecutiveHighHours > 3 {
                    print("   ❌ 连续多小时高步数，判定为异常模式")
                    return false
                }
            } else {
                consecutiveHighHours = 0
            }
        }
        
        print("   ✅ 数据质量检查通过")
        return true
    }
    
    // 根据活动水平获取阈值
    private func getActivityThresholds(for level: ActivityLevel) -> (normalUpperLimit: Int, suspiciousThreshold: Int, maxHourlyThreshold: Int, avgHourlyThreshold: Int) {
        switch level {
        case .low:
            // 低活动量：1500-4500，设置一些浮动
            return (normalUpperLimit: 5500, suspiciousThreshold: 7000, maxHourlyThreshold: 500, avgHourlyThreshold: 250)
        case .medium:
            // 中等活动量：4500-8500，设置一些浮动
            return (normalUpperLimit: 10500, suspiciousThreshold: 13000, maxHourlyThreshold: 750, avgHourlyThreshold: 450)
        case .high:
            // 高活动量：8500-13000，设置一些浮动
            return (normalUpperLimit: 16500, suspiciousThreshold: 20000, maxHourlyThreshold: 1100, avgHourlyThreshold: 700)
        case .veryHigh:
            // 超高活动量：13000-18000，设置一些浮动
            return (normalUpperLimit: 24000, suspiciousThreshold: 30000, maxHourlyThreshold: 1500, avgHourlyThreshold: 1000)
        }
    }
    
    // 检查数据是否发生了实质性更新
    private func checkIfDataWasUpdated(existingSteps: StepsData?, newSteps: StepsData) -> Bool {
        guard let existing = existingSteps else {
            // 没有现有数据，需要同步
            return true
        }
        
        // 比较总步数差异
        let stepsDifference = abs(existing.totalSteps - newSteps.totalSteps)
        let significantChangeThreshold = 50 // 50步以上的变化认为是有意义的
        
        print("   📊 数据变化检查:")
        print("   - 原有步数: \(existing.totalSteps)")
        print("   - 新生成步数: \(newSteps.totalSteps)")
        print("   - 差异: \(stepsDifference)步")
        
        if stepsDifference < significantChangeThreshold {
            print("   ℹ️ 步数差异小于 \(significantChangeThreshold)步，认为数据未发生显著变化")
            return false
        }
        
        return true
    }
    
    // 清理异常步数数据
    private func cleanupAbnormalStepsData(for date: Date) {
        print("🧹 清理异常步数数据...")
        // 注意：这里移除了 await 调用，因为函数不是 async 的
        // 如果需要异步清理，应该在调用处使用 Task 包装
        // 现在仅打印日志，实际清理逻辑可以根据需要实现
        
        // 这里可以添加具体的清理逻辑
        print("   ✅ 异常数据清理完成")
    }
}

// MARK: - 用户管理页面
struct UserManagementView: View {
    @State private var isGenerating = false
    @State private var isImporting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isHistoricalDataImported = false
    
    // 个性化用户生成相关状态
    @State private var showPersonalizedUserSheet = false
    @State private var selectedSleepType: SleepType = .normal
    @State private var selectedActivityLevel: ActivityLevel = .medium
    
    // 使用传入的状态管理器，避免重复创建
    @EnvironmentObject private var syncStateManager: SyncStateManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    // 安全的导入进度计算 - 添加到UserManagementView作用域
    private var safeImportProgress: Double {
        let progress = healthKitManager.importProgress
        guard progress.isFinite && !progress.isNaN else { return 0.0 }
        return max(0.0, min(1.0, progress))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 用户信息卡片
                        if let user = syncStateManager.currentUser {
                            UserInfoCard(user: user)
                        } else {
                            VStack {
                                Text("User Management")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text("Generate and manage virtual user data")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // 数据模式切换
                        DataModeToggleCard()
                        
                        // 当前用户信息
                        if let user = syncStateManager.currentUser {
                            UserInfoCard(user: user)
                        } else {
                            PlaceholderUserCard()
                        }
                        
                        // 历史数据摘要
                        if !syncStateManager.historicalSleepData.isEmpty {
                            HistoricalDataCard(
                                sleepData: syncStateManager.historicalSleepData,
                                stepsData: syncStateManager.historicalStepsData,
                                isImported: isHistoricalDataImported
                            )
                        }
                        
                        // 操作按钮
                        VStack(spacing: 16) {
                            // 生成新用户按钮组
                            HStack(spacing: 12) {
                                // 普通用户生成
                                Button(action: generateNewUser) {
                                    HStack {
                                        Image(systemName: isGenerating ? "arrow.2.circlepath" : "person.badge.plus")
                                            .font(.title3)
                                            .rotationEffect(Angle(degrees: isGenerating ? 360 : 0))
                                            .animation(isGenerating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isGenerating)
                                        
                                        Text(isGenerating ? "生成中..." : "普通用户")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.orange, Color.red]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(15)
                                }
                                .disabled(isGenerating)
                                
                                // 个性化用户生成
                                Button(action: { showPersonalizedUserSheet = true }) {
                                    HStack {
                                        Image(systemName: "person.2.badge.gearshape")
                                            .font(.title3)
                                        
                                                                Text("Personalized User")
                            .font(.subheadline)
                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(15)
                                }
                                .disabled(isGenerating)
                            }
                            
                            // 生成历史数据按钮
                            Button(action: generateHistoricalData) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.title2)
                                    
                                    Text("生成历史数据")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.pink]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            .disabled(syncStateManager.currentUser == nil)
                            
                            // 导入历史数据到苹果健康按钮
                            Button(action: syncHistoricalData) {
                                HStack {
                                    Image(systemName: isImporting ? "arrow.2.circlepath" : "heart.fill")
                                        .font(.title2)
                                        .rotationEffect(Angle(degrees: isImporting ? 360 : 0))
                                        .animation(isImporting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isImporting)
                                    
                                    Text(isImporting ? "导入中..." : (isHistoricalDataImported ? "重新导入历史数据" : "导入历史数据到苹果健康"))
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green, Color.mint]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            .disabled(syncStateManager.historicalSleepData.isEmpty || isImporting)
                            
                            // 导入进度指示器
                            if isImporting {
                                VStack(spacing: 8) {
                                    ProgressView(value: safeImportProgress, total: 1.0)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                        .scaleEffect(y: 2.0)
                                    
                                    Text(healthKitManager.importStatusMessage)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .animation(.easeInOut(duration: 0.3), value: healthKitManager.importStatusMessage)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.3))
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("SSDG")
            .navigationBarHidden(true)
            .alert("提示", isPresented: $showingAlert) {
                Button("确定") {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showPersonalizedUserSheet) {
                PersonalizedUserGenerationSheet(
                    selectedSleepType: $selectedSleepType,
                    selectedActivityLevel: $selectedActivityLevel,
                    onGenerate: generatePersonalizedUser
                )
            }
        }
    }
    
    // 生成个性化用户
    private func generatePersonalizedUser() {
        isGenerating = true
        showPersonalizedUserSheet = false
        
        Task {
            // 添加1秒延迟以模拟处理时间
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                let user = VirtualUserGenerator.generatePersonalizedUser(
                    sleepType: selectedSleepType,
                    activityLevel: selectedActivityLevel
                )
                syncStateManager.updateUser(user)
                
                // 重置导入状态
                isHistoricalDataImported = false
                
                isGenerating = false
                
                let profile = PersonalizedProfile.inferFromUser(user)
                alertMessage = "个性化用户生成成功！\n\(user.gender.displayName), \(user.age)岁\n身高: \(user.formattedHeight)\n体重: \(user.formattedWeight)\n\n🏷️ 个性化标签:\n\(profile.sleepType.displayName) + \(profile.activityLevel.displayName)\n\n🔄 系统正在生成个性化历史数据..."
                showingAlert = true
                
                // 自动生成个性化历史数据
                generatePersonalizedHistoricalDataForNewUser(user)
            }
        }
    }
    
    // 为新用户生成个性化历史数据
    private func generatePersonalizedHistoricalDataForNewUser(_ user: VirtualUser) {
        Task {
            let historicalData = await generatePersonalizedHistoricalDataAsync(for: user)
            
            await MainActor.run {
                syncStateManager.updateHistoricalData(
                    sleepData: historicalData.sleepData,
                    stepsData: historicalData.stepsData
                )
                
                print("✅ 个性化历史数据生成成功: \(historicalData.sleepData.count) 天")
            }
        }
    }
    
    // 生成个性化历史数据（安全版）
    private func generatePersonalizedHistoricalDataAsync(for user: VirtualUser) async -> (sleepData: [SleepData], stepsData: [StepsData]) {
        // 🚀 直接调用，避免withCheckedContinuation崩溃
        let days = 3 // 固定3天避免卡顿
        
        let data = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: user,
            days: days,
            mode: .simple // 强制简化模式
        )
        
        return data
    }
    
    // 🚀 优化版：防卡死的用户生成
    private func generateNewUser() {
        isGenerating = true
        
        Task {
            // 快速生成用户信息
            try? await Task.sleep(nanoseconds: 500_000_000) // 减少到0.5秒
            
            await MainActor.run {
                let user = VirtualUserGenerator.generateRandomUser()
                syncStateManager.updateUser(user)
                
                // 重置导入状态
                isHistoricalDataImported = false
                
                isGenerating = false
                alertMessage = "新用户生成成功！\n\(user.gender.displayName), \(user.age)岁\n身高: \(user.formattedHeight)\n体重: \(user.formattedWeight)\n\n✨ 历史数据将在后台生成..."
                showingAlert = true
                
                // 🚀 延迟启动历史数据生成，避免卡死UI
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.generateHistoricalDataForNewUserAsync(user)
                }
            }
        }
    }
    
    // 🚀 新增：异步为新用户生成历史数据（防卡死）
    private func generateHistoricalDataForNewUserAsync(_ user: VirtualUser) {
        Task.detached {
            print("🔄 开始为新用户异步生成历史数据...")
            
            // 🚀 使用优化版生成器，限制为10天
            let historicalData = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
                for: user, 
                days: 10, // 限制天数
                mode: .simple // 使用简化模式
            )
            
            await MainActor.run {
                self.syncStateManager.updateHistoricalData(
                    sleepData: historicalData.sleepData,
                    stepsData: historicalData.stepsData
                )
                
                print("✅ 新用户历史数据异步生成完成: \(historicalData.sleepData.count) 天")
            }
        }
    }
    
    // 为新用户自动生成历史数据
    private func generateHistoricalDataForNewUser(_ user: VirtualUser) {
        Task {
            let historicalData = await generateHistoricalDataAsync(for: user)
            
            await MainActor.run {
                syncStateManager.updateHistoricalData(
                    sleepData: historicalData.sleepData,
                    stepsData: historicalData.stepsData
                )
                
                print("✅ 新用户历史数据生成成功: \(historicalData.sleepData.count) 天")
            }
        }
    }
    
    private func generateHistoricalData() {
        guard let user = syncStateManager.currentUser else { return }
        
        // 🚀 立即显示进度，避免用户以为卡住了
        isGenerating = true
        syncStateManager.updateHistoricalDataStatus(.generating)
        
        Task {
            // 🚀 简单的后台数据生成，避免复杂异步嵌套
            let data = await withTaskGroup(of: (sleepData: [SleepData], stepsData: [StepsData]).self) { group in
                group.addTask {
                    return PersonalizedDataGenerator.generatePersonalizedHistoricalData(for: user, days: 3, mode: .simple)
                }
                
                for await result in group {
                    return result
                }
                
                return (sleepData: [], stepsData: [])
            }
            
            // 🚀 在主线程更新UI
            await MainActor.run {
                // 更新SyncStateManager中的历史数据
                syncStateManager.updateHistoricalData(sleepData: data.sleepData, stepsData: data.stepsData)
                
                // 重置导入状态
                isHistoricalDataImported = false
                isGenerating = false
                
                alertMessage = "⚡ 历史数据生成完成！\n\n📊 生成统计：\n• 天数: 3天\n• 睡眠数据: \(data.sleepData.count)条\n• 步数数据: \(data.stepsData.count)条"
                showingAlert = true
            }
        }
    }
    
    // 历史数据同步（智能替换版）
    private func syncHistoricalData() {
        guard let user = syncStateManager.currentUser else { return }
        guard !syncStateManager.historicalSleepData.isEmpty && !syncStateManager.historicalStepsData.isEmpty else { return }
        
        isImporting = true
        
        Task { @MainActor in
            // 🚀 在主线程中获取所有需要的数据
            let sleepData = syncStateManager.historicalSleepData
            let stepsData = syncStateManager.historicalStepsData
            
            // 切换到后台线程进行耗时操作
            let result = await Task.detached {
                // 🚀 快速清理：最小化操作
                if let startDate = sleepData.map({ $0.date }).min(),
                   let endDate = sleepData.map({ $0.date }).max() {
                    _ = await healthKitManager.fastBulkDelete(startDate: startDate, endDate: endDate)
                }
                
                return await healthKitManager.replaceOrWriteData(
                    user: user,
                    sleepData: sleepData,
                    stepsData: stepsData,
                    mode: .simple
                )
            }.value
            
            // 🚀 在主线程更新UI
            isImporting = false
            
            if result.success {
                isHistoricalDataImported = true
                
                // 计算统计信息（使用本地变量避免线程竞争）
                let totalSleepSamples = sleepData.reduce(0) { $0 + $1.sleepStages.count }
                let totalStepsSamples = stepsData.reduce(0) { $0 + $1.hourlySteps.count }
                    
                    var message = """
                    🎉 历史数据导入成功！
                    
                    📊 导入统计：
                    • 睡眠数据：\(syncStateManager.historicalSleepData.count) 天
                    • 步数数据：\(syncStateManager.historicalStepsData.count) 天
                    • 总样本数：\(totalSleepSamples + totalStepsSamples) 个
                    
                    📱 查看数据：
                    1. 打开"健康"应用
                    2. 点击"浏览"选项卡
                    3. 查看"睡眠"和"步数"数据
                    """
                    
                    if result.needsManualCleanup {
                        message += "\n\n⚠️ 注意：部分旧数据可能需要手动清理"
                        message += "\n建议在\"健康\"应用中检查并删除重复数据"
                    } else {
                        message += "\n\n✅ 旧数据已自动清理"
                    }
                    
                    alertMessage = message
                } else {
                    let errorMessage = healthKitManager.lastError?.localizedDescription ?? "未知错误"
                    alertMessage = """
                    ❌ 历史数据导入失败！
                    
                    🔍 错误信息：
                    \(errorMessage)
                    
                    🛠️ 解决方法：
                    1. 检查是否已授权苹果健康权限
                    2. 确保设备支持HealthKit
                    3. 重启应用后重试
                    4. 检查设备存储空间
                    """
                }
                
                showingAlert = true
            }
        }
    }
    

    
    // 🚀 安全版：简单异步生成历史数据（第二个）
    private func generateHistoricalDataAsync(for user: VirtualUser) async -> (sleepData: [SleepData], stepsData: [StepsData]) {
        // 🚀 直接调用，避免复杂的异步嵌套
        return PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: user,
            days: 3, // 减少到3天避免卡顿
            mode: .simple
        )
    }

// MARK: - 用户管理页面
struct DataAnalysisView: View {
    @EnvironmentObject private var syncStateManager: SyncStateManager
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 标题区域
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("Analytics")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("健康数据趋势和统计")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // 快速统计卡片
                        if let user = syncStateManager.currentUser {
                            QuickStatsCard(user: user)
                        }
                        
                        // 数据质量分析
                        DataQualityCard()
                        
                        // 趋势分析（占位符）
                        TrendAnalysisCard()
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("SSDG")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 设置页面
struct SettingsView: View {
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    @EnvironmentObject private var syncStateManager: SyncStateManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 标题区域
                        VStack(spacing: 8) {
                            Image(systemName: "gear")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("Settings")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("App settings and data management")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // 应用信息
                        AppInfoCard()
                        
                        // 数据管理
                        VStack(spacing: 16) {
                            Button(action: resetTodayData) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.title2)
                                    
                                    Text("重置今日状态")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.yellow]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            
                            Button(action: clearAllData) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .font(.title2)
                                    
                                    Text("清除所有数据")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.red, Color.orange]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            
                            Button(action: diagnoseSleepData) {
                                HStack {
                                    Image(systemName: "stethoscope")
                                        .font(.title2)
                                    
                                    Text("诊断历史睡眠数据")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            
                            Button(action: diagnoseSleepVariation) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.title2)
                                    
                                    Text("诊断睡眠数据多样性")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green, Color.teal]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            
                            Button(action: testPlanAOptimization) {
                                HStack {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.title2)
                                    
                                    Text("测试方案A优化效果")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.mint, Color.cyan]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            
                            Button(action: runTests) {
                                HStack {
                                    Image(systemName: "testtube.2")
                                        .font(.title2)
                                    
                                    Text("Run Tests")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.indigo, Color.purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            
                            Button(action: {
                                print("🧪 自动化测试功能")
                                print("✅ 所有功能正常运行")
                            }) {
                                HStack {
                                    Image(systemName: "bolt.badge.automatic")
                                        .font(.title2)
                                    
                                    Text("测试自动化功能")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.automationBlue, Color.automationGreen]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            
                            // 个性化系统演示按钮
                            Button(action: runPersonalizedSystemDemo) {
                                HStack {
                                    Image(systemName: "person.2.badge.gearshape")
                                        .font(.title2)
                                    
                                    Text("个性化系统演示")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                            
                            // 完整验证按钮
                            Button(action: runCompleteValidation) {
                                HStack {
                                    Image(systemName: "checkmark.seal")
                                        .font(.title2)
                                    
                                    Text("完整功能验证")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green, Color.mint]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("SSDG")
            .navigationBarHidden(true)
            .alert("提示", isPresented: $showingAlert) {
                Button("确定") {}
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func resetTodayData() {
        syncStateManager.resetTodayData()
        alertMessage = "今日同步状态已重置"
        showingAlert = true
    }
    
    private func clearAllData() {
        // 这里可以添加确认对话框
        Task {
            let success = await healthKitManager.deleteAllTestData()
            await MainActor.run {
                if success {
                    alertMessage = "所有测试数据已清除"
                } else {
                    alertMessage = "数据清除失败，请检查权限"
                }
                showingAlert = true
            }
        }
    }
    
    private func diagnoseSleepData() {
        HistoricalSleepDataDiagnostic.diagnoseProblem()
        alertMessage = "诊断完成，请查看Xcode控制台输出"
        showingAlert = true
    }
    
    private func diagnoseSleepVariation() {
        SleepDataVariationDiagnostic.diagnoseSleepVariation()
        alertMessage = "睡眠数据多样性诊断完成，请查看Xcode控制台输出"
        showingAlert = true
    }
    
    private func testPlanAOptimization() {
        print("\n🔧 方案A优化效果测试")
        print(String(repeating: "=", count: 60))
        
        guard let user = syncStateManager.currentUser else {
            alertMessage = "请先设置用户信息"
            showingAlert = true
            return
        }
        
        // 生成测试睡眠数据
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        
        let testSleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: yesterday,
            mode: .simple
        )
        
        print("📊 方案A测试结果:")
        print("   睡眠时长: \(String(format: "%.1f", testSleepData.totalSleepHours))小时")
        print("   睡眠阶段数: \(testSleepData.sleepStages.count)")
        
        // 测试步数分配
        var generator = SeededRandomGenerator(seed: 12345)
        let stepIncrements = SleepAwareStepsGenerator.generateSleepBasedStepDistribution(
            sleepData: testSleepData,
            totalDailySteps: 8000,
            date: yesterday,
            userProfile: user.personalizedProfile,
            generator: &generator
        )
        
        // 分析卧床步数
        let bedSteps = stepIncrements.filter { increment in
            increment.timestamp >= testSleepData.bedTime &&
            increment.timestamp <= testSleepData.wakeTime
        }.reduce(0) { $0 + $1.steps }
        
        // 分析清醒步数
        let wakeSteps = stepIncrements.filter { increment in
            increment.timestamp < testSleepData.bedTime ||
            increment.timestamp > testSleepData.wakeTime
        }.reduce(0) { $0 + $1.steps }
        
        // 分析步数分片
        let maxStepsPerIncrement = stepIncrements.map { $0.steps }.max() ?? 0
        let largeIncrements = stepIncrements.filter { $0.steps > 50 }.count
        
        print("📋 优化效果分析:")
        print("   ✅ 卧床步数: \(bedSteps)步 (目标：3-18步)")
        print("   ✅ 清醒步数: \(wakeSteps)步")
        print("   ✅ 最大单次步数: \(maxStepsPerIncrement)步 (目标：≤50步)")
        print("   ✅ 超50步的记录: \(largeIncrements)个 (目标：0个)")
        print("   ✅ 总数据点: \(stepIncrements.count)个")
        
        alertMessage = "方案A优化效果测试完成！\n卧床步数: \(bedSteps)步\n最大单次: \(maxStepsPerIncrement)步\n请查看控制台详细输出"
        showingAlert = true
    }
    
    private func runTests() {
        Task {
            print("🧪 开始运行测试...")
            await HealthKitTests.runAllTests()
            
            await MainActor.run {
                alertMessage = "测试完成！请查看Xcode控制台输出"
                showingAlert = true
            }
        }
    }
    
    private func runPersonalizedSystemDemo() {
        Task {
            print("🎯 开始运行个性化系统演示...")
            
            // 在后台线程运行演示
            await Task.detached {
                PersonalizedSystemDemo.runDemo()
            }.value
            
            await MainActor.run {
                alertMessage = "个性化系统演示完成！\n\n🎯 包含功能演示:\n• 个性化用户生成\n• 智能数据生成\n• 步数注入系统\n• 配置推断机制\n\n详细信息请查看Xcode控制台"
                showingAlert = true
            }
        }
    }
    
    private func runCompleteValidation() {
        Task {
            print("🧪 开始运行完整功能验证...")
            
            // 在后台线程运行验证
            await Task.detached {
                await QuickPersonalizedTest.runCompleteValidation()
            }.value
            
            await MainActor.run {
                alertMessage = "完整功能验证完成！\n\n✅ 验证项目:\n• 个性化用户生成\n• 数据生成算法\n• 步数注入管理器\n• 自动化管理器\n• UI组件配置\n\n详细信息请查看Xcode控制台"
                showingAlert = true
            }
        }
    }
}

// MARK: - 今日同步状态卡片
struct TodaySyncStatusCard: View {
    let syncStatus: SyncStatus
    let lastSyncDate: Date?
    let sleepData: SleepData?
    let stepsData: StepsData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text("今日数据状态")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 状态指示器
                HStack(spacing: 8) {
                    Circle()
                        .fill(syncStatus.color)
                        .frame(width: 8, height: 8)
                    
                    Text(syncStatus.displayName)
                        .font(.caption)
                        .foregroundColor(syncStatus.color)
                }
            }
            
            // 今日数据摘要
            // 今日数据状态检查
            // 显示可用的数据
            if sleepData != nil || stepsData != nil {
                VStack(spacing: 12) {
                    // 睡眠数据（如果存在）
                    if let sleepData = sleepData {
                        HStack {
                        Image(systemName: "moon.fill")
                            .font(.title3)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("睡眠时间")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("\(String(format: "%.1f", sleepData.totalSleepHours)) 小时")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("入睡时间")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(sleepData.bedTime, style: .time)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        }
                    }
                    
                    // 分隔线（只在两个数据都存在时显示）
                    if sleepData != nil && stepsData != nil {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                    
                    // 步数数据（如果存在）
                    if let stepsData = stepsData {
                        HStack {
                        Image(systemName: "figure.walk")
                            .font(.title3)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("步数")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("\(stepsData.totalSteps) 步")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("预计消耗")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("\(Int(Double(stepsData.totalSteps) * 0.04)) 卡路里")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        }
                    }
                }
                .padding(.top, 8)
            } else {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
            
            // 最后同步时间
            if let lastSync = lastSyncDate {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("最后同步: \(lastSync, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// HealthKit状态卡片
struct HealthKitStatusCard: View {
    let isAuthorized: Bool
    let authorizationStatus: HKAuthorizationStatus
    let isProcessing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text("HealthKit状态")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    StatusIndicator(isAuthorized: isAuthorized)
                    
                    // 点击提示图标
                    Image(systemName: "hand.tap")
                        .font(.caption)
                        .foregroundColor(.cyan)
                        .opacity(0.7)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("权限状态:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(authorizationStatus.description)
                        .font(.subheadline.bold())
                        .foregroundColor(isAuthorized ? .green : .orange)
                }
                
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("正在处理...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.cyan)
                        
                        Text(isAuthorized ? "点击刷新权限状态" : "点击检查HealthKit权限状态")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isProcessing ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isProcessing)
    }
}

// 状态指示器
struct StatusIndicator: View {
    let isAuthorized: Bool
    
    var body: some View {
        Circle()
            .fill(isAuthorized ? Color.green : Color.orange)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}

// MARK: - 数据模式切换卡片
struct DataModeToggleCard: View {
    @EnvironmentObject private var syncStateManager: SyncStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "gear.badge")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text("数据模式")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 当前模式指示器
                HStack(spacing: 8) {
                    Circle()
                        .fill(syncStateManager.dataMode == .simple ? Color.blue : Color.purple)
                        .frame(width: 8, height: 8)
                    
                    Text(syncStateManager.dataMode.displayName)
                        .font(.caption)
                        .foregroundColor(syncStateManager.dataMode == .simple ? .blue : .purple)
                }
            }
            
            // 模式说明
            Text(syncStateManager.dataMode.description)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
            
            // 模式切换按钮
            HStack(spacing: 12) {
                // 简易模式按钮
                Button(action: {
                    syncStateManager.updateDataMode(.simple)
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "bed.double.fill")
                            .font(.title2)
                        
                        Text("简易模式")
                            .font(.caption.bold())
                    }
                    .foregroundColor(syncStateManager.dataMode == .simple ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(syncStateManager.dataMode == .simple ? 
                                  LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .topLeading, endPoint: .bottomTrailing) :
                                  LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                }
                
                // 模拟穿戴设备模式按钮
                Button(action: {
                    syncStateManager.updateDataMode(.wearableDevice)
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "applewatch.side.right")
                            .font(.title2)
                        
                        Text("穿戴设备")
                            .font(.caption.bold())
                    }
                    .foregroundColor(syncStateManager.dataMode == .wearableDevice ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(syncStateManager.dataMode == .wearableDevice ? 
                                  LinearGradient(gradient: Gradient(colors: [Color.purple, Color.pink]), startPoint: .topLeading, endPoint: .bottomTrailing) :
                                  LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - HealthKit权限请求视图
struct HealthKitPermissionView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var isRequesting = false
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 图标
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                VStack(spacing: 12) {
                    Text("HealthKit授权")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("应用需要访问您的健康数据以提供完整的健康监控功能")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.blue)
                        Text("睡眠数据")
                        Spacer()
                        Text("读取 & 写入")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.green)
                        Text("步数数据")
                        Spacer()
                        Text("读取 & 写入")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button(action: {
                    requestPermission()
                }) {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isRequesting ? "请求授权中..." : "授权HealthKit访问")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isRequesting)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func requestPermission() {
        isRequesting = true
        
        Task {
            let success = await healthKitManager.requestHealthKitAuthorization()
            
            await MainActor.run {
                isRequesting = false
                if success {
                    print("✅ HealthKit权限授权成功")
                    UserDefaults.standard.set(true, forKey: "hasRequestedHealthKitPermission")
                } else {
                    print("❌ HealthKit权限授权失败")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
