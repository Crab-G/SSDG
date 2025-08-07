//
//  NotificationSettingsView.swift
//  SSDG
//
//  Created by Assistant on 2025/8/6.
//

import SwiftUI
import UserNotifications

// MARK: - 通知设置视图
struct NotificationSettingsView: View {
    @State private var notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    @State private var morningNotificationTime = Date()
    @State private var eveningNotificationTime = Date()
    @State private var reminderNotifications = UserDefaults.standard.bool(forKey: "reminderNotifications")
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
            }
            
            if notificationsEnabled {
                Section {
                    DatePicker("Morning Reminder",
                              selection: Binding(
                                get: { morningNotificationTime },
                                set: { newValue in
                                    morningNotificationTime = newValue
                                    saveTimeSettings()
                                }
                              ),
                              displayedComponents: .hourAndMinute)
                    
                    DatePicker("Evening Reminder",
                              selection: Binding(
                                get: { eveningNotificationTime },
                                set: { newValue in
                                    eveningNotificationTime = newValue
                                    saveTimeSettings()
                                }
                              ),
                              displayedComponents: .hourAndMinute)
                } header: {
                    Text("Daily Reminders")
                } footer: {
                    Text("Get reminded to check your health data")
                }
                
                Section {
                    Toggle("Data Generation Notifications", isOn: $reminderNotifications)
                } header: {
                    Text("Automation Notifications")
                } footer: {
                    Text("Notify when automatic data generation completes")
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
        .onChange(of: notificationsEnabled) { newValue in
            UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
            if newValue {
                requestNotificationPermission()
            }
        }
        .onChange(of: reminderNotifications) { newValue in
            UserDefaults.standard.set(newValue, forKey: "reminderNotifications")
        }
    }
    
    private func loadSettings() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        reminderNotifications = UserDefaults.standard.bool(forKey: "reminderNotifications")
        
        // 加载时间设置
        if let morningData = UserDefaults.standard.data(forKey: "morningNotificationTime"),
           let morningTime = try? JSONDecoder().decode(Date.self, from: morningData) {
            morningNotificationTime = morningTime
        } else {
            // 默认早上8点
            let calendar = Calendar.current
            morningNotificationTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        }
        
        if let eveningData = UserDefaults.standard.data(forKey: "eveningNotificationTime"),
           let eveningTime = try? JSONDecoder().decode(Date.self, from: eveningData) {
            eveningNotificationTime = eveningTime
        } else {
            // 默认晚上8点
            let calendar = Calendar.current
            eveningNotificationTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        }
    }
    
    private func saveTimeSettings() {
        if let morningData = try? JSONEncoder().encode(morningNotificationTime) {
            UserDefaults.standard.set(morningData, forKey: "morningNotificationTime")
        }
        
        if let eveningData = try? JSONEncoder().encode(eveningNotificationTime) {
            UserDefaults.standard.set(eveningData, forKey: "eveningNotificationTime")
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self.notificationsEnabled = false
                    UserDefaults.standard.set(false, forKey: "notificationsEnabled")
                }
            }
        }
    }
}