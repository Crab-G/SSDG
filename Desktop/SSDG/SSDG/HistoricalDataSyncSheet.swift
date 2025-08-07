//
//  HistoricalDataSyncSheet.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI

// MARK: - 历史数据同步界面
struct HistoricalDataSyncSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // 状态管理
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var syncStateManager = SyncStateManager.shared
    @StateObject private var automationManager = AutomationManager.shared
    
    @State private var selectedDays: Int = 30
    @State private var isProcessing = false
    @State private var syncProgress: Double = 0.0
    @State private var syncStatusMessage = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
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
                    VStack(spacing: 24) {
                        // 头部说明
                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            Text("历史数据同步")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("同步个性化历史数据到Apple Health")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // 天数选择卡片
                        DaySelectorCard(selectedDays: $selectedDays, isProcessing: isProcessing)
                        
                        // 数据预览卡片
                        if let user = syncStateManager.currentUser {
                            DataPreviewCard(user: user, days: selectedDays)
                        }
                        
                        // 进度卡片
                        if isProcessing {
                            ProgressCard(progress: syncProgress, statusMessage: syncStatusMessage)
                        }
                        
                        // 同步按钮
                        SyncButton(
                            isProcessing: isProcessing,
                            hasUser: syncStateManager.currentUser != nil,
                            onSync: startSync
                        )
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        if !isProcessing {
                            dismiss()
                        }
                    }
                    .foregroundColor(isProcessing ? .gray : .white)
                    .disabled(isProcessing)
                }
            }
        }
        .alert("同步成功", isPresented: $showingSuccessAlert) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("历史数据已成功同步到Apple Health")
        }
        .alert("同步失败", isPresented: $showingErrorAlert) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // 开始同步
    private func startSync() {
        guard syncStateManager.currentUser != nil else { return }
        
        isProcessing = true
        syncProgress = 0.0
        syncStatusMessage = "正在准备同步..."
        
        Task {
            // 模拟同步进度
            do {
                try await updateProgress(0.1, "生成个性化历史数据...")
                try await Task.sleep(nanoseconds: 500_000_000)
                
                try await updateProgress(0.3, "准备睡眠数据...")
                try await Task.sleep(nanoseconds: 500_000_000)
                
                try await updateProgress(0.6, "准备步数数据...")
                try await Task.sleep(nanoseconds: 500_000_000)
                
                try await updateProgress(0.8, "写入Apple Health...")
                
                // 执行实际同步 - 使用简化方法
                let success = await performHistoricalSync(days: selectedDays)
            
                await MainActor.run {
                    isProcessing = false
                    if success {
                        syncProgress = 1.0
                        syncStatusMessage = "同步完成！"
                        showingSuccessAlert = true
                    } else {
                        errorMessage = "同步失败，请检查HealthKit权限或网络连接"
                        showingErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "同步过程中发生错误: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    // 更新进度
    @MainActor
    private func updateProgress(_ progress: Double, _ message: String) async throws {
        syncProgress = progress
        syncStatusMessage = message
    }
    
    // 执行历史数据同步的辅助方法
    private func performHistoricalSync(days: Int) async -> Bool {
        guard let user = syncStateManager.currentUser else { return false }
        
        // 生成历史数据
        // 🔧 修复：使用PersonalizedDataGenerator替代旧的DataGenerator
        let historicalData = PersonalizedDataGenerator.generatePersonalizedHistoricalData(for: user, days: days, mode: .simple)
        
        // 同步到HealthKit
        let result = await healthKitManager.replaceOrWriteData(
            user: user,
            sleepData: historicalData.sleepData,
            stepsData: historicalData.stepsData,
            mode: .simple
        )
        
        return result.success
    }
}

// MARK: - 天数选择卡片
struct DaySelectorCard: View {
    @Binding var selectedDays: Int
    let isProcessing: Bool
    
    private let dayOptions = [7, 30, 90, 180, 365]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Image(systemName: "calendar.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("选择同步天数")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 快速选择按钮
                HStack(spacing: 8) {
                    ForEach(dayOptions, id: \.self) { days in
                        QuickSelectButton(
                            days: days,
                            selectedDays: selectedDays,
                            isProcessing: isProcessing,
                            onSelect: { selectedDays = days }
                        )
                    }
                }
                
                // 自定义滑块
                VStack(spacing: 8) {
                    HStack {
                        Text("自定义天数")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(selectedDays) 天")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                            .monospacedDigit()
                    }
                    
                    let sliderBinding = Binding<Double>(
                        get: { Double(selectedDays) },
                        set: { selectedDays = Int($0) }
                    )
                    
                    Slider(
                        value: sliderBinding,
                        in: 1...365,
                        step: 1
                    )
                    .tint(.blue)
                    .disabled(isProcessing)
                }
                
                // 天数说明
                Text(dayDescription(for: selectedDays))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.cyan.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func dayDescription(for days: Int) -> String {
        switch days {
        case 1...7:
            return "适合快速测试和验证功能"
        case 8...30:
            return "推荐选择，提供一个月的历史数据"
        case 31...90:
            return "季度数据，适合分析长期趋势"
        case 91...180:
            return "半年数据，可以观察季节性变化"
        case 181...365:
            return "全年数据，提供完整的年度健康记录"
        default:
            return "超长历史数据，可能需要较长同步时间"
        }
    }
}

// MARK: - 数据预览卡片
struct DataPreviewCard: View {
    let user: VirtualUser
    let days: Int
    
    private var estimatedSleepData: Int { days }
    private var estimatedStepData: Int { days * 16 } // 假设每天16小时活跃时间
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("数据预览")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 用户信息
                HStack {
                    Text("用户类型:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(user.personalizedDescription)
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // 预计数据量
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "moon.zzz")
                            .foregroundColor(.cyan)
                        
                        Text("睡眠数据")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(estimatedSleepData) 条")
                            .font(.subheadline.bold())
                            .foregroundColor(.cyan)
                    }
                    
                    HStack {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.blue)
                        
                        Text("步数数据")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(estimatedStepData) 条")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        
                        Text("预计时间")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(estimatedTime(for: days))
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.6), Color.mint.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func estimatedTime(for days: Int) -> String {
        let seconds = days * 2 // 假设每天2秒
        if seconds < 60 {
            return "\(seconds) 秒"
        } else {
            let minutes = seconds / 60
            return "\(minutes) 分钟"
        }
    }
}

// MARK: - 进度卡片
struct ProgressCard: View {
    let progress: Double
    let statusMessage: String
    
    // 安全的进度值 - 移到computed property
    private var safeProgress: Double {
        guard progress.isFinite && !progress.isNaN else { return 0.0 }
        return max(0.0, min(1.0, progress))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("同步进度")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.title3.bold())
                    .foregroundColor(.orange)
                    .monospacedDigit()
            }
            
            VStack(spacing: 12) {
                // 进度条 - 使用超级安全进度值
                ProgressView(value: max(0.0, min(1.0, safeProgress)), total: 1.0)
                    .tint(.orange)
                    .scaleEffect(y: 2)
                
                // 状态消息
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                // 动画指示器
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .scaleEffect(progress > 0 ? 1.0 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: progress
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.6), Color.yellow.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 同步按钮
struct SyncButton: View {
    let isProcessing: Bool
    let hasUser: Bool
    let onSync: () -> Void
    
    var body: some View {
        Button(action: onSync) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("正在同步...")
                        .font(.headline)
                } else {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title2)
                    
                    Text("开始同步")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isProcessing ? [.gray, .gray] : [.blue, .cyan]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .disabled(isProcessing || !hasUser)
    }
}

// MARK: - 快速选择按钮组件
struct QuickSelectButton: View {
    let days: Int
    let selectedDays: Int
    let isProcessing: Bool
    let onSelect: () -> Void
    
    var body: some View {
        let isSelected = selectedDays == days
        
        Button(action: onSelect) {
            Text("\(days)天")
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .white : .blue)
                .frame(minWidth: 50, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.2))
                )
        }
        .disabled(isProcessing)
    }
}

#Preview {
    HistoricalDataSyncSheet()
} 