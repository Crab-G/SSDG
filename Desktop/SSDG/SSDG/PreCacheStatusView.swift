import SwiftUI

// MARK: - 预缓存数据预览类型
struct DailyDataPreview {
    let date: Date
    let sleepHours: Double
    let steps: Int
    let quality: String
    let completionStatus: String
    
    var dateDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
    
    var sleepDescription: String {
        return "睡眠: \(String(format: "%.1f", sleepHours))小时 · \(quality)"
    }
    
    var stepDescription: String {
        return "步数: \(steps.formatted()) 步"
    }
    
    var sleepImportTime: Date? {
        // 模拟起床时间，基于睡眠时长计算
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let wakeTime = calendar.date(byAdding: .hour, value: Int(7 + sleepHours), to: startOfDay)
        return wakeTime
    }
}

/// 预缓存状态视图
struct PreCacheStatusView: View {
    @StateObject private var automationManager = AutomationManager.shared
    @StateObject private var preCacheSystem = WeeklyPreCacheSystem.shared
    @StateObject private var smartExecutor = SmartExecutor.shared
    
    @State private var showDetailView = false
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 主状态卡片
            mainStatusCard
            
            // 数据预览卡片
            dataPreviewCards
            
            // 控制按钮
            controlButtons
            
            // 执行日志（可选）
            if showDetailView {
                executionLogView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("🚀 预缓存系统")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await refreshData()
        }
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - 主状态卡片
    
    private var mainStatusCard: some View {
        VStack(spacing: 16) {
            // 状态标题
            HStack {
                Text(preCacheSystem.cacheStatus.emoji)
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("预缓存系统")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(getStatusDescription())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 状态指示器
                Circle()
                    .fill(getStatusColor())
                    .frame(width: 12, height: 12)
            }
            
            // 进度指示
            if smartExecutor.totalBatches > 0 {
                progressIndicator
            }
            
            // 统计信息
            statisticsView
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 进度指示器
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text("今日执行进度")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(smartExecutor.completedBatches)/\(smartExecutor.totalBatches)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: max(0.0, min(1.0, safeExecutionProgress)), total: 1.0)
                .tint(.cyan)
                .scaleEffect(y: 1.5)
        }
    }
    
    // 安全的执行进度计算
    private var safeExecutionProgress: Double {
        let total = Double(smartExecutor.totalBatches)
        let completed = Double(smartExecutor.completedBatches)
        
        guard total > 0 else { return 0.0 }
        let progress = completed / total
        
        if progress.isFinite && !progress.isNaN {
            return max(0.0, min(1.0, progress))
        } else {
            return 0.0
        }
    }
    
    // MARK: - 统计信息
    
    private var statisticsView: some View {
        HStack(spacing: 20) {
            // 当前周状态
            StatisticItem(
                title: "当前周",
                value: preCacheSystem.currentWeekPackage != nil ? "✅" : "❌",
                subtitle: preCacheSystem.currentWeekPackage?.weekDescription ?? "未加载"
            )
            
            Divider()
                .frame(height: 30)
            
            // 下周状态
            StatisticItem(
                title: "下周",
                value: preCacheSystem.nextWeekPackage != nil ? "✅" : "❌",
                subtitle: preCacheSystem.nextWeekPackage?.weekDescription ?? "未生成"
            )
            
            Divider()
                .frame(height: 30)
            
            // 执行状态
            StatisticItem(
                title: "执行器",
                value: smartExecutor.executionStatus.emoji,
                subtitle: smartExecutor.executionStatus.displayName
            )
        }
    }
    
    // MARK: - 数据预览卡片
    
    private var dataPreviewCards: some View {
        VStack(spacing: 12) {
            // 今日数据预览
            if let todayPreview = automationManager.getTodayDataPreview() {
                DailyPreviewCard(preview: todayPreview, isToday: true)
            }
            
            // 明日数据预览
            if let tomorrowPreview = automationManager.getTomorrowDataPreview() {
                DailyPreviewCard(preview: tomorrowPreview, isToday: false)
            }
        }
    }
    
    // MARK: - 控制按钮
    
    private var controlButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 刷新按钮
                Button(action: {
                    Task { await refreshData() }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("刷新缓存")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing)
                
                // 重新生成按钮
                Button(action: {
                    Task { await forceRegenerate() }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("重新生成")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing)
            }
            
            HStack(spacing: 12) {
                // 执行剩余任务
                Button(action: {
                    Task { await executeRemaining() }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("执行剩余")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(smartExecutor.executionStatus == .completed)
                
                // 查看日志
                Button(action: {
                    showDetailView.toggle()
                }) {
                    HStack {
                        Image(systemName: showDetailView ? "eye.slash" : "eye")
                        Text(showDetailView ? "隐藏日志" : "查看日志")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - 执行日志视图
    
    private var executionLogView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("执行日志")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("清空日志") {
                    smartExecutor.clearLog()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(smartExecutor.executionLog.reversed()) { entry in
                        LogEntryRow(entry: entry)
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 辅助方法
    
    private func getStatusDescription() -> String {
        let status = automationManager.getPreCacheStatus()
        return status // getPreCacheStatus() 已经返回 String
    }
    
    private func getStatusColor() -> Color {
        switch preCacheSystem.cacheStatus {
        case .ready: return .green
        case .partial: return .orange
        case .generating: return .blue
        case .error: return .red
        case .empty: return .gray
        }
    }
    
    private func loadInitialData() async {
        // 初始化预缓存系统
        if automationManager.config.automationMode != .fullAutomatic {
            automationManager.enablePreCacheSystem()
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        await automationManager.refreshPreCacheData()
        isRefreshing = false
    }
    
    private func forceRegenerate() async {
        isRefreshing = true
        await automationManager.forceRegeneratePreCacheData()
        isRefreshing = false
    }
    
    private func executeRemaining() async {
        await automationManager.executeRemainingTasks()
    }
}

// MARK: - 统计项组件

struct StatisticItem: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 每日预览卡片

struct DailyPreviewCard: View {
    let preview: DailyDataPreview
    let isToday: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text(isToday ? "📅 今日计划" : "📋 明日计划")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(getStatusEmoji(for: preview.completionStatus))
                    .font(.title2)
                
                Text(preview.completionStatus)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(getStatusBackgroundColor())
                    .foregroundColor(getStatusTextColor())
                    .cornerRadius(4)
            }
            
            // 数据信息
            VStack(alignment: .leading, spacing: 6) {
                Text(preview.dateDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(preview.sleepDescription)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    if let sleepImportTime = preview.sleepImportTime {
                        Text("起床时间: \(sleepImportTime, style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(preview.stepDescription)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func getStatusBackgroundColor() -> Color {
        switch preview.completionStatus {
        case "等待中": return .gray.opacity(0.2)
        case "进行中": return .blue.opacity(0.2)
        case "睡眠完成": return .orange.opacity(0.2)
        case "已完成": return .green.opacity(0.2)
        default: return .gray.opacity(0.2)
        }
    }
    
    private func getStatusTextColor() -> Color {
        switch preview.completionStatus {
        case "等待中": return .gray
        case "进行中": return .blue
        case "睡眠完成": return .orange
        case "已完成": return .green
        default: return .gray
        }
    }
    
    private func getStatusEmoji(for status: String) -> String {
        switch status {
        case "等待中": return "⏳"
        case "进行中": return "🔄"
        case "睡眠完成": return "😴"
        case "已完成": return "✅"
        default: return "❓"
        }
    }
}

// MARK: - 日志条目行

struct LogEntryRow: View {
    let entry: ExecutionLogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.type.emoji)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.caption)
                    .foregroundColor(getTextColor())
                
                Text(entry.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private func getTextColor() -> Color {
        switch entry.type {
        case .error: return .red
        case .warning: return .orange
        case .success: return .green
        case .info: return .primary
        }
    }
}

// MARK: - 预览

struct PreCacheStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PreCacheStatusView()
        }
    }
} 