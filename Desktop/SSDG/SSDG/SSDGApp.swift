//
//  SSDGApp.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import SwiftUI
import UIKit
import BackgroundTasks

@main
struct SSDGApp: App {
    
    // 初始化自动化管理器
    @StateObject private var automationManager = AutomationManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 应用启动时的初始化
                    initializeApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // 应用变为活跃时检查自动化状态
                    handleAppDidBecomeActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // 应用即将失去焦点时保存状态
                    handleAppWillResignActive()
                }
        }
    }
    
        // MARK: - 应用初始化
    private func initializeApp() {
        print("🚀 HealthKit Started")

        // 加载个性化配置
        VirtualUser.loadPersonalizedProfiles()
        print("📋 Personalized profiles loaded")

        // 请求通知权限
        Task {
            _ = await notificationManager.requestNotificationAuthorization()
        }

        // 检查自动化状态
        if automationManager.config.autoSyncLevel != .manual {
            print("🔄 Automation configuration detected, starting automation...")
        }
    }
    
    // MARK: - 应用状态处理
    private func handleAppDidBecomeActive() {
        print("📱 App became active")
        
        // 检查是否有通知导航需求
        if let target = UserDefaults.standard.string(forKey: "notification_navigation_target") {
            print("📍 Navigation target detected: \(target)")
            UserDefaults.standard.removeObject(forKey: "notification_navigation_target")
            // 这里可以实现具体的导航逻辑
        }
        
        // 检查自动化状态
        Task {
            // 简化版本，移除不存在的方法调用
            print("🔄 App active, automation manager ready")
        }
    }
    
    private func handleAppWillResignActive() {
        print("📱 App will resign active")
        // 保存当前状态
        VirtualUser.savePersonalizedProfiles()
        // AutomationManager和其他管理器会自动保存状态
    }
}
