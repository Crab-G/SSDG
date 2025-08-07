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
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
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
        // 安全的初始化，防止SIGTERM错误
        print("🚀 开始应用初始化...")
        
        // 1. 安全加载个性化配置
        VirtualUser.loadPersonalizedProfiles()
        print("✅ 个性化配置加载完成")

        // 2. 延迟且安全地执行权限请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            Task { @MainActor in
                _ = await self.notificationManager.requestNotificationAuthorization()
                print("✅ 通知权限请求完成")
            }
        }

        // 3. 更长延迟执行HealthKit权限请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            Task { @MainActor in
                await self.requestHealthKitAuthorizationOnFirstLaunch()
                print("✅ HealthKit权限检查完成")
            }
        }
        
        print("✅ 应用初始化调度完成")
    }
    
    // MARK: - HealthKit权限请求
    private func requestHealthKitAuthorizationOnFirstLaunch() async {
        // 检查是否是首次启动或权限未授权
        let hasRequestedBefore = UserDefaults.standard.bool(forKey: "hasRequestedHealthKitPermission")
        
        if !hasRequestedBefore || !healthKitManager.isAuthorized {
            print("🏥 请求HealthKit权限...")
            
            let success = await healthKitManager.requestHealthKitAuthorization()
            
            if success {
                print("✅ HealthKit权限授权成功")
                UserDefaults.standard.set(true, forKey: "hasRequestedHealthKitPermission")
            } else {
                print("❌ HealthKit权限授权失败")
                // 可以考虑显示引导用户手动授权的提示
            }
        } else {
            print("📋 HealthKit权限已授权，跳过权限请求")
        }
    }
    
    // MARK: - 应用状态处理
    private func handleAppDidBecomeActive() {
        print("📱 App became active")
        
        // 安全检查通知导航需求
        if let target = UserDefaults.standard.string(forKey: "notification_navigation_target") {
            print("📍 Navigation target detected: \(target)")
            UserDefaults.standard.removeObject(forKey: "notification_navigation_target")
        }
        
        // 安全执行自动化状态检查
        Task { @MainActor in
            print("🔄 App active, checking automation status...")
            
            // 安全检查HealthKit权限状态
            await healthKitManager.checkAuthorizationStatus()
            
            print("✅ App activation tasks completed")
        }
    }
    
    private func handleAppWillResignActive() {
        print("📱 App will resign active")
        
        // 安全保存当前状态
        VirtualUser.savePersonalizedProfiles()
        print("✅ 个性化配置保存完成")
        
        // 清理资源，防止内存泄漏
        print("🧹 清理应用资源...")
    }
}
