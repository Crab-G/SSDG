//
//  AutomationStatusCard.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI

// MARK: - 自动化状态快速查看卡片
struct AutomationQuickStatusCard: View {
    @StateObject private var automationManager = AutomationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.badge.automatic")
                    .font(.title2)
                    .foregroundColor(.automationBlue)
                
                Text("自动化状态")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(automationManager.status.color)
                        .frame(width: 8, height: 8)
                    
                    Text(automationManager.status.displayName)
                        .font(.caption)
                        .foregroundColor(automationManager.status.color)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // 当前自动化级别
                HStack {
                    Image(systemName: automationManager.config.autoSyncLevel.icon)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("模式: \(automationManager.config.autoSyncLevel.displayName)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // 下次运行时间
                let nextRun = automationManager.nextScheduledRun
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("下次运行: \(nextRun, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // 失败状态提示
                if automationManager.failureCount > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("失败 \(automationManager.failureCount) 次")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // 快速操作按钮
                HStack(spacing: 8) {
                    // 立即运行按钮
                    Button(action: {
                        Task {
                            await automationManager.performDailySync()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.caption)
                            
                            Text("立即运行")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(.green)
                    }
                    .disabled(automationManager.isRunning || automationManager.config.autoSyncLevel == .manual)
                    
                    // 暂停/恢复按钮
                    Button(action: {
                        if automationManager.status == .paused {
                            automationManager.resumeAutomation()
                        } else {
                            automationManager.pauseAutomation()
                        }
                    }) {
                        HStack {
                            Image(systemName: automationManager.status == .paused ? "play.fill" : "pause.fill")
                                .font(.caption)
                            
                            Text(automationManager.status == .paused ? "恢复" : "暂停")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(.orange)
                    }
                    .disabled(automationManager.status == .disabled || automationManager.config.autoSyncLevel == .manual)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.automationBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 自动化进度指示器
struct AutomationProgressIndicator: View {
    @StateObject private var automationManager = AutomationManager.shared
    
    var body: some View {
        if automationManager.isRunning {
            VStack(spacing: 8) {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .automationBlue))
                    
                    Text("自动化运行中...")
                        .font(.caption)
                        .foregroundColor(.automationBlue)
                    
                    Spacer()
                }
                
                if let lastRun = automationManager.lastAutomationRun {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("开始时间: \(lastRun, style: .time)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.automationBlue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.automationBlue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - 自动化简易配置卡片
struct AutomationQuickConfigCard: View {
    @StateObject private var automationManager = AutomationManager.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.automationGreen)
                
                Text("快速配置")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            
            // 自动化级别快速切换
            HStack(spacing: 8) {
                ForEach(AutoSyncLevel.allCases, id: \.self) { level in
                    Button(action: {
                        automationManager.updateAutomationLevel(level)
                        alertMessage = "自动化模式已切换为: \(level.displayName)"
                        showingAlert = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: level.icon)
                                .font(.caption)
                            
                            Text(level.displayName.replacingOccurrences(of: "模式", with: ""))
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(automationManager.config.autoSyncLevel == level ? 
                                      Color.automationGreen.opacity(0.3) : 
                                      Color.gray.opacity(0.2)
                                )
                        )
                        .foregroundColor(automationManager.config.autoSyncLevel == level ? .white : .gray)
                    }
                }
            }
            
            // 智能触发开关
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("智能触发")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    
                    Text("自动检测时间并同步")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { automationManager.config.enableSmartTriggers },
                    set: { enabled in
                        automationManager.config.enableSmartTriggers = enabled
                        if automationManager.status == .enabled {
                            Task {
                                automationManager.stopAutomation()
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                automationManager.startAutomation()
                            }
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .automationGreen))
                .scaleEffect(0.8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.automationGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AutomationQuickStatusCard()
        AutomationProgressIndicator()
        AutomationQuickConfigCard()
    }
    .padding()
    .background(Color.black)
} 