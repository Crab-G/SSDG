//
//  UIComponents.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI
import HealthKit

// MARK: - 用户信息卡片
struct UserInfoCard: View {
    let user: VirtualUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("当前用户信息")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("ID: \(user.id.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                UserInfoItem(title: "年龄", value: "\(user.age)岁", icon: "calendar")
                UserInfoItem(title: "性别", value: user.gender.displayName, icon: "person.fill")
                UserInfoItem(title: "身高", value: user.formattedHeight, icon: "ruler")
                UserInfoItem(title: "体重", value: user.formattedWeight, icon: "scalemass")
                UserInfoItem(title: "BMI", value: "\(user.formattedBMI) (\(user.bmiCategory))", icon: "heart.text.square")
                UserInfoItem(title: "睡眠基准", value: user.formattedSleepBaseline, icon: "moon.stars")
                UserInfoItem(title: "步数基准", value: "\(user.stepsBaseline)步", icon: "figure.walk")
                PersonalizedTagsItem(user: user)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 历史数据状态卡片
struct HistoricalDataStatusCard: View {
    let status: HistoricalDataStatus
    let dataCount: Int
    let generatedDate: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: getStatusIcon())
                    .font(.title2)
                    .foregroundColor(getStatusColor())
                
                Text("历史数据状态")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                StatusBadge(status: status)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("状态描述:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(status.description)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                if status == .generated {
                    HStack {
                        Text("数据天数:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("\(dataCount) 天")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    
                    if let generatedDate = generatedDate {
                        HStack {
                            Text("生成时间:")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(DateFormatter.localizedString(from: generatedDate, dateStyle: .short, timeStyle: .short))
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                if status == .generating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.orange)
                        
                        Text("正在生成历史数据，请稍候...")
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
                        .stroke(getStatusColor().opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func getStatusIcon() -> String {
        switch status {
        case .notGenerated:
            return "chart.line.uptrend.xyaxis.circle"
        case .generating:
            return "arrow.2.circlepath"
        case .generated:
            return "chart.line.uptrend.xyaxis.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func getStatusColor() -> Color {
        switch status {
        case .notGenerated:
            return .gray
        case .generating:
            return .orange
        case .generated:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - 状态标签
struct StatusBadge: View {
    let status: HistoricalDataStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(getStatusColor())
            )
    }
    
    private func getStatusColor() -> Color {
        switch status {
        case .notGenerated:
            return .gray
        case .generating:
            return .orange
        case .generated:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - 占位符用户卡片
struct PlaceholderUserCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无用户信息")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("点击生成新用户按钮创建虚拟用户")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 用户信息项
struct UserInfoItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
}

// MARK: - 历史数据卡片
struct HistoricalDataCard: View {
    let sleepData: [SleepData]
    let stepsData: [StepsData]
    let isImported: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("历史数据统计")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // 导入状态指示器
                if isImported {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("已导入")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.2))
                    )
                }
                
                Text("\(sleepData.count) 天")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                // 睡眠统计
                let averageSleep = sleepData.map { $0.totalSleepHours }.reduce(0, +) / Double(sleepData.count)
                let minSleep = sleepData.map { $0.totalSleepHours }.min() ?? 0
                let maxSleep = sleepData.map { $0.totalSleepHours }.max() ?? 0
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("睡眠统计")
                            .font(.subheadline.bold())
                            .foregroundColor(.purple)
                        
                        Text("平均: \(String(format: "%.1f", averageSleep))h")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("范围: \(String(format: "%.1f", minSleep))-\(String(format: "%.1f", maxSleep))h")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "moon.fill")
                        .font(.title)
                        .foregroundColor(.purple)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // 步数统计
                let averageSteps = stepsData.map { $0.totalSteps }.reduce(0, +) / stepsData.count
                let minSteps = stepsData.map { $0.totalSteps }.min() ?? 0
                let maxSteps = stepsData.map { $0.totalSteps }.max() ?? 0
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("步数统计")
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                        
                        Text("平均: \(averageSteps) 步")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("范围: \(minSteps)-\(maxSteps) 步")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "figure.walk")
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
            
            // 导入提示
            if !isImported {
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("点击下方按钮可将历史数据导入到苹果健康应用")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 快速统计卡片
struct QuickStatsCard: View {
    let user: VirtualUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speedometer")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("用户概况")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatItem(title: "健康评分", value: getHealthScore(user), color: .green)
                StatItem(title: "活跃度", value: user.stepsBaselineDescription, color: .orange)
                StatItem(title: "睡眠类型", value: user.sleepBaselineDescription, color: .purple)
                StatItem(title: "BMI状态", value: user.bmiCategory, color: getBMIColor(user.bmi))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func getHealthScore(_ user: VirtualUser) -> String {
        let score = min(100, max(60, Int(90 - abs(user.bmi - 22) * 5)))
        return "\(score)分"
    }
    
    private func getBMIColor(_ bmi: Double) -> Color {
        switch bmi {
        case 18.5..<24:
            return .green
        case 24..<28:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - 统计项
struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
}

// MARK: - 数据质量卡片
struct DataQualityCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("数据质量")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("优秀")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                QualityItem(title: "数据一致性", score: 95, color: .green)
                QualityItem(title: "生物合理性", score: 92, color: .green)
                QualityItem(title: "变异性", score: 88, color: .orange)
                QualityItem(title: "完整性", score: 100, color: .green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 质量项
struct QualityItem: View {
    let title: String
    let score: Int
    let color: Color
    
    // 安全的评分值
    private var safeScore: Double {
        let scoreValue = Double(score)
        guard scoreValue.isFinite && !scoreValue.isNaN else { return 0.0 }
        return max(0.0, min(100.0, scoreValue))
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 8) {
                ProgressView(value: max(0.0, min(100.0, safeScore)), total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .frame(width: 60)
                
                Text("\(score)%")
                    .font(.caption.bold())
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - 趋势分析卡片
struct TrendAnalysisCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text("趋势分析")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {}) {
                    Text("查看详情")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
            }
            
            VStack(spacing: 12) {
                TrendItem(title: "睡眠趋势", trend: "稳定", icon: "moon.fill", color: .purple)
                TrendItem(title: "活动趋势", trend: "上升", icon: "figure.walk", color: .green)
                TrendItem(title: "健康指数", trend: "优良", icon: "heart.fill", color: .red)
            }
            
            Text("基于最近30天数据分析")
                .font(.caption)
                .foregroundColor(.gray)
                .italic()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 趋势项
struct TrendItem: View {
    let title: String
    let trend: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(trend)
                    .font(.caption)
                    .foregroundColor(color)
            }
            
            Spacer()
            
            Image(systemName: getTrendIcon(trend))
                .font(.caption)
                .foregroundColor(color)
        }
    }
    
    private func getTrendIcon(_ trend: String) -> String {
        switch trend {
        case "上升":
            return "arrow.up.right"
        case "下降":
            return "arrow.down.right"
        case "稳定":
            return "arrow.right"
        default:
            return "minus"
        }
    }
}

// MARK: - 应用信息卡片
struct AppInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("应用信息")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                InfoRow(title: "应用名称", value: "HealthKit")
                InfoRow(title: "版本", value: "1.0.0")
                InfoRow(title: "构建版本", value: "2025.01.12")
                InfoRow(title: "开发者", value: "谢铭麟")
                InfoRow(title: "支持设备", value: "iPhone, iPad")
                InfoRow(title: "系统要求", value: "iOS 14.0+")
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("功能特性")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    FeatureRow(text: "• 智能虚拟用户生成")
                    FeatureRow(text: "• 真实健康数据模拟")
                    FeatureRow(text: "• Apple Health 集成")
                    FeatureRow(text: "• 每日自动同步")
                    FeatureRow(text: "• 数据质量分析")
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 信息行
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
    }
}

// MARK: - 特性行
struct FeatureRow: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.gray)
    }
}

// MARK: - 个性化标签项
struct PersonalizedTagsItem: View {
    let user: VirtualUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                Text("个性化标签")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "moon.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    
                    Text(user.personalizedProfile.sleepType.displayName)
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
                
                HStack {
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Text(user.personalizedProfile.activityLevel.displayName)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
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