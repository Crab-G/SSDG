//
//  PersonalizedUserGenerationSheet.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI

// MARK: - 个性化用户生成表单
struct PersonalizedUserGenerationSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedSleepType: SleepType
    @Binding var selectedActivityLevel: ActivityLevel
    let onGenerate: () -> Void
    
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
                            Image(systemName: "person.2.badge.gearshape.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.purple)
                            
                            Text("个性化用户生成")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("选择睡眠类型和活动水平，生成具有真实个性化习惯的虚拟用户")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // 睡眠类型选择
                        SleepTypeSelectionCard(selectedSleepType: $selectedSleepType)
                        
                        // 活动水平选择
                        ActivityLevelSelectionCard(selectedActivityLevel: $selectedActivityLevel)
                        
                        // 预览信息
                        PersonalizedUserPreviewCard(
                            sleepType: selectedSleepType,
                            activityLevel: selectedActivityLevel
                        )
                        
                        // 生成按钮
                        Button(action: {
                            onGenerate()
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .font(.title2)
                                
                                Text("生成个性化用户")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        
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
            }
        }
    }
}

// MARK: - 睡眠类型选择卡片
struct SleepTypeSelectionCard: View {
    @Binding var selectedSleepType: SleepType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text("睡眠类型")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(SleepType.allCases, id: \.self) { sleepType in
                    SleepTypeOptionView(
                        sleepType: sleepType,
                        isSelected: selectedSleepType == sleepType,
                        onSelect: { selectedSleepType = sleepType }
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

// MARK: - 睡眠类型选项视图
struct SleepTypeOptionView: View {
    let sleepType: SleepType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .cyan : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(sleepType.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text(sleepTypeDescription(sleepType))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.cyan.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func sleepTypeDescription(_ type: SleepType) -> String {
        let range = type.sleepTimeRange
        let duration = type.durationRange
        
        switch type {
        case .nightOwl:
            return "凌晨\(range.start):00-下午\(range.end):00 • \(duration.min)-\(duration.max)小时"
        case .earlyBird:
            return "晚上\(range.start):00-早上\(range.end):00 • \(duration.min)-\(duration.max)小时"
        case .irregular:
            return "不规律作息 • \(duration.min)-\(duration.max)小时，变化很大"
        case .normal:
            return "晚上\(range.start):00-早上\(range.end):00 • \(duration.min)-\(duration.max)小时"
        }
    }
}

// MARK: - 活动水平选择卡片
struct ActivityLevelSelectionCard: View {
    @Binding var selectedActivityLevel: ActivityLevel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.walk.motion")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("活动水平")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(ActivityLevel.allCases, id: \.self) { activityLevel in
                    ActivityLevelOptionView(
                        activityLevel: activityLevel,
                        isSelected: selectedActivityLevel == activityLevel,
                        onSelect: { selectedActivityLevel = activityLevel }
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

// MARK: - 活动水平选项视图
struct ActivityLevelOptionView: View {
    let activityLevel: ActivityLevel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // 选择指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(activityLevel.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text(activityLevelDescription(activityLevel))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 步数范围指示器
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(activityLevel.stepRange.min)-\(activityLevel.stepRange.max)")
                        .font(.caption.bold())
                        .foregroundColor(isSelected ? .green : .gray)
                    
                    Text("步/天")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func activityLevelDescription(_ level: ActivityLevel) -> String {
        switch level {
        case .low:
            return "久坐为主，很少运动"
        case .medium:
            return "日常活动，偶尔运动"
        case .high:
            return "经常运动，活跃生活"
        case .veryHigh:
            return "高强度运动，专业运动员"
        }
    }
}

// MARK: - 个性化用户预览卡片
struct PersonalizedUserPreviewCard: View {
    let sleepType: SleepType
    let activityLevel: ActivityLevel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("用户预览")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("🏷️ 个性化标签")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(sleepType.displayName) + \(activityLevel.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                VStack(spacing: 8) {
                    HStack {
                        Text("💤 睡眠模式")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                        
                        Spacer()
                        
                        Text("规律性: \(Int(sleepType.consistency * 100))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("🚶‍♂️ 活动强度")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Text("系数: \(String(format: "%.1f", activityLevel.intensityMultiplier))x")
                            .font(.caption)
                            .foregroundColor(.gray)
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

#Preview {
    PersonalizedUserGenerationSheet(
        selectedSleepType: .constant(.normal),
        selectedActivityLevel: .constant(.medium),
        onGenerate: {}
    )
} 