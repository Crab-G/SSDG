//
//  PersonalizedAutomationConfigSheet.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI

// MARK: - 个性化自动化配置类型
struct PersonalizedAutomationConfig {
    var autoSyncLevel: AutoSyncLevel = .manual
    var enableNotifications: Bool = true
    var enableRetryOnFailure: Bool = true
    var enableSmartTriggers: Bool = false
    var maxRetryAttempts: Int = 3
    var dailySyncTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    var dayEndSyncTime: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var wakeTimeDetection: Bool = true
    var sleepTimeDetection: Bool = true
    var enableLowPowerMode: Bool = false
    
    // 新增属性以兼容 QuickPersonalizedTest
    var automationMode: AutoSyncLevel {
        get { return autoSyncLevel }
        set { autoSyncLevel = newValue }
    }
    var enableRealTimeStepInjection: Bool = true
    var maxDailyStepIncrements: Int = 500
    var enableSmartSleepGeneration: Bool = true
    var stepInjectionDelay: TimeInterval = 0.05 // 50毫秒
    
    static func defaultConfig() -> PersonalizedAutomationConfig {
        return PersonalizedAutomationConfig()
    }
}

// MARK: - 个性化自动化配置表单
struct PersonalizedAutomationConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var config: PersonalizedAutomationConfig
    @Binding var isPresented: Bool
    
    init(config: Binding<PersonalizedAutomationConfig>, isPresented: Binding<Bool>) {
        self._config = config
        self._isPresented = isPresented
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
                    VStack(spacing: 24) {
                        // 头部说明
                        VStack(spacing: 12) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.purple)
                            
                            Text("个性化自动化配置")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("调整自动化参数以获得最佳体验")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // 自动化模式设置
                        AutomationModeSettings(config: $config)
                        
                        // 时间设置
                        TimeSettings(config: $config)
                        
                        // 睡眠数据设置
                        SleepDataSettings(config: $config)
                        
                        // 步数注入设置
                        StepInjectionSettings(config: $config)
                        
                        // 维护设置
                        MaintenanceSettings(config: $config)
                        
                        // 高级设置
                        AdvancedSettings(config: $config)
                        
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
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .font(.headline)
                }
            }
        }
    }
}

// MARK: - 自动化模式设置
struct AutomationModeSettings: View {
    @Binding var config: PersonalizedAutomationConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("自动化模式")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // 模式选择
                ForEach(AutoSyncLevel.allCases, id: \.self) { mode in
                    ModeSelectionCard(
                        mode: mode,
                        isSelected: config.autoSyncLevel == mode,
                        onSelect: { config.autoSyncLevel = mode }
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
                                gradient: Gradient(colors: [Color.green.opacity(0.6), Color.mint.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 睡眠数据设置
struct SleepDataSettings: View {
    @Binding var config: PersonalizedAutomationConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "moon.stars")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text("睡眠数据设置")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                InfoCard(
                    title: "智能生成时机",
                    content: "睡眠数据将在用户预设的起床时间自动生成，完全模拟真实设备的行为模式",
                    icon: "clock.badge.checkmark",
                    color: .cyan
                )
                
                InfoCard(
                    title: "个性化适配",
                    content: "基于用户的睡眠类型标签（夜猫型、早起型等）自动调整生成时间和睡眠模式",
                    icon: "person.2.badge.gearshape",
                    color: .purple
                )
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

// MARK: - 步数注入设置
struct StepInjectionSettings: View {
    @Binding var config: PersonalizedAutomationConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "syringe")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("步数注入设置")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // 重试设置
                SettingSlider(
                    title: "最大重试次数",
                    description: "同步失败时的最大重试次数",
                    value: Binding(
                        get: { Double(config.maxRetryAttempts) },
                        set: { config.maxRetryAttempts = Int($0) }
                    ),
                    range: 1...10,
                    step: 1,
                    icon: "arrow.clockwise",
                    color: .blue,
                    formatter: { "\(Int($0)) 次" }
                )
                
                InfoCard(
                    title: "微增量技术",
                    content: "采用分钟级时间戳和小步数增量，完美模拟Apple设备的传感器数据，确保数据的真实性和自然性",
                    icon: "waveform.path.ecg",
                    color: .blue
                )
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

// MARK: - 维护设置
struct MaintenanceSettings: View {
    @Binding var config: PersonalizedAutomationConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("维护设置")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // 智能触发器开关
                SettingToggle(
                    title: "启用智能触发器",
                    description: "根据设备状态智能调整同步时机",
                    isOn: $config.enableSmartTriggers,
                    icon: "brain",
                    color: .orange
                )
                
                // 低电量模式
                SettingToggle(
                    title: "低电量模式",
                    description: "在低电量时减少同步频率",
                    isOn: $config.enableLowPowerMode,
                    icon: "battery.25",
                    color: .yellow
                )
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

// MARK: - 高级设置
struct AdvancedSettings: View {
    @Binding var config: PersonalizedAutomationConfig
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.2.gobackward")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("高级设置")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // 性能模式说明
                InfoCard(
                    title: "性能优化",
                    content: "系统自动检测设备性能和电池状态，在低电量时自动降低注入频率，确保不影响设备正常使用",
                    icon: "battery.75",
                    color: .green
                )
                
                // 数据安全说明
                InfoCard(
                    title: "数据安全",
                    content: "所有个性化数据都标记有特殊元数据，支持选择性删除，不会影响其他健康数据",
                    icon: "shield.checkered",
                    color: .blue
                )
                
                // 重置按钮
                Button(action: { showingResetAlert = true }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.title3)
                        
                        Text("恢复默认设置")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.red, .pink]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .alert("恢复默认设置", isPresented: $showingResetAlert) {
                    Button("取消", role: .cancel) { }
                    Button("确认", role: .destructive) {
                        config = PersonalizedAutomationConfig()
                    }
                } message: {
                    Text("此操作将重置所有自动化配置到默认值，是否继续？")
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
                                gradient: Gradient(colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 设置开关组件
struct SettingToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(color)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 设置滑块组件
struct SettingSlider: View {
    let title: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let icon: String
    let color: Color
    let formatter: (Double) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(formatter(value))
                    .font(.subheadline.bold())
                    .foregroundColor(color)
                    .monospacedDigit()
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(color)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 信息卡片组件
struct InfoCard: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Text(content)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 时间设置
struct TimeSettings: View {
    @Binding var config: PersonalizedAutomationConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("时间设置")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // 每日同步时间
                DatePicker(
                    "每日同步时间",
                    selection: $config.dailySyncTime,
                    displayedComponents: [.hourAndMinute]
                )
                .foregroundColor(.white)
                .colorScheme(.dark)
                
                // 结束同步时间
                DatePicker(
                    "结束同步时间",
                    selection: $config.dayEndSyncTime,
                    displayedComponents: [.hourAndMinute]
                )
                .foregroundColor(.white)
                .colorScheme(.dark)
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
                                gradient: Gradient(colors: [Color.orange.opacity(0.6), Color.purple.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 模式选择卡片
struct ModeSelectionCard: View {
    let mode: AutoSyncLevel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 选择指示器
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 模式图标
                Image(systemName: modeIcon(for: mode))
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func modeIcon(for mode: AutoSyncLevel) -> String {
        switch mode {
        case .fullAutomatic:
            return "bolt.circle.fill"
        case .semiAutomatic:
            return "hand.tap"
        case .manual:
            return "hand.point.up"
        }
    }
}


#Preview {
    PersonalizedAutomationConfigSheet(
        config: .constant(PersonalizedAutomationConfig()),
        isPresented: .constant(true)
    )
} 