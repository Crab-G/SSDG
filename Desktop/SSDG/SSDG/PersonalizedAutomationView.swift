//
//  PersonalizedAutomationView.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI
import Charts

// MARK: - 个性化自动化主界面
struct PersonalizedAutomationView: View {
    // 状态管理
    @StateObject private var automationManager = AutomationManager.shared
    @StateObject private var syncStateManager = SyncStateManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var showingConfigSheet = false
    @State private var showingHistoricalSyncSheet = false
    
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
                        // 状态概览卡片
                        PersonalizedAutomationStatusCard()
                        
                        // 实时进度卡片
                        if automationManager.isPersonalizedModeEnabled {
                            RealTimeProgressCard()
                        }
                        
                        // 步数注入监控
                        if automationManager.stepInjectionManager != nil {
                            if let stepManager = automationManager.stepInjectionManager {
                                StepInjectionProgressCard(stepManager: stepManager)
                            }
                        }
                        
                        // 下次睡眠数据生成
                        if let nextGeneration = automationManager.nextSleepDataGeneration {
                            NextSleepGenerationCard(nextTime: nextGeneration)
                        }
                        
                        // 控制按钮组
                        PersonalizedControlButtonsCard()
                        
                        // 数据统计图表
                        if automationManager.isPersonalizedModeEnabled {
                            PersonalizedDataChartsCard()
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("个性化自动化")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingConfigSheet = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingConfigSheet) {
                PersonalizedAutomationConfigSheet(
                    config: $automationManager.personalizedConfig,
                    isPresented: $showingConfigSheet
                )
            }
            .sheet(isPresented: $showingHistoricalSyncSheet) {
                HistoricalDataSyncSheet()
            }
        }
    }
}

// MARK: - 状态概览卡片
struct PersonalizedAutomationStatusCard: View {
    @ObservedObject private var automationManager = AutomationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gauge.badge.plus")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("自动化状态")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 状态指示器
                HStack(spacing: 8) {
                    Circle()
                        .fill(automationManager.automationStatus.color)
                        .frame(width: 12, height: 12)
                    
                    Text(automationManager.automationStatus.displayName)
                        .font(.caption.bold())
                        .foregroundColor(automationManager.automationStatus.color)
                }
            }
            
            VStack(spacing: 12) {
                // 个性化模式状态
                StatusRow(
                    title: "个性化模式",
                    value: automationManager.isPersonalizedModeEnabled ? "已启用" : "未启用",
                    icon: "person.2.badge.gearshape",
                    color: automationManager.isPersonalizedModeEnabled ? .green : .gray
                )
                
                // 当前用户信息
                if let user = automationManager.currentUser {
                    StatusRow(
                        title: "当前用户",
                        value: user.personalizedDescription,
                        icon: "person.circle",
                        color: .blue
                    )
                }
                
                // 步数注入状态
                StatusRow(
                    title: "步数注入",
                    value: (automationManager.stepInjectionManager?.isActive ?? false) ? "进行中" : "未启动",
                    icon: "figure.walk.motion",
                    color: (automationManager.stepInjectionManager?.isActive ?? false) ? .green : .gray
                )
                
                // 已注入步数
                if let stepManager = automationManager.stepInjectionManager {
                    StatusRow(
                        title: "已注入步数",
                        value: "\(stepManager.injectedSteps) 步",
                        icon: "plus.circle",
                        color: .orange
                    )
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
                                gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 实时进度卡片
struct RealTimeProgressCard: View {
    @ObservedObject private var automationManager = AutomationManager.shared
    @State private var progressAnimation: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("实时进度")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 刷新按钮
                Button(action: refreshProgress) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.green)
                        .rotationEffect(.degrees(progressAnimation))
                }
            }
            
            if let stepManager = automationManager.stepInjectionManager,
               let distribution = stepManager.currentDistribution {
                
                VStack(spacing: 12) {
                    // 步数进度显示 - 简化为文字避免ProgressView错误
                    HStack {
                        Text("步数注入进度")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(stepManager.injectedSteps) / \(distribution.totalSteps)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // 简单的进度指示条
                    HStack(spacing: 4) {
                        ForEach(0..<10, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index < (stepManager.injectedSteps * 10 / max(1, distribution.totalSteps)) ? Color.cyan : Color.gray.opacity(0.3))
                                .frame(height: 4)
                        }
                    }
                    .tint(.green)
                    
                    // 详细信息
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("完成度")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("\(Int((Double(stepManager.injectedSteps) / Double(distribution.totalSteps)) * 100))%")
                                .font(.title3.bold())
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("剩余注入点")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text("\(distribution.incrementalData.count - stepManager.injectedSteps / 10)")
                                .font(.title3.bold())
                                .foregroundColor(.orange)
                        }
                    }
                }
            } else {
                Text("暂无活跃的步数注入任务")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
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
    
    private func refreshProgress() {
        withAnimation(.linear(duration: 1)) {
            progressAnimation += 360
        }
    }
}

// MARK: - 步数注入进度卡片
struct StepInjectionProgressCard: View {
    @ObservedObject var stepManager: StepInjectionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "syringe")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("步数注入监控")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 状态指示器
                Circle()
                    .fill(stepManager.isActive ? .green : .red)
                    .frame(width: 12, height: 12)
            }
            
            if stepManager.isActive {
                VStack(spacing: 12) {
                    // 当前状态
                    HStack {
                        Text("状态: 正在注入")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Text("累计: \(stepManager.injectedSteps) 步")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    // 进度条（完全安全的固定指示器）
                    if let distribution = stepManager.currentDistribution {
                        // 显示进度信息但不使用动态宽度
                        HStack {
                            Text("进度:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            // 安全的百分比显示
                            let percentage: String = {
                                guard distribution.totalSteps > 0 else { return "0%" }
                                let percent = (stepManager.injectedSteps * 100) / distribution.totalSteps
                                return "\(min(100, max(0, percent)))%"
                            }()
                            
                            Text(percentage)
                                .font(.caption.bold())
                                .foregroundColor(.cyan)
                        }
                        
                        // 固定宽度的视觉指示器
                        HStack(spacing: 2) {
                            ForEach(0..<20, id: \.self) { index in
                                Rectangle()
                                    .fill(index * distribution.totalSteps < stepManager.injectedSteps * 20 ? Color.cyan : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 4)
                                    .cornerRadius(1)
                            }
                        }
                    }
                    
                    // 实时信息
                    HStack {
                        Text("注入频率: 实时")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("类型: 微增量")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Text("步数注入未启动")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
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
}

// MARK: - 下次睡眠生成卡片
struct NextSleepGenerationCard: View {
    let nextTime: Date
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    @State private var animateOpacity = false
    // 移除了startTime和复杂的进度计算
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "moon.zzz")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text("下次睡眠数据生成")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // 预定时间
                HStack {
                    Text("预定时间:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(nextTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.bold())
                        .foregroundColor(.cyan)
                }
                
                // 倒计时
                HStack {
                    Text("剩余时间:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(formatTimeRemaining(timeRemaining))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                
                // 状态指示 - 脉动圆点效果，使用现代动画API
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 8, height: 8)
                            .opacity(animateOpacity ? 0.3 : 1.0)
                            .task {
                                // 使用异步任务实现重复动画
                                try? await Task.sleep(nanoseconds: UInt64(Double(index) * 200_000_000)) // 延迟
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    animateOpacity.toggle()
                                }
                                // 使用Timer实现重复效果
                                Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        animateOpacity.toggle()
                                    }
                                }
                            }
                    }
                    
                    Spacer()
                    
                    Text("等待中...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(height: 6)
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
                                gradient: Gradient(colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            startTimer()
            // 启动脉动动画
            withAnimation {
                animateOpacity = true
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        updateTimeRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        timeRemaining = max(0, nextTime.timeIntervalSince(Date()))
    }
    
    private func formatTimeRemaining(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - 控制按钮卡片
struct PersonalizedControlButtonsCard: View {
    @ObservedObject private var automationManager = AutomationManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("控制面板")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 第一行按钮
                HStack(spacing: 12) {
                    // 手动生成今日数据
                    ControlButton(
                        title: "生成今日数据",
                        icon: "wand.and.stars",
                        color: .purple,
                        isEnabled: automationManager.isPersonalizedModeEnabled && !isProcessing,
                        action: manualGenerateToday
                    )
                    
                    // 停止/启动注入
                    ControlButton(
                        title: automationManager.stepInjectionManager?.isActive == true ? "停止注入" : "启动注入",
                        icon: automationManager.stepInjectionManager?.isActive == true ? "stop.circle" : "play.circle",
                        color: automationManager.stepInjectionManager?.isActive == true ? .red : .green,
                        isEnabled: automationManager.isPersonalizedModeEnabled && !isProcessing,
                        action: toggleStepInjection
                    )
                }
                
                // 第二行按钮
                HStack(spacing: 12) {
                    // 同步历史数据
                    ControlButton(
                        title: "同步历史数据",
                        icon: "clock.arrow.circlepath",
                        color: .blue,
                        isEnabled: automationManager.isPersonalizedModeEnabled && !isProcessing,
                        action: syncHistoricalData
                    )
                    
                    // 清理数据
                    ControlButton(
                        title: "清理旧数据",
                        icon: "trash.circle",
                        color: .orange,
                        isEnabled: !isProcessing,
                        action: cleanupOldData
                    )
                }
                
                // 第三行：模式切换
                Button(action: togglePersonalizedMode) {
                    HStack {
                        Image(systemName: automationManager.isPersonalizedModeEnabled ? "pause.circle" : "play.circle")
                            .font(.title3)
                        
                        Text(automationManager.isPersonalizedModeEnabled ? "禁用个性化模式" : "启用个性化模式")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: automationManager.isPersonalizedModeEnabled ? [.red, .pink] : [.green, .mint]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(isProcessing || automationManager.currentUser == nil)
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
        .alert("操作结果", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // 按钮动作方法
    private func manualGenerateToday() {
        isProcessing = true
        Task {
            let success = await automationManager.manualGenerateTodayData()
            await MainActor.run {
                isProcessing = false
                alertMessage = success ? "今日数据生成成功！" : "今日数据生成失败，请检查HealthKit权限"
                showingAlert = true
            }
        }
    }
    
    private func toggleStepInjection() {
        let isActive = automationManager.stepInjectionManager?.isActive ?? false
        if isActive {
            automationManager.stopStepInjection()
            alertMessage = "步数注入已停止"
        } else {
            if let user = automationManager.currentUser {
                automationManager.startStepInjection(for: user)
                alertMessage = "步数注入已启动"
            }
        }
        showingAlert = true
    }
    
    private func syncHistoricalData() {
        isProcessing = true
        Task {
            let success = await automationManager.manualSyncHistoricalData(days: 30)
            await MainActor.run {
                isProcessing = false
                alertMessage = success ? "历史数据同步成功！已同步30天数据" : "历史数据同步失败，请检查网络和权限"
                showingAlert = true
            }
        }
    }
    
    private func cleanupOldData() {
        isProcessing = true
        Task {
            await automationManager.performMaintenanceTasks()
            await MainActor.run {
                isProcessing = false
                alertMessage = "数据清理完成！已清理过期数据"
                showingAlert = true
            }
        }
    }
    
    private func togglePersonalizedMode() {
        if automationManager.isPersonalizedModeEnabled {
            automationManager.disablePersonalizedMode()
            alertMessage = "个性化模式已禁用"
        } else {
            if let user = automationManager.currentUser {
                automationManager.enablePersonalizedMode(for: user)
                alertMessage = "个性化模式已启用"
            }
        }
        showingAlert = true
    }
}

// MARK: - 控制按钮组件
struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                
                Text(title)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(isEnabled ? .white : .gray)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? color.opacity(0.8) : Color.gray.opacity(0.3))
            )
        }
        .disabled(!isEnabled)
    }
}

// MARK: - 状态行组件
struct StatusRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
        }
    }
}

// MARK: - 数据统计图表卡片
struct PersonalizedDataChartsCard: View {
    @ObservedObject private var automationManager = AutomationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundColor(.mint)
                
                Text("数据统计")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // 简化的图表占位符
            VStack(spacing: 12) {
                Text("步数注入趋势")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                // 模拟图表数据
                HStack(spacing: 4) {
                    ForEach(0..<24, id: \.self) { hour in
                        Rectangle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 10, height: CGFloat.random(in: 10...50))
                            .cornerRadius(2)
                    }
                }
                .frame(height: 60)
                
                Text("过去24小时的步数注入分布")
                    .font(.caption)
                    .foregroundColor(.gray)
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
                                gradient: Gradient(colors: [Color.mint.opacity(0.6), Color.green.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview {
    PersonalizedAutomationView()
} 