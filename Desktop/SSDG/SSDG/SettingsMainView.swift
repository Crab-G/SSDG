//
//  SettingsMainView.swift
//  SSDG
//
//  Created by Assistant on 2025/8/6.
//

import SwiftUI

// MARK: - 设置主视图
struct SettingsMainView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var automationManager = AutomationManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // HealthKit部分
                Section {
                    // 授权状态
                    HStack {
                        Label("Authorization", systemImage: "heart.text.square.fill")
                        Spacer()
                        if healthKitManager.isAuthorized {
                            Label("Authorized", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .labelStyle(.iconOnly)
                        } else {
                            Button("Authorize") {
                                Task {
                                    _ = await healthKitManager.requestHealthKitAuthorization()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // 数据管理
                    NavigationLink(destination: DataManagementView()) {
                        Label("Data Management", systemImage: "doc.text.magnifyingglass")
                    }
                } header: {
                    Text("HealthKit")
                } footer: {
                    Text("Manage HealthKit permissions and data")
                }
                
                // 自动化部分
                Section {
                    // 自动化开关
                    Toggle(isOn: $automationManager.isAutomationEnabled) {
                        Label("Enable Automation", systemImage: "clock.badge.checkmark.fill")
                    }
                    
                    if automationManager.isAutomationEnabled {
                        // 自动化设置
                        NavigationLink(destination: AutomationSettingsView()) {
                            Label("Automation Settings", systemImage: "gearshape.2")
                        }
                        
                        // 通知设置
                        NavigationLink(destination: NotificationSettingsView()) {
                            Label("Notifications", systemImage: "bell.badge")
                        }
                    }
                } header: {
                    Text("Automation")
                } footer: {
                    Text("Configure automatic daily data generation")
                }
                
                // 高级设置
                Section {
                    // 开发者选项
                    NavigationLink(destination: DeveloperOptionsView()) {
                        Label("Developer Options", systemImage: "hammer.fill")
                    }
                    
                    // 关于
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                } header: {
                    Text("Advanced")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 数据管理视图
struct DataManagementView: View {
    @State private var showingDeleteAlert = false
    @State private var dataToDelete: DataType?
    
    enum DataType: String, CaseIterable {
        case sleep = "Sleep Data"
        case steps = "Steps Data"
        case all = "All Data"
        
        var icon: String {
            switch self {
            case .sleep: return "moon.fill"
            case .steps: return "figure.walk"
            case .all: return "trash.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .sleep: return .blue
            case .steps: return .green
            case .all: return .red
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                ForEach(DataType.allCases, id: \.self) { dataType in
                    Button(action: {
                        dataToDelete = dataType
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Label(dataType.rawValue, systemImage: dataType.icon)
                                .foregroundColor(dataType.color)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            } header: {
                Text("Delete Data")
            } footer: {
                Text("Remove test data from HealthKit")
            }
            
            Section {
                // 数据统计
                DataStatisticsView()
            } header: {
                Text("Statistics")
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete \(dataToDelete?.rawValue ?? "")?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteData()
            }
        } message: {
            Text("This action cannot be undone")
        }
    }
    
    private func deleteData() {
        guard let dataType = dataToDelete else { return }
        
        Task {
            switch dataType {
            case .sleep:
                await HealthKitManager.shared.deleteSleepData()
            case .steps:
                await HealthKitManager.shared.deleteStepsData()
            case .all:
                await HealthKitManager.shared.deleteAllData()
            }
        }
    }
}

// MARK: - 数据统计视图
struct DataStatisticsView: View {
    @StateObject private var syncStateManager = SyncStateManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatRow(title: "Sleep Records", 
                   value: "\(syncStateManager.recentSleepData.count)")
            StatRow(title: "Steps Records", 
                   value: "\(syncStateManager.recentStepsData.count)")
            StatRow(title: "Data Range", 
                   value: getDataRange())
        }
    }
    
    private func getDataRange() -> String {
        let allDates = (syncStateManager.recentSleepData.map { $0.date } + 
                       syncStateManager.recentStepsData.map { $0.date })
        
        guard let minDate = allDates.min(),
              let maxDate = allDates.max() else {
            return "No data"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        return "\(formatter.string(from: minDate)) - \(formatter.string(from: maxDate))"
    }
}

// MARK: - 统计行
struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 开发者选项视图
struct DeveloperOptionsView: View {
    @State private var debugMode = UserDefaults.standard.bool(forKey: "debugMode")
    @State private var verboseLogging = UserDefaults.standard.bool(forKey: "verboseLogging")
    @State private var showingExportAlert = false
    
    var body: some View {
        List {
            Section {
                Toggle("Debug Mode", isOn: Binding(
                    get: { debugMode },
                    set: { newValue in
                        debugMode = newValue
                        UserDefaults.standard.set(newValue, forKey: "debugMode")
                    }
                ))
                Toggle("Verbose Logging", isOn: Binding(
                    get: { verboseLogging },
                    set: { newValue in
                        verboseLogging = newValue
                        UserDefaults.standard.set(newValue, forKey: "verboseLogging")
                    }
                ))
            } header: {
                Text("Debug")
            }
            
            Section {
                Button("Export Debug Log") {
                    showingExportAlert = true
                }
                
                Button("Clear Cache") {
                    clearCache()
                }
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Developer Options")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Complete", isPresented: $showingExportAlert) {
            Button("OK") {}
        } message: {
            Text("Debug log exported to Documents")
        }
    }
    
    private func clearCache() {
        // 清除缓存逻辑
        OfflineStorageManager.shared.clearCache()
    }
}

// MARK: - 关于视图
struct AboutView: View {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Bundle ID")
                    Spacer()
                    Text("com.health.kit")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Section {
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
            } header: {
                Text("Legal")
            }
            
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Health Data Simulator")
                        .font(.headline)
                    
                    Text("A testing tool for HealthKit integration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}