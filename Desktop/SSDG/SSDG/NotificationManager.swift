//
//  NotificationManager.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation
import UserNotifications

// MARK: - 通知管理器
@MainActor
class NotificationManager: ObservableObject {
    
    // 单例实例
    static let shared = NotificationManager()
    
    // 状态
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        checkNotificationPermissions()
    }
    
    // MARK: - 权限管理
    
    func requestNotificationPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
                authorizationStatus = granted ? .authorized : .denied
            }
            
            if granted {
                print("📱 通知权限已授权")
            } else {
                print("❌ 通知权限被拒绝")
            }
            
            return granted
        } catch {
            print("❌ 请求通知权限失败: \(error)")
            return false
        }
    }
    
    // 别名方法，保持向后兼容
    func requestNotificationAuthorization() async -> Bool {
        return await requestNotificationPermissions()
    }
    
    private func checkNotificationPermissions() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - 发送通知
    
    func sendNotification(title: String, body: String, identifier: String) async {
        guard isAuthorized else {
            print("⚠️ 通知权限未授权，无法发送通知")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // 立即发送通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 通知已发送: \(title)")
        } catch {
            print("❌ 发送通知失败: \(error)")
        }
    }
    
    func sendDelayedNotification(title: String, body: String, identifier: String, delay: TimeInterval) async {
        guard isAuthorized else {
            print("⚠️ 通知权限未授权，无法发送通知")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 延迟通知已安排: \(title) (延迟 \(delay)秒)")
        } catch {
            print("❌ 安排延迟通知失败: \(error)")
        }
    }
    
    func sendScheduledNotification(title: String, body: String, identifier: String, at date: Date) async {
        guard isAuthorized else {
            print("⚠️ 通知权限未授权，无法发送通知")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 定时通知已安排: \(title) (时间: \(date))")
        } catch {
            print("❌ 安排定时通知失败: \(error)")
        }
    }
    
    // MARK: - 通知管理
    
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🚫 已取消通知: \(identifier)")
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🚫 已取消所有待发送通知")
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    func getPendingNotificationsCount() async -> Int {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.count
    }
    
    // MARK: - 测试通知
    
    func sendTestNotification() async {
        guard isAuthorized else {
            print("⚠️ 通知权限未授权，无法发送测试通知")
            return
        }
        
        let title = "🧪 测试通知"
        let body = "这是一个测试通知，用于验证通知系统是否正常工作"
        await sendNotification(title: title, body: body, identifier: "test_notification")
    }
    
    // MARK: - 常用通知模板
    
    func sendDataSyncNotification(sleepHours: Double, steps: Int) async {
        let title = "✅ 数据同步完成"
        let body = "睡眠: \(String(format: "%.1f", sleepHours))小时，步数: \(steps)步已同步到健康应用"
        await sendNotification(title: title, body: body, identifier: "data_sync_complete")
    }
    
    func sendAutomationStatusNotification(status: String) async {
        let title = "🤖 自动化状态更新"
        let body = "个性化自动化系统状态: \(status)"
        await sendNotification(title: title, body: body, identifier: "automation_status")
    }
    
    func sendErrorNotification(error: String) async {
        let title = "⚠️ 系统错误"
        let body = "发生错误: \(error)"
        await sendNotification(title: title, body: body, identifier: "system_error")
    }
    
    func sendMaintenanceNotification(message: String) async {
        let title = "🔧 系统维护"
        let body = message
        await sendNotification(title: title, body: body, identifier: "system_maintenance")
    }
    
    // MARK: - AutomationManager需要的方法
    
    func sendConfigChangeNotification(level: String) async {
        let title = "⚙️ 自动化配置已更新"
        let body = "自动同步模式已更改为: \(level)"
        await sendNotification(title: title, body: body, identifier: "config_change")
    }
    
    func sendDailySyncStartNotification() async {
        let title = "🌅 每日健康数据同步"
        let body = "正在自动生成和同步今日的健康数据..."
        await sendNotification(title: title, body: body, identifier: "daily_sync_start")
    }
    
    func sendDailySyncSuccessNotification() async {
        let title = "✅ 每日同步完成"
        let body = "今日的睡眠和步数数据已成功同步到苹果健康"
        await sendNotification(title: title, body: body, identifier: "daily_sync_success")
    }
    
    func sendSemiAutoSyncNotification() async {
        let title = "🔄 数据已准备就绪"
        let body = "今日健康数据已生成完成，点击确认同步到苹果健康"
        await sendNotification(title: title, body: body, identifier: "semi_auto_reminder")
    }
    
    func sendDailySyncFailureNotification(error: Error) async {
        let title = "❌ 每日同步失败"
        let body = "自动同步出现问题: \(error.localizedDescription)"
        await sendNotification(title: title, body: body, identifier: "daily_sync_failure")
    }
}

// MARK: - 通知标识符常量
extension NotificationManager {
    struct Identifiers {
        static let dataSyncComplete = "data_sync_complete"
        static let dailySyncComplete = "daily_sync_complete"
        static let sleepDataGenerated = "sleep_data_generated"
        static let automationStatus = "automation_status"
        static let systemError = "system_error"
        static let systemMaintenance = "system_maintenance"
        static let backgroundTaskComplete = "background_task_complete"
        static let healthKitSync = "healthkit_sync"
    }
}

 