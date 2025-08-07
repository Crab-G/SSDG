//
//  UsersView.swift
//  SSDG
//
//  Created by Assistant on 2025/8/6.
//

import SwiftUI

// MARK: - 用户管理视图
struct UsersView: View {
    @StateObject private var syncStateManager = SyncStateManager.shared
    @State private var showingCreateUser = false
    @State private var users: [VirtualUser] = []
    
    var body: some View {
        NavigationView {
            List {
                // 当前用户部分
                if let currentUser = syncStateManager.currentUser {
                    Section("Current User") {
                        UserListRow(user: currentUser, isCurrent: true)
                    }
                }
                
                // 其他用户
                Section("Other Users") {
                    if users.isEmpty {
                        Text("No other users")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(users, id: \.id) { user in
                            UserListRow(user: user, isCurrent: false) {
                                switchToUser(user)
                            }
                        }
                        .onDelete(perform: deleteUsers)
                    }
                }
                
                // 创建新用户按钮
                Section {
                    Button(action: { showingCreateUser = true }) {
                        Label("Create New User", systemImage: "person.badge.plus")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingCreateUser) {
            CreateUserView { newUser in
                users.append(newUser)
            }
        }
        .onAppear {
            loadUsers()
        }
    }
    
    private func switchToUser(_ user: VirtualUser) {
        syncStateManager.updateUser(user)
    }
    
    private func deleteUsers(at offsets: IndexSet) {
        users.remove(atOffsets: offsets)
        saveUsers()
    }
    
    private func loadUsers() {
        // 从UserDefaults加载用户列表
        if let data = UserDefaults.standard.data(forKey: "SavedUsers"),
           let decoded = try? JSONDecoder().decode([VirtualUser].self, from: data) {
            users = decoded.filter { $0.id != syncStateManager.currentUser?.id }
        }
    }
    
    private func saveUsers() {
        // 保存用户列表到UserDefaults
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: "SavedUsers")
        }
    }
}

// MARK: - 用户列表行
struct UserListRow: View {
    let user: VirtualUser
    let isCurrent: Bool
    var onTap: (() -> Void)?
    
    var body: some View {
        HStack {
            // 用户头像
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Text(user.gender == .male ? "♂" : "♀")
                    .font(.title2)
                    .foregroundColor(isCurrent ? .white : .primary)
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                Text("\(user.gender.displayName), \(user.age) years")
                    .font(.headline)
                
                Text(user.personalizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Label(String(format: "%.1fh", user.sleepBaseline), 
                          systemImage: "moon.fill")
                        .font(.caption2)
                    
                    Label("\(user.stepsBaseline)", 
                          systemImage: "figure.walk")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - 创建用户视图
struct CreateUserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSleepType: SleepType = .normal
    @State private var selectedActivityLevel: ActivityLevel = .medium
    @State private var isCreating = false
    
    var onCreate: (VirtualUser) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                // 睡眠类型选择
                Section {
                    Picker("Sleep Type", selection: $selectedSleepType) {
                        ForEach(SleepType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    // 睡眠类型描述
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.blue)
                            Text(getSleepDescription(for: selectedSleepType))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Sleep Pattern")
                }
                
                // 活动水平选择
                Section {
                    Picker("Activity Level", selection: $selectedActivityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    
                    // 活动水平描述
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.green)
                            Text(getActivityDescription(for: selectedActivityLevel))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Activity Level")
                }
                
                // 预览部分
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("User Preview")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            PreviewItem(
                                title: "Sleep",
                                value: "\(selectedSleepType.durationRange.min)-\(selectedSleepType.durationRange.max)h",
                                icon: "moon.fill",
                                color: .blue
                            )
                            
                            PreviewItem(
                                title: "Steps",
                                value: "\(selectedActivityLevel.stepRange.min)-\(selectedActivityLevel.stepRange.max)",
                                icon: "figure.walk",
                                color: .green
                            )
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Create User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createUser()
                    }
                    .disabled(isCreating)
                }
            }
        }
    }
    
    private func createUser() {
        isCreating = true
        
        let newUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: selectedSleepType,
            activityLevel: selectedActivityLevel
        )
        
        onCreate(newUser)
        dismiss()
    }
    
    private func getSleepDescription(for type: SleepType) -> String {
        switch type {
        case .nightOwl:
            return "Late sleeper, typically 2-3 AM to 10-11 AM"
        case .earlyBird:
            return "Early sleeper, typically 10 PM to 6 AM"
        case .irregular:
            return "Inconsistent sleep schedule with high variation"
        case .normal:
            return "Regular schedule, 11 PM to 7-8 AM"
        }
    }
    
    private func getActivityDescription(for level: ActivityLevel) -> String {
        switch level {
        case .low:
            return "Sedentary lifestyle, minimal physical activity"
        case .medium:
            return "Moderate activity, regular daily movement"
        case .high:
            return "Active lifestyle, regular exercise"
        case .veryHigh:
            return "Very active, intense daily workouts"
        }
    }
}

// MARK: - 预览项组件
struct PreviewItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}