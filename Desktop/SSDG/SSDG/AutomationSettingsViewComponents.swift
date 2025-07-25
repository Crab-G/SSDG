//
//  AutomationSettingsViewComponents.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI

// MARK: - 通知设置卡片
struct NotificationSettingsCard: View {
    @ObservedObject var automationManager: AutomationManager
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("通知设置")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 启用通知
                HStack {
                    Toggle("启用通知", isOn: Binding(
                        get: { automationManager.config.enableNotifications },
                        set: { newValue in
                            automationManager.config.enableNotifications = newValue
                            automationManager.saveConfiguration()
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                }
                
                if automationManager.config.enableNotifications {
                    // 通知类型配置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("通知类型")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 6) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text("同步成功通知")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("✓")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                
                                Text("同步失败通知")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("✓")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            
                            if automationManager.config.autoSyncLevel == .semiAutomatic {
                                HStack {
                                    Image(systemName: "hand.tap.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    
                                    Text("确认同步提醒")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("✓")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                                
                                Text("周报总结")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("✓")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // 测试通知按钮
                    Button(action: {
                        Task {
                            await notificationManager.sendTestNotification()
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                                .font(.caption)
                            
                            Text("发送测试通知")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.2))
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
                                gradient: Gradient(colors: [Color.orange.opacity(0.6), Color.red.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 高级设置卡片
struct AdvancedSettingsCard: View {
    @ObservedObject var automationManager: AutomationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("高级设置")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 失败重试
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("失败重试")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Text("同步失败时自动重试")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { automationManager.config.enableRetryOnFailure },
                        set: { newValue in
                            automationManager.config.enableRetryOnFailure = newValue
                            automationManager.saveConfiguration()
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                if automationManager.config.enableRetryOnFailure {
                    HStack {
                        Text("重试次数: \(automationManager.config.maxRetryAttempts)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Stepper("", value: Binding(
                            get: { automationManager.config.maxRetryAttempts },
                            set: { newValue in
                                automationManager.config.maxRetryAttempts = max(1, min(10, newValue))
                                automationManager.saveConfiguration()
                            }
                        ), in: 1...10)
                    }
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // 低电量模式
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("低电量优化")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Text("低电量时暂停非关键自动化")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { automationManager.config.enableLowPowerMode },
                        set: { newValue in
                            automationManager.config.enableLowPowerMode = newValue
                            automationManager.saveConfiguration()
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // 数据连续性
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("数据连续性")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Text("自动检测和修复数据断层")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { automationManager.config.enableDataContinuity },
                        set: { newValue in
                            automationManager.config.enableDataContinuity = newValue
                            automationManager.saveConfiguration()
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
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

// MARK: - 自动化控制按钮
struct AutomationControlButtons: View {
    let status: AutomationStatus
    let onStart: () -> Void
    let onStop: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("自动化控制")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                // 启动按钮
                Button(action: onStart) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.title3)
                        
                        Text("启动")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.mint]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(status == .enabled || status == .running)
                .opacity((status == .enabled || status == .running) ? 0.5 : 1.0)
                
                // 暂停/恢复按钮
                Button(action: status == .paused ? onResume : onPause) {
                    HStack {
                        Image(systemName: status == .paused ? "play.fill" : "pause.fill")
                            .font(.title3)
                        
                        Text(status == .paused ? "恢复" : "暂停")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange, Color.yellow]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(status == .disabled)
                .opacity(status == .disabled ? 0.5 : 1.0)
                
                // 停止按钮
                Button(action: onStop) {
                    HStack {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                        
                        Text("停止")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.red, Color.pink]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(status == .disabled)
                .opacity(status == .disabled ? 0.5 : 1.0)
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
                                gradient: Gradient(colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 自动化日志卡片
struct AutomationLogCard: View {
    let automationLog: [AutomationLogEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text("自动化日志")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(automationLog.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if automationLog.isEmpty {
                Text("暂无日志记录")
                    .font(.body)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(automationLog.prefix(10)) { entry in
                            AutomationLogItem(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 200)
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
    }
}

// MARK: - 自动化日志项
struct AutomationLogItem: View {
    let entry: AutomationLogEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.type.icon)
                .font(.caption)
                .foregroundColor(entry.success ? .green : .red)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
        )
    }
} 