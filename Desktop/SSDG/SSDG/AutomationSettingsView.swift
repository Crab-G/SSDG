//
//  AutomationSettingsView.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI
import UserNotifications

// MARK: - 自动化设置界面
struct AutomationSettingsView: View {
    @StateObject private var automationManager = AutomationManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var showingTimePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var pendingNotificationsCount = 0
    
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
                        // 标题区域
                        VStack(spacing: 8) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.automationBlue)
                            
                            Text("自动化设置")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("配置智能同步和提醒功能")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // 自动化状态卡片
                        AutomationStatusCard(
                            status: automationManager.status,
                            isRunning: automationManager.isRunning,
                            nextScheduledRun: automationManager.nextScheduledRun,
                            failureCount: automationManager.failureCount
                        )
                        
                        // 自动化级别选择
                        AutomationLevelCard(
                            currentLevel: automationManager.config.autoSyncLevel,
                            onLevelChanged: { level in
                                automationManager.updateAutomationLevel(level)
                            }
                        )
                        
                        // 时间设置卡片
                        TimeSettingsCard(
                            dailySyncTime: automationManager.config.dailySyncTime,
                            dayEndSyncTime: automationManager.config.dayEndSyncTime,
                            onDailySyncTimeChanged: { time in
                                automationManager.config.dailySyncTime = time
                                saveAndRestartAutomation()
                            },
                            onDayEndSyncTimeChanged: { time in
                                automationManager.config.dayEndSyncTime = time
                                saveAndRestartAutomation()
                            }
                        )
                        
                        // 智能触发设置
                        SmartTriggersCard(
                            enableSmartTriggers: automationManager.config.enableSmartTriggers,
                            wakeTimeDetection: automationManager.config.wakeTimeDetection,
                            sleepTimeDetection: automationManager.config.sleepTimeDetection,
                            onSmartTriggersChanged: { enabled in
                                automationManager.config.enableSmartTriggers = enabled
                                saveAndRestartAutomation()
                            },
                            onWakeTimeDetectionChanged: { enabled in
                                automationManager.config.wakeTimeDetection = enabled
                                saveAndRestartAutomation()
                            },
                            onSleepTimeDetectionChanged: { enabled in
                                automationManager.config.sleepTimeDetection = enabled
                                saveAndRestartAutomation()
                            }
                        )
                        
                        // 通知设置卡片
                        NotificationSettingsCard(
                            automationManager: automationManager,
                            notificationManager: notificationManager
                        )
                        
                        // 高级设置卡片
                        AdvancedSettingsCard(
                            automationManager: automationManager
                        )
                        
                        // 控制按钮
                        AutomationControlButtons(
                            status: automationManager.status,
                            onStart: {
                                automationManager.startAutomation()
                                alertMessage = "自动化已启动"
                                showingAlert = true
                            },
                            onStop: {
                                automationManager.stopAutomation()
                                alertMessage = "自动化已停止"
                                showingAlert = true
                            },
                            onPause: {
                                automationManager.pauseAutomation()
                                alertMessage = "自动化已暂停"
                                showingAlert = true
                            },
                            onResume: {
                                automationManager.resumeAutomation()
                                alertMessage = "自动化已恢复"
                                showingAlert = true
                            }
                        )
                        
                        // 自动化日志
                        AutomationLogCard(
                            automationLog: Array(automationManager.automationLog.suffix(10))
                        )
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .alert("提示", isPresented: $showingAlert) {
                Button("确定") {}
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            updatePendingNotificationsCount()
        }
    }
    
    // MARK: - 辅助方法
    private func saveAndRestartAutomation() {
        Task { @MainActor in
            // 保存配置并重启自动化
            if automationManager.status == .enabled || automationManager.status == .running {
                automationManager.stopAutomation()
                try? await Task.sleep(nanoseconds: 500_000_000) // 等待0.5秒
                automationManager.startAutomation()
            }
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            let granted = await notificationManager.requestNotificationAuthorization()
            await MainActor.run {
                if granted {
                    automationManager.config.enableNotifications = true
                    saveAndRestartAutomation()
                    alertMessage = "通知权限已授权，自动化通知已启用"
                } else {
                    alertMessage = "通知权限被拒绝，请在设置中手动开启"
                }
                showingAlert = true
            }
        }
    }
    
    private func updatePendingNotificationsCount() {
        Task {
            let count = await notificationManager.getPendingNotificationsCount()
            await MainActor.run {
                pendingNotificationsCount = count
            }
        }
    }
}

// MARK: - 自动化状态卡片
struct AutomationStatusCard: View {
    let status: AutomationStatus
    let isRunning: Bool
    let nextScheduledRun: Date?
    let failureCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gear.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(status.color)
                
                Text("自动化状态")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    }
                    
                    Circle()
                        .fill(status.color)
                        .frame(width: 12, height: 12)
                    
                    Text(status.displayName)
                        .font(.caption.bold())
                        .foregroundColor(status.color)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if let nextRun = nextScheduledRun {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("下次运行: \(nextRun, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if failureCount > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("失败次数: \(failureCount)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(status.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 自动化级别卡片
struct AutomationLevelCard: View {
    let currentLevel: AutoSyncLevel
    let onLevelChanged: (AutoSyncLevel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.automationBlue)
                
                Text("自动化级别")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(currentLevel.description)
                .font(.caption)
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                ForEach(AutoSyncLevel.allCases, id: \.self) { level in
                    Button(action: {
                        onLevelChanged(level)
                    }) {
                        HStack {
                            Image(systemName: level.icon)
                                .font(.title3)
                                .foregroundColor(currentLevel == level ? .white : .gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.displayName)
                                    .font(.headline)
                                    .foregroundColor(currentLevel == level ? .white : .gray)
                                
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundColor(currentLevel == level ? .gray : .gray.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            if currentLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentLevel == level ? 
                                      Color.automationBlue.opacity(0.3) : 
                                      Color.gray.opacity(0.1)
                                )
                        )
                    }
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

// MARK: - 时间设置卡片
struct TimeSettingsCard: View {
    let dailySyncTime: Date
    let dayEndSyncTime: Date
    let onDailySyncTimeChanged: (Date) -> Void
    let onDayEndSyncTimeChanged: (Date) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.badge.fill")
                    .font(.title2)
                    .foregroundColor(.automationOrange)
                
                Text("时间设置")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 16) {
                // 每日同步时间
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("每日同步时间")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        DatePicker("", selection: Binding(
                            get: { dailySyncTime },
                            set: onDailySyncTimeChanged
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                    
                    Text("自动生成和同步每日健康数据的时间")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // 睡前检查时间
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("睡前检查时间")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        DatePicker("", selection: Binding(
                            get: { dayEndSyncTime },
                            set: onDayEndSyncTimeChanged
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                    
                    Text("智能触发检查是否需要补充同步数据")
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

// MARK: - 智能触发设置卡片
struct SmartTriggersCard: View {
    let enableSmartTriggers: Bool
    let wakeTimeDetection: Bool
    let sleepTimeDetection: Bool
    let onSmartTriggersChanged: (Bool) -> Void
    let onWakeTimeDetectionChanged: (Bool) -> Void
    let onSleepTimeDetectionChanged: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.badge.automatic")
                    .font(.title2)
                    .foregroundColor(.automationGreen)
                
                Text("智能触发")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { enableSmartTriggers },
                    set: onSmartTriggersChanged
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .automationGreen))
            }
            
            if enableSmartTriggers {
                VStack(spacing: 12) {
                    // 起床时间检测
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("起床时间检测")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            Text("在起床时间自动生成数据")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { wakeTimeDetection },
                            set: onWakeTimeDetectionChanged
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .automationGreen))
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // 睡前时间检测
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("睡前时间检测")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            Text("在睡前时间检查数据同步状态")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { sleepTimeDetection },
                            set: onSleepTimeDetectionChanged
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .automationGreen))
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.automationGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    AutomationSettingsView()
} 