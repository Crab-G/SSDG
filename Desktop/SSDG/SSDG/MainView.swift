//
//  MainView.swift
//  SSDG
//
//  Created by Assistant on 2025/8/6.
//

import SwiftUI

// MARK: - 主界面（符合Apple设计规范）
struct MainView: View {
    @StateObject private var syncStateManager = SyncStateManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var automationManager = AutomationManager.shared
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 今日数据
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "heart.text.square.fill")
                }
                .tag(0)
            
            // 历史数据
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)
            
            // 用户管理
            UsersView()
                .tabItem {
                    Label("Users", systemImage: "person.2.fill")
                }
                .tag(2)
            
            // 设置
            SettingsMainView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .task {
            // 检查HealthKit权限
            if !healthKitManager.isAuthorized {
                _ = await healthKitManager.requestHealthKitAuthorization()
            }
            
            // 检查是否需要创建默认用户
            if syncStateManager.currentUser == nil {
                let user = VirtualUserGenerator.generateRandomUser()
                syncStateManager.updateUser(user)
            }
        }
    }
}

// MARK: - 今日数据视图
struct TodayView: View {
    @StateObject private var syncStateManager = SyncStateManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var automationManager = AutomationManager.shared
    
    @State private var isGenerating = false
    @State private var showingGenerateOptions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户卡片
                    if let user = syncStateManager.currentUser {
                        UserCard(user: user)
                            .padding(.horizontal)
                    }
                    
                    // 今日数据状态
                    TodayDataStatusCard()
                        .padding(.horizontal)
                    
                    // 自动化状态
                    if automationManager.isAutomationEnabled {
                        AutomationStatusCardCompact()
                            .padding(.horizontal)
                    }
                    
                    // 操作按钮
                    VStack(spacing: 12) {
                        // 生成数据按钮
                        Button(action: { showingGenerateOptions = true }) {
                            Label("Generate Today's Data", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(isGenerating)
                        
                        // 智能补全按钮
                        Button(action: smartCompletion) {
                            Label("Smart Completion", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(isGenerating)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Health Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Image(systemName: "bell.badge")
                    }
                }
            }
        }
        .sheet(isPresented: $showingGenerateOptions) {
            GenerateDataOptionsSheet(isGenerating: $isGenerating)
        }
    }
    
    private func smartCompletion() {
        // 实现智能补全
        isGenerating = true
        Task {
            // 调用智能补全逻辑
            await MainActor.run {
                isGenerating = false
            }
        }
    }
}

// MARK: - 用户卡片
struct UserCard: View {
    let user: VirtualUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(user.gender.displayName), \(user.age) years")
                        .font(.headline)
                    Text(user.personalizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                DataPoint(
                    icon: "moon.fill",
                    value: String(format: "%.1fh", user.sleepBaseline),
                    label: "Sleep"
                )
                
                DataPoint(
                    icon: "figure.walk",
                    value: "\(user.stepsBaseline)",
                    label: "Steps"
                )
                
                DataPoint(
                    icon: "heart.fill",
                    value: String(format: "%.1f", user.bmi),
                    label: "BMI"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - 数据点组件
struct DataPoint: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 今日数据状态卡片
struct TodayDataStatusCard: View {
    @StateObject private var syncStateManager = SyncStateManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Status")
                    .font(.headline)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                StatusItem(
                    title: "Sleep",
                    icon: "moon.zzz.fill",
                    status: syncStateManager.todaySleepData != nil ? .complete : .pending,
                    value: syncStateManager.todaySleepData != nil ? 
                        String(format: "%.1fh", syncStateManager.todaySleepData!.duration) : "--"
                )
                
                StatusItem(
                    title: "Steps",
                    icon: "figure.walk.circle.fill",
                    status: syncStateManager.todayStepsData != nil ? .complete : .pending,
                    value: syncStateManager.todayStepsData != nil ?
                        "\(syncStateManager.todayStepsData!.totalSteps)" : "--"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - 状态项组件
struct StatusItem: View {
    let title: String
    let icon: String
    let status: DataStatus
    let value: String
    
    enum DataStatus {
        case pending, complete
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .complete: return .green
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(status.color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 自动化状态卡片（紧凑版）
struct AutomationStatusCardCompact: View {
    @StateObject private var automationManager = AutomationManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: "clock.badge.checkmark.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Automation Active")
                    .font(.headline)
                Text("Next sync: \(automationManager.nextSyncTime ?? "Tomorrow 6:00 AM")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            NavigationLink(destination: AutomationSettingsView()) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - 生成数据选项表单
struct GenerateDataOptionsSheet: View {
    @Binding var isGenerating: Bool
    @State private var generateSleep = true
    @State private var generateSteps = true
    @State private var selectedMode: DataMode = .simple
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Data Types") {
                    Toggle("Sleep Data", isOn: $generateSleep)
                    Toggle("Steps Data", isOn: $generateSteps)
                }
                
                Section("Mode") {
                    Picker("Data Mode", selection: $selectedMode) {
                        Text("Simple (iPhone Only)").tag(DataMode.simple)
                        Text("Wearable Device").tag(DataMode.wearableDevice)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button(action: startGeneration) {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Generate Data")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isGenerating || (!generateSleep && !generateSteps))
                }
            }
            .navigationTitle("Generate Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func startGeneration() {
        isGenerating = true
        Task {
            // 实现数据生成逻辑
            await generateData()
            await MainActor.run {
                isGenerating = false
                dismiss()
            }
        }
    }
    
    private func generateData() async {
        guard let user = SyncStateManager.shared.currentUser else { return }
        
        let todayData = PersonalizedDataGenerator.generatePersonalizedDailyData(
            for: user,
            date: Date(),
            recentSleepData: SyncStateManager.shared.recentSleepData,
            recentStepsData: SyncStateManager.shared.recentStepsData,
            mode: selectedMode
        )
        
        // 写入HealthKit
        if generateSleep, let sleepData = todayData.sleepData {
            _ = await HealthKitManager.shared.writeSleepData([sleepData], mode: selectedMode, user: user)
        }
        
        if generateSteps {
            _ = await HealthKitManager.shared.writeStepsData([todayData.stepsData], user: user)
        }
        
        // 更新状态
        await MainActor.run {
            if let sleepData = todayData.sleepData {
                SyncStateManager.shared.updateTodaySleepData(sleepData)
            }
            SyncStateManager.shared.updateTodayStepsData(todayData.stepsData)
        }
    }
}

// MARK: - 预览
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}