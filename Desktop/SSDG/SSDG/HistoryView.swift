//
//  HistoryView.swift
//  SSDG
//
//  Created by Assistant on 2025/8/6.
//

import SwiftUI

// MARK: - 历史数据视图
struct HistoryView: View {
    @StateObject private var syncStateManager = SyncStateManager.shared
    @State private var showingGenerateSheet = false
    @State private var selectedDateRange = DateRange.week
    
    enum DateRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 日期范围选择器
                    Picker("Date Range", selection: $selectedDateRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 数据概览卡片
                    DataOverviewCard(dateRange: selectedDateRange)
                        .padding(.horizontal)
                    
                    // 历史数据列表
                    HistoricalDataList()
                        .padding(.horizontal)
                    
                    // 生成历史数据按钮
                    Button(action: { showingGenerateSheet = true }) {
                        Label("Generate Historical Data", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingGenerateSheet) {
            HistoricalDataGenerationSheet()
        }
    }
}

// MARK: - 数据概览卡片
struct DataOverviewCard: View {
    let dateRange: HistoryView.DateRange
    @StateObject private var syncStateManager = SyncStateManager.shared
    
    var averageSleep: Double {
        let recentSleep = syncStateManager.recentSleepData
            .prefix(dateRange.days)
            .map { $0.duration }
        guard !recentSleep.isEmpty else { return 0 }
        return recentSleep.reduce(0, +) / Double(recentSleep.count)
    }
    
    var averageSteps: Int {
        let recentSteps = syncStateManager.recentStepsData
            .prefix(dateRange.days)
            .map { $0.totalSteps }
        guard !recentSteps.isEmpty else { return 0 }
        return recentSteps.reduce(0, +) / recentSteps.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(dateRange.rawValue) Overview")
                .font(.headline)
            
            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Avg Sleep", systemImage: "moon.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f hours", averageSleep))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Avg Steps", systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(averageSteps)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - 历史数据列表
struct HistoricalDataList: View {
    @StateObject private var syncStateManager = SyncStateManager.shared
    
    var sortedData: [(date: Date, sleep: SleepData?, steps: StepsData?)] {
        var combined: [(date: Date, sleep: SleepData?, steps: StepsData?)] = []
        
        // 组合睡眠和步数数据
        let allDates = Set(syncStateManager.recentSleepData.map { $0.date } + 
                          syncStateManager.recentStepsData.map { $0.date })
        
        for date in allDates {
            let sleep = syncStateManager.recentSleepData.first { 
                Calendar.current.isDate($0.date, inSameDayAs: date)
            }
            let steps = syncStateManager.recentStepsData.first {
                Calendar.current.isDate($0.date, inSameDayAs: date)
            }
            combined.append((date: date, sleep: sleep, steps: steps))
        }
        
        return combined.sorted { $0.date > $1.date }.prefix(7).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Data")
                .font(.headline)
            
            if sortedData.isEmpty {
                Text("No historical data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(sortedData, id: \.date) { item in
                    HistoricalDataRow(
                        date: item.date,
                        sleep: item.sleep,
                        steps: item.steps
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - 历史数据行
struct HistoricalDataRow: View {
    let date: Date
    let sleep: SleepData?
    let steps: StepsData?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    if let sleep = sleep {
                        Label(String(format: "%.1fh", sleep.duration), 
                              systemImage: "moon.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if let steps = steps {
                        Label("\(steps.totalSteps)", 
                              systemImage: "figure.walk")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 历史数据生成表单
struct HistoricalDataGenerationSheet: View {
    @State private var selectedDays = 30
    @State private var isGenerating = false
    @State private var progress: Double = 0
    @Environment(\.dismiss) private var dismiss
    
    let dayOptions = [7, 30, 90, 180, 365]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 标题部分
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Generate Historical Data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Create realistic health data for testing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                
                // 天数选择
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Duration")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(dayOptions, id: \.self) { days in
                            DayOptionButton(
                                days: days,
                                isSelected: selectedDays == days,
                                action: { selectedDays = days }
                            )
                        }
                    }
                    
                    // 自定义滑块
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom: \(selectedDays) days")
                            .font(.subheadline)
                        
                        Slider(value: Binding(
                            get: { Double(selectedDays) },
                            set: { selectedDays = Int($0) }
                        ), in: 1...365, step: 1)
                        .accentColor(.blue)
                    }
                    .padding(.top)
                }
                .padding(.horizontal)
                
                // 进度指示器
                if isGenerating {
                    VStack(spacing: 12) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("Generating data...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 生成按钮
                Button(action: startGeneration) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isGenerating ? "Generating..." : "Generate Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isGenerating ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isGenerating)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isGenerating)
                }
            }
        }
    }
    
    private func startGeneration() {
        isGenerating = true
        progress = 0
        
        Task {
            await generateHistoricalData()
            await MainActor.run {
                isGenerating = false
                dismiss()
            }
        }
    }
    
    private func generateHistoricalData() async {
        guard let user = SyncStateManager.shared.currentUser else { return }
        
        // 一次性生成所有历史数据
        let data = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: user,
            days: selectedDays,
            mode: .simple
        )
        
        // 分批写入HealthKit以显示进度
        let batchSize = 10
        let totalDays = data.sleepData.count
        let totalBatches = (totalDays + batchSize - 1) / batchSize
        
        for batch in 0..<totalBatches {
            let startIndex = batch * batchSize
            let endIndex = min((batch + 1) * batchSize, totalDays)
            
            // 获取这批数据
            let batchSleepData = Array(data.sleepData[startIndex..<endIndex])
            let batchStepsData = Array(data.stepsData[startIndex..<endIndex])
            
            // 写入HealthKit
            _ = await HealthKitManager.shared.replaceOrWriteData(
                user: user,
                sleepData: batchSleepData,
                stepsData: batchStepsData,
                mode: .simple
            )
            
            // 更新进度
            await MainActor.run {
                progress = Double(endIndex) / Double(totalDays)
            }
        }
    }
}

// MARK: - 天数选项按钮
struct DayOptionButton: View {
    let days: Int
    let isSelected: Bool
    let action: () -> Void
    
    var label: String {
        switch days {
        case 7: return "Week"
        case 30: return "Month"
        case 90: return "Quarter"
        case 180: return "6 Months"
        case 365: return "Year"
        default: return "\(days) days"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(days)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(10)
        }
    }
}