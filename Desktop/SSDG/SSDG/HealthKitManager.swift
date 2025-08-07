//
//  HealthKitManager.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation
import HealthKit

// MARK: - String Extension for Hex Generation
extension String {
    static func randomHexString(length: Int) -> String {
        let hexChars = "0123456789ABCDEF"
        var result = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<hexChars.count)
            let char = hexChars[hexChars.index(hexChars.startIndex, offsetBy: randomIndex)]
            result.append(char)
        }
        return result
    }
}
import SwiftUI

// MARK: - HealthKit管理器
@MainActor
class HealthKitManager: ObservableObject {
    
    // 单例实例
    static let shared = HealthKitManager()
    
    // HealthKit Store
    private let healthStore = HKHealthStore()
    
    // 发布的状态
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var lastError: Error?
    
    // 新增：分别跟踪读写权限状态
    @Published var sleepReadAuthorized = false
    @Published var sleepWriteAuthorized = false
    @Published var stepsReadAuthorized = false
    @Published var stepsWriteAuthorized = false
    
    // 处理状态
    @Published var isProcessing = false
    
    @Published var importProgress: Double = 0.0
    @Published var importStatusMessage: String = ""
    
    private init() {
        // 初始化时检查权限状态
        Task {
            await checkAuthorizationStatus()
        }
        print("✅ HealthKitManager 初始化完成")
    }
    
    // MARK: - HealthKit可用性检查
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit不可用")
            return
        }
        print("✅ HealthKit可用")
    }
    
    // MARK: - 权限管理
    func requestHealthKitAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ 此设备不支持HealthKit")
            return false
        }
        
        // 安全获取数据类型
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("❌ 无法获取HealthKit数据类型")
            return false
        }
        
        let writeTypes: Set<HKSampleType> = [sleepType, stepsType]
        let readTypes: Set<HKObjectType> = [sleepType, stepsType]
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            await checkAuthorizationStatus()
            
            if isAuthorized {
                print("✅ HealthKit权限请求成功 - 所有必要权限已获得")
            } else {
                print("⚠️ HealthKit权限请求完成，但部分权限未授权")
                print("   睡眠写权限: \(sleepWriteAuthorized)")
                print("   步数写权限: \(stepsWriteAuthorized)")
                print("   睡眠读权限: \(sleepReadAuthorized)")
                print("   步数读权限: \(stepsReadAuthorized)")
            }
            
            return isAuthorized
        } catch {
            print("❌ HealthKit权限请求失败: \(error.localizedDescription)")
            await MainActor.run {
                lastError = error
            }
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        // 安全获取数据类型，避免强制解包
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("❌ 无法获取HealthKit数据类型")
            await MainActor.run {
                isAuthorized = false
            }
            return
        }
        
        // 检查写权限
        let sleepWriteStatus = healthStore.authorizationStatus(for: sleepType)
        let stepsWriteStatus = healthStore.authorizationStatus(for: stepsType)
        
        // 在主线程上更新所有@Published属性
        await MainActor.run {
            // 更新各项权限状态
            sleepWriteAuthorized = sleepWriteStatus == .sharingAuthorized
            stepsWriteAuthorized = stepsWriteStatus == .sharingAuthorized
            
            // 读权限检查（HealthKit的读权限状态获取方式不同）
            sleepReadAuthorized = sleepWriteStatus != .sharingDenied
            stepsReadAuthorized = stepsWriteStatus != .sharingDenied
            
            // 综合权限状态：需要所有必要权限都已授权
            isAuthorized = sleepWriteAuthorized && stepsWriteAuthorized && sleepReadAuthorized && stepsReadAuthorized
            authorizationStatus = sleepWriteStatus
        }
        
        print("🔍 权限状态检查完成")
        print("   睡眠数据 - 写权限: \(sleepWriteStatus.description), 读权限: \(sleepReadAuthorized ? "已授权" : "未授权")")
        print("   步数数据 - 写权限: \(stepsWriteStatus.description), 读权限: \(stepsReadAuthorized ? "已授权" : "未授权")")
        print("   综合权限状态: \(isAuthorized ? "✅ 已授权" : "❌ 未完全授权")")
    }
    
    // MARK: - 写入睡眠数据
    func writeSleepData(_ sleepData: [SleepData], mode: DataMode = .simple, user: VirtualUser? = nil) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权")
            return false
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        do {
            var samples: [HKCategorySample] = []
            let calendar = Calendar.current
            
            // 🔥 修复：去重处理，确保每个日期只有一份睡眠数据
            var uniqueSleepData: [SleepData] = []
            var seenDates = Set<Date>()
            
            for sleep in sleepData {
                let startOfDay = calendar.startOfDay(for: sleep.date)
                if !seenDates.contains(startOfDay) {
                    seenDates.insert(startOfDay)
                    uniqueSleepData.append(sleep)
                } else {
                    print("⚠️ 跳过重复日期的睡眠数据: \(startOfDay)")
                }
            }
            
            for sleep in uniqueSleepData {
                // 创建睡眠样本
                let sleepSamples = createSleepSamples(from: sleep, mode: mode, user: user)
                samples.append(contentsOf: sleepSamples)
            }
            
            // 检查样本是否为空
            guard !samples.isEmpty else {
                print("⚠️ 跳过写入空的睡眠数据样本")
                await MainActor.run {
                    isProcessing = false
                }
                return true // 空数据不算错误
            }
            
            try await healthStore.save(samples)
            
            await MainActor.run {
                isProcessing = false
            }
            
            print("✅ 成功写入 \(samples.count) 个睡眠数据样本")
            return true
            
        } catch {
            print("❌ 写入睡眠数据失败: \(error.localizedDescription)")
            await MainActor.run {
                lastError = error
                isProcessing = false
            }
            return false
        }
    }
    
    // MARK: - 写入步数数据
    func writeStepsData(_ stepsData: [StepsData], user: VirtualUser? = nil) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权")
            return false
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        do {
            var samples: [HKQuantitySample] = []
            
            for steps in stepsData {
                // 创建步数样本
                let stepsSamples = createStepsSamples(from: steps, user: user)
                samples.append(contentsOf: stepsSamples)
            }
            
            // 检查样本是否为空
            guard !samples.isEmpty else {
                print("⚠️ 跳过写入空的步数数据样本")
                await MainActor.run {
                    isProcessing = false
                }
                return true // 空数据不算错误
            }
            
            try await healthStore.save(samples)
            
            await MainActor.run {
                isProcessing = false
            }
            
            print("✅ 成功写入 \(samples.count) 个步数数据样本")
            return true
            
        } catch {
            print("❌ 写入步数数据失败: \(error.localizedDescription)")
            await MainActor.run {
                lastError = error
                isProcessing = false
            }
            return false
        }
    }
    
    // MARK: - 智能数据替换机制
    func replaceOrWriteData(user: VirtualUser, sleepData: [SleepData], stepsData: [StepsData], mode: DataMode = .simple) async -> (success: Bool, needsManualCleanup: Bool) {
        if !isAuthorized {
            let success = await requestHealthKitAuthorization()
            if !success {
                return (false, false)
            }
        }
        
        print("🔄 开始智能数据替换...")
        
        // 重置进度
        await MainActor.run {
            importProgress = 0.0
            importStatusMessage = "准备替换数据..."
        }
        
        // 1. 分析时间范围
        let dateRange = getDateRange(from: sleepData, stepsData: stepsData)
        let startDate = dateRange.start
        let endDate = dateRange.end
        
        print("   时间范围: \(DateFormatter.localizedString(from: startDate, dateStyle: .short, timeStyle: .none)) - \(DateFormatter.localizedString(from: endDate, dateStyle: .short, timeStyle: .none))")
        
        // 2. 检查已存在的数据
        await MainActor.run {
            importProgress = 0.1
            importStatusMessage = "检查已存在的数据..."
        }
        
        let existingData = await checkExistingData(startDate: startDate, endDate: endDate)
        
        // 3. 尝试智能删除
        await MainActor.run {
            importProgress = 0.2
            importStatusMessage = "尝试清理旧数据..."
        }
        
        let deleteResult = await smartDeleteData(startDate: startDate, endDate: endDate, existingData: existingData)
        
        // 4. 写入新数据
        await MainActor.run {
            importProgress = 0.5
            importStatusMessage = "写入新数据..."
        }
        
        let sleepSuccess = await writeSleepData(sleepData, mode: mode, user: user)
        let stepsSuccess = await writeStepsData(stepsData, user: user)
        
        let overallSuccess = sleepSuccess && stepsSuccess
        
        // 5. 完成
        await MainActor.run {
            importProgress = 1.0
            importStatusMessage = overallSuccess ? "替换完成！" : "替换失败"
        }
        
        if overallSuccess {
            print("✅ 数据替换成功")
            if deleteResult.partialSuccess {
                print("⚠️ 部分旧数据可能未完全清理")
            }
        } else {
            print("❌ 数据替换失败")
        }
        
        return (overallSuccess, deleteResult.needsManualCleanup)
    }
    
    // MARK: - 检查已存在的数据
    private func checkExistingData(startDate: Date, endDate: Date) async -> (sleepSamples: [HKCategorySample], stepsSamples: [HKQuantitySample]) {
        
        async let sleepSamples = checkExistingSleepData(startDate: startDate, endDate: endDate)
        async let stepsSamples = checkExistingStepsData(startDate: startDate, endDate: endDate)
        
        return await (sleepSamples, stepsSamples)
    }
    
    // 检查已存在的睡眠数据
    private func checkExistingSleepData(startDate: Date, endDate: Date) async -> [HKCategorySample] {
        return await withCheckedContinuation { continuation in
            guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                continuation.resume(returning: [])
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    print("❌ 查询睡眠数据失败: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else {
                    let sleepSamples = samples as? [HKCategorySample] ?? []
                    print("📊 发现已存在睡眠数据: \(sleepSamples.count) 条")
                    continuation.resume(returning: sleepSamples)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // 检查已存在的步数数据
    private func checkExistingStepsData(startDate: Date, endDate: Date) async -> [HKQuantitySample] {
        return await withCheckedContinuation { continuation in
            guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
                continuation.resume(returning: [])
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            
            let query = HKSampleQuery(
                sampleType: stepsType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    print("❌ 查询步数数据失败: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else {
                    let stepsSamples = samples as? [HKQuantitySample] ?? []
                    print("📊 发现已存在步数数据: \(stepsSamples.count) 条")
                    continuation.resume(returning: stepsSamples)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - 智能删除数据
    private func smartDeleteData(startDate: Date, endDate: Date, existingData: (sleepSamples: [HKCategorySample], stepsSamples: [HKQuantitySample])) async -> (success: Bool, partialSuccess: Bool, needsManualCleanup: Bool) {
        var sleepDeleteSuccess = true
        var stepsDeleteSuccess = true
        var partialSuccess = false
        
        // 1. 尝试删除睡眠数据
        if !existingData.sleepSamples.isEmpty {
            print("   发现 \(existingData.sleepSamples.count) 个已存在的睡眠样本")
            
            // 优先删除应用自己生成的数据
            let appGeneratedSleep = existingData.sleepSamples.filter { sample in
                if let deviceName = sample.metadata?[HKMetadataKeyDeviceName] as? String {
                    return deviceName == "iPhone" || deviceName.contains("Health")
                }
                return false
            }
            
            if !appGeneratedSleep.isEmpty {
                print("     其中 \(appGeneratedSleep.count) 个可能是应用生成的")
                do {
                    try await healthStore.delete(appGeneratedSleep)
                    print("     ✅ 成功删除应用生成的睡眠数据")
                } catch {
                    print("     ❌ 删除应用生成的睡眠数据失败: \(error.localizedDescription)")
                    sleepDeleteSuccess = false
                }
            }
            
            // 尝试删除时间范围内的所有数据
            if sleepDeleteSuccess {
                do {
                    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
                    let sleepPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
                    try await healthStore.deleteObjects(of: sleepType, predicate: sleepPredicate)
                    print("     ✅ 成功删除所有睡眠数据")
                } catch {
                    print("     ⚠️ 删除所有睡眠数据失败: \(error.localizedDescription)")
                    partialSuccess = true
                }
            }
        }
        
        // 2. 尝试删除步数数据
        if !existingData.stepsSamples.isEmpty {
            print("   发现 \(existingData.stepsSamples.count) 个已存在的步数样本")
            
            // 优先删除应用自己生成的数据
            let appGeneratedSteps = existingData.stepsSamples.filter { sample in
                if let deviceName = sample.metadata?[HKMetadataKeyDeviceName] as? String {
                    return deviceName == "iPhone" || deviceName.contains("Health")
                }
                return false
            }
            
            if !appGeneratedSteps.isEmpty {
                print("     其中 \(appGeneratedSteps.count) 个可能是应用生成的")
                do {
                    try await healthStore.delete(appGeneratedSteps)
                    print("     ✅ 成功删除应用生成的步数数据")
                } catch {
                    print("     ❌ 删除应用生成的步数数据失败: \(error.localizedDescription)")
                    stepsDeleteSuccess = false
                }
            }
            
            // 尝试删除时间范围内的所有数据
            if stepsDeleteSuccess {
                do {
                    let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
                    let stepsPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
                    try await healthStore.deleteObjects(of: stepsType, predicate: stepsPredicate)
                    print("     ✅ 成功删除所有步数数据")
                } catch {
                    print("     ⚠️ 删除所有步数数据失败: \(error.localizedDescription)")
                    partialSuccess = true
                }
            }
        }
        
        let overallSuccess = sleepDeleteSuccess && stepsDeleteSuccess
        let needsManualCleanup = !overallSuccess || partialSuccess
        
        return (overallSuccess, partialSuccess, needsManualCleanup)
    }
    
    // MARK: - 获取日期范围
    private func getDateRange(from sleepData: [SleepData], stepsData: [StepsData]) -> (start: Date, end: Date) {
        var startDate = Date()
        var endDate = Date(timeIntervalSince1970: 0)
        
        // 检查睡眠数据
        for sleep in sleepData {
            if sleep.date < startDate {
                startDate = sleep.date
            }
            if sleep.date > endDate {
                endDate = sleep.date
            }
        }
        
        // 检查步数数据
        for steps in stepsData {
            if steps.date < startDate {
                startDate = steps.date
            }
            if steps.date > endDate {
                endDate = steps.date
            }
        }
        
        // 扩展到全天范围
        let calendar = Calendar.current
        startDate = calendar.startOfDay(for: startDate)
        endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        
        return (startDate, endDate)
    }
    
    // MARK: - 创建iPhone设备对象
    private func createiPhoneDevice(user: VirtualUser? = nil) -> HKDevice {
        // 如果提供了用户，使用用户的设备信息
        if let user = user {
            let modelInfo = getModelInfo(for: user.deviceModel)
            let systemVersion = getRealisticiOSVersion()
            
            return HKDevice(
                name: user.deviceModel,                              // 用户的设备型号
                manufacturer: "Apple Inc.",
                model: modelInfo.modelIdentifier,                    // 对应的型号标识符
                hardwareVersion: modelInfo.hardwareVersion,         // 硬件版本
                firmwareVersion: systemVersion,                      // 系统版本
                softwareVersion: systemVersion,                      // 软件版本
                localIdentifier: user.deviceUUID,                    // 用户的设备UUID
                udiDeviceIdentifier: nil
            )
        } else {
            // 使用默认的随机设备信息
            let deviceModel = getRealisticiPhoneModel()
            let systemVersion = getRealisticiOSVersion()
            
            return HKDevice(
                name: deviceModel.displayName,                      // 真实iPhone型号名称
                manufacturer: "Apple Inc.",
                model: deviceModel.modelIdentifier,                 // 真实型号标识符
                hardwareVersion: deviceModel.hardwareVersion,       // 硬件版本
                firmwareVersion: systemVersion,                      // 系统版本
                softwareVersion: systemVersion,                      // 软件版本
                localIdentifier: generateRealisticDeviceID(),       // 真实风格设备ID
                udiDeviceIdentifier: nil
            )
        }
    }
    
    // MARK: - 根据设备名称获取型号信息
    private func getModelInfo(for deviceName: String) -> (modelIdentifier: String, hardwareVersion: String) {
        // 映射用户友好的设备名称到技术标识符
        let modelMappings: [String: (modelIdentifier: String, hardwareVersion: String)] = [
            "iPhone 15 Pro Max": (modelIdentifier: "iPhone16,2", hardwareVersion: "iPhone16,2"),
            "iPhone 15 Pro": (modelIdentifier: "iPhone16,1", hardwareVersion: "iPhone16,1"),
            "iPhone 15 Plus": (modelIdentifier: "iPhone15,5", hardwareVersion: "iPhone15,5"),
            "iPhone 15": (modelIdentifier: "iPhone15,4", hardwareVersion: "iPhone15,4"),
            "iPhone 14 Pro Max": (modelIdentifier: "iPhone15,3", hardwareVersion: "iPhone15,3"),
            "iPhone 14 Pro": (modelIdentifier: "iPhone15,2", hardwareVersion: "iPhone15,2"),
            "iPhone 14 Plus": (modelIdentifier: "iPhone14,8", hardwareVersion: "iPhone14,8"),
            "iPhone 14": (modelIdentifier: "iPhone14,7", hardwareVersion: "iPhone14,7"),
            "iPhone 13 Pro Max": (modelIdentifier: "iPhone14,3", hardwareVersion: "iPhone14,3"),
            "iPhone 13 Pro": (modelIdentifier: "iPhone14,2", hardwareVersion: "iPhone14,2"),
            "iPhone 13": (modelIdentifier: "iPhone14,5", hardwareVersion: "iPhone14,5"),
            "iPhone 13 mini": (modelIdentifier: "iPhone14,4", hardwareVersion: "iPhone14,4"),
            "iPhone SE (3rd generation)": (modelIdentifier: "iPhone14,6", hardwareVersion: "iPhone14,6")
        ]
        
        // 如果找到映射，返回对应的信息；否则返回默认值
        return modelMappings[deviceName] ?? (modelIdentifier: "iPhone14,7", hardwareVersion: "iPhone14,7")
    }
    
    // MARK: - 获取真实iPhone型号信息
    private func getRealisticiPhoneModel() -> (displayName: String, modelIdentifier: String, hardwareVersion: String) {
        let currentYear = Calendar.current.component(.year, from: Date())
        
        // 根据当前年份选择合适的iPhone型号
        let models = [
            (displayName: "iPhone 15 Pro", modelIdentifier: "iPhone16,1", hardwareVersion: "iPhone16,1"),
            (displayName: "iPhone 15", modelIdentifier: "iPhone15,4", hardwareVersion: "iPhone15,4"),
            (displayName: "iPhone 14 Pro", modelIdentifier: "iPhone15,2", hardwareVersion: "iPhone15,2"),
            (displayName: "iPhone 14", modelIdentifier: "iPhone14,7", hardwareVersion: "iPhone14,7"),
            (displayName: "iPhone 13 Pro", modelIdentifier: "iPhone14,2", hardwareVersion: "iPhone14,2"),
            (displayName: "iPhone 13", modelIdentifier: "iPhone14,5", hardwareVersion: "iPhone14,5")
        ]
        
        // 根据年份和随机性选择型号
        let modelIndex = (currentYear + Int.random(in: 0...2)) % models.count
        return models[modelIndex]
    }
    
    // MARK: - 获取真实iOS版本
    private func getRealisticiOSVersion() -> String {
        let currentVersion = UIDevice.current.systemVersion
        
        // 在当前版本基础上微调，模拟真实情况
        let majorVersions = ["17.5.1", "17.4.1", "17.3.1", "16.7.1", "16.6.1"]
        
        // 80%几率使用当前版本，20%使用其他常见版本
        if Int.random(in: 1...100) <= 80 {
            return currentVersion
        } else {
            return majorVersions.randomElement() ?? currentVersion
        }
    }
    
    // MARK: - 生成真实风格的设备ID
    private func generateRealisticDeviceID() -> String {
        // 生成类似真实设备的UUID格式
        let segments = [
            String.randomHexString(length: 8),
            String.randomHexString(length: 4),
            "4" + String.randomHexString(length: 3), // UUID v4格式
            String.randomHexString(length: 4),
            String.randomHexString(length: 12)
        ]
        return segments.joined(separator: "-").uppercased()
    }
    
    // MARK: - 生成iPhone原生数据元数据
    private func createiPhoneMetadata(extraData: [String: Any] = [:], user: VirtualUser? = nil) -> [String: Any] {
        var metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: false,                    // 标记为自动记录
            HKMetadataKeyDeviceName: "iPhone",                     // 设备名称（关键）
            HKMetadataKeyDeviceManufacturerName: "Apple Inc.",     // 制造商
            HKMetadataKeyDeviceSerialNumber: user?.deviceSerialNumber ?? generateRealisticSerialNumber(), // 使用用户的序列号
            HKMetadataKeyExternalUUID: user?.deviceUUID ?? UUID().uuidString, // 使用用户的UUID
            // 模拟Apple Health应用的标识（使用有效的自定义键名）
            "AppleDeviceSource": NSNumber(value: true),                   // Apple设备标识
            "DeviceCalibrated": NSNumber(value: true),                    // 设备已校准
        ]
        
        // 合并额外的元数据（移除明显生成标识）
        for (key, value) in extraData {
            // 跳过明显的生成标识
            if !["AppGenerated", "DataVersion", "Generated", "Synthetic"].contains(key) {
                metadata[key] = value
            }
        }
        
        return metadata
    }
    
    // MARK: - 生成真实风格的设备序列号
    private func generateRealisticSerialNumber() -> String {
        // 模拟真实iPhone序列号格式：F2LXXXXX
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        let alphanumeric = letters + numbers
        
        var serialNumber = "F2L" // iPhone常见前缀
        
        // 添加5位随机字符
        for _ in 0..<5 {
            let randomIndex = Int.random(in: 0..<alphanumeric.count)
            let character = alphanumeric[alphanumeric.index(alphanumeric.startIndex, offsetBy: randomIndex)]
            serialNumber.append(character)
        }
        
        return serialNumber
    }
    
    // MARK: - 改进的创建睡眠样本（完全模拟iPhone数据）
    private func createSleepSamples(from sleepData: SleepData, mode: DataMode = .simple, user: VirtualUser? = nil) -> [HKCategorySample] {
        var samples: [HKCategorySample] = []
        
        // 使用统一的iPhone元数据和设备对象
        let metadata = createiPhoneMetadata(user: user)
        let device = createiPhoneDevice(user: user)
        
        switch mode {
        case .simple:
            // 🔥 新方案：只创建卧床时间样本，不创建清醒样本
            // 这样更贴合真实iPhone的记录（只显示卧床时间段）
            for stage in sleepData.sleepStages {
                // 只处理睡眠段，忽略清醒段
                if stage.stage != .awake {
                    let inBedSample = HKCategorySample(
                        type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                        value: HKCategoryValueSleepAnalysis.inBed.rawValue,
                        start: stage.startTime,
                        end: stage.endTime,
                        device: device,
                        metadata: metadata
                    )
                    samples.append(inBedSample)
                }
            }
            
        case .wearableDevice:
            // 可穿戴设备模式：生成详细的睡眠阶段样本（版本兼容）
            for stage in sleepData.sleepStages {
                let categoryValue: Int
                switch stage.stage {
                case .awake:
                    categoryValue = HKCategoryValueSleepAnalysis.awake.rawValue
                case .light:
                    if #available(iOS 16.0, *) {
                        categoryValue = HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    } else {
                        categoryValue = HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                case .deep:
                    if #available(iOS 16.0, *) {
                        categoryValue = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    } else {
                        categoryValue = HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                case .rem:
                    if #available(iOS 16.0, *) {
                        categoryValue = HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    } else {
                        categoryValue = HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }
                
                let stageSample = HKCategorySample(
                    type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                    value: categoryValue,
                    start: stage.startTime,
                    end: stage.endTime,
                    device: device,
                    metadata: metadata
                )
                samples.append(stageSample)
            }
        }
        
        return samples
    }
    
    // MARK: - 改进的创建步数样本（增强数据标识）
    private func createStepsSamples(from stepsData: StepsData, user: VirtualUser? = nil) -> [HKQuantitySample] {
        var samples: [HKQuantitySample] = []
        
        // 使用统一的iPhone元数据和设备对象
        let metadata = createiPhoneMetadata(user: user)
        let device = createiPhoneDevice(user: user)
        
        // 优先使用精细间隔数据（如果有的话）
        if !stepsData.stepsIntervals.isEmpty {
            for interval in stepsData.stepsIntervals {
                // 跳过0步数的间隔，减少数据噪音
                guard interval.steps > 0 else { continue }
                
                let stepsQuantity = HKQuantity(unit: HKUnit.count(), doubleValue: Double(interval.steps))
                let stepsSample = HKQuantitySample(
                    type: HKObjectType.quantityType(forIdentifier: .stepCount)!,
                    quantity: stepsQuantity,
                    start: interval.startTime,
                    end: interval.endTime,
                    device: device,
                    metadata: metadata
                )
                samples.append(stepsSample)
            }
        } else {
            // 回退到小时数据
            for hourlySteps in stepsData.hourlySteps {
                guard hourlySteps.steps > 0 else { continue }
                
                let stepsQuantity = HKQuantity(unit: HKUnit.count(), doubleValue: Double(hourlySteps.steps))
                let stepsSample = HKQuantitySample(
                    type: HKObjectType.quantityType(forIdentifier: .stepCount)!,
                    quantity: stepsQuantity,
                    start: hourlySteps.startTime,
                    end: hourlySteps.endTime,
                    device: device,
                    metadata: metadata
                )
                samples.append(stepsSample)
            }
        }
        
        return samples
    }
    
    // MARK: - 批量写入用户数据
    func syncUserData(user: VirtualUser, sleepData: [SleepData], stepsData: [StepsData], mode: DataMode = .simple) async -> Bool {
        if !isAuthorized {
            let success = await requestHealthKitAuthorization()
            if !success {
                return false
            }
        }
        
        print("🔄 开始同步用户数据到HealthKit...")
        print("   用户ID: \(user.id.prefix(8))")
        print("   睡眠数据: \(sleepData.count) 天")
        print("   步数数据: \(stepsData.count) 天")
        
        // 重置进度
        await MainActor.run {
            importProgress = 0.0
            importStatusMessage = "准备导入数据..."
        }
        
        // 同步睡眠数据
        await MainActor.run {
            importProgress = 0.1
            importStatusMessage = "导入睡眠数据..."
        }
        
        let sleepSuccess = await writeSleepData(sleepData, mode: mode, user: user)
        
        // 同步步数数据
        await MainActor.run {
            importProgress = 0.5
            importStatusMessage = "导入步数数据..."
        }
        
        let stepsSuccess = await writeStepsData(stepsData, user: user)
        
        let overallSuccess = sleepSuccess && stepsSuccess
        
        // 完成导入
        await MainActor.run {
            importProgress = 1.0
            importStatusMessage = overallSuccess ? "导入完成！" : "导入失败"
        }
        
        if overallSuccess {
            print("✅ 用户数据同步成功")
        } else {
            print("❌ 用户数据同步失败")
        }
        
        return overallSuccess
    }
    
    // MARK: - 测试删除权限
    func testDeletePermissions() async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权")
            return false
        }
        
        // 尝试删除一个很小的时间范围的数据来测试权限
        let testDate = Date().addingTimeInterval(-3600) // 1小时前
        let testEndDate = Date().addingTimeInterval(-3590) // 50分钟前
        
        do {
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let sleepPredicate = HKQuery.predicateForSamples(
                withStart: testDate,
                end: testEndDate,
                options: .strictStartDate
            )
            
            try await healthStore.deleteObjects(of: sleepType, predicate: sleepPredicate)
            print("✅ 删除权限测试成功")
            return true
            
        } catch {
            print("❌ 删除权限测试失败: \(error.localizedDescription)")
            await MainActor.run {
                lastError = error
            }
            return false
        }
    }
    
    // MARK: - 删除特定日期的数据（增强版）
    func deleteDayData(for date: Date) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权")
            return false
        }
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        // 扩展时间范围，包含前一天晚上和后一天早上，以确保跨天数据被正确删除
        let startOfRange = calendar.date(byAdding: .hour, value: -6, to: targetDay)! // 前一天18:00
        let endOfRange = calendar.date(byAdding: .hour, value: 30, to: targetDay)!   // 后一天06:00
        
        print("🗑️ 开始删除日期范围: \(DateFormatter.localizedString(from: startOfRange, dateStyle: .short, timeStyle: .short)) - \(DateFormatter.localizedString(from: endOfRange, dateStyle: .short, timeStyle: .short))")
        
        do {
            // 1. 先查询要删除的数据
            let sleepSamples = await querySleepSamples(start: startOfRange, end: endOfRange)
            let stepsSamples = await queryStepsSamples(start: startOfRange, end: endOfRange)
            
            print("   发现睡眠样本: \(sleepSamples.count) 个")
            print("   发现步数样本: \(stepsSamples.count) 个")
            
            // 2. 删除睡眠数据
            if !sleepSamples.isEmpty {
                // 先尝试删除应用生成的数据
                let appGeneratedSleep = sleepSamples.filter { sample in
                    if let metadata = sample.metadata,
                       let isAppGenerated = metadata["AppGenerated"] as? Bool {
                        return isAppGenerated
                    }
                    // 备用判断：设备名称包含iPhone或SSDG
                    if let deviceName = sample.metadata?[HKMetadataKeyDeviceName] as? String {
                        return deviceName.contains("iPhone") || deviceName.contains("Health")
                    }
                    return false
                }
                
                if !appGeneratedSleep.isEmpty {
                    try await healthStore.delete(appGeneratedSleep)
                    print("   ✅ 删除应用生成的睡眠数据: \(appGeneratedSleep.count) 个")
                }
                
                // 再尝试删除剩余的数据
                let remainingSleep = sleepSamples.filter { sample in
                    !appGeneratedSleep.contains(sample)
                }
                
                if !remainingSleep.isEmpty {
                    try await healthStore.delete(remainingSleep)
                    print("   ✅ 删除其他睡眠数据: \(remainingSleep.count) 个")
                }
                
                // 使用谓词删除确保完全清理
                let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
                let sleepPredicate = HKQuery.predicateForSamples(
                    withStart: startOfRange,
                    end: endOfRange,
                    options: []  // 不使用严格选项，包含所有重叠的样本
                )
                
                try await healthStore.deleteObjects(of: sleepType, predicate: sleepPredicate)
                print("   ✅ 谓词删除睡眠数据完成")
            }
            
            // 3. 删除步数数据
            if !stepsSamples.isEmpty {
                // 先尝试删除应用生成的数据
                let appGeneratedSteps = stepsSamples.filter { sample in
                    if let metadata = sample.metadata,
                       let isAppGenerated = metadata["AppGenerated"] as? Bool {
                        return isAppGenerated
                    }
                    // 备用判断：设备名称包含iPhone或SSDG
                    if let deviceName = sample.metadata?[HKMetadataKeyDeviceName] as? String {
                        return deviceName.contains("iPhone") || deviceName.contains("Health")
                    }
                    return false
                }
                
                if !appGeneratedSteps.isEmpty {
                    try await healthStore.delete(appGeneratedSteps)
                    print("   ✅ 删除应用生成的步数数据: \(appGeneratedSteps.count) 个")
                }
                
                // 再尝试删除剩余的数据
                let remainingSteps = stepsSamples.filter { sample in
                    !appGeneratedSteps.contains(sample)
                }
                
                if !remainingSteps.isEmpty {
                    try await healthStore.delete(remainingSteps)
                    print("   ✅ 删除其他步数数据: \(remainingSteps.count) 个")
                }
                
                // 使用谓词删除确保完全清理
                let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
                let stepsPredicate = HKQuery.predicateForSamples(
                    withStart: startOfRange,
                    end: endOfRange,
                    options: []  // 不使用严格选项，包含所有重叠的样本
                )
                
                try await healthStore.deleteObjects(of: stepsType, predicate: stepsPredicate)
                print("   ✅ 谓词删除步数数据完成")
            }
            
            print("✅ 删除\(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))的数据成功")
            return true
            
        } catch {
            print("❌ 删除\(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))的数据失败: \(error.localizedDescription)")
            await MainActor.run {
                lastError = error
            }
            return false
        }
    }
    
    // MARK: - 查询睡眠样本
    private func querySleepSamples(start: Date, end: Date) async -> [HKCategorySample] {
        return await withCheckedContinuation { continuation in
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    print("❌ 查询睡眠样本失败: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - 查询步数样本
    private func queryStepsSamples(start: Date, end: Date) async -> [HKQuantitySample] {
        return await withCheckedContinuation { continuation in
            let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            
            let query = HKSampleQuery(
                sampleType: stepsType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    print("❌ 查询步数样本失败: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - 强力清理重复数据
    func forceCleanDuplicateData(for date: Date) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权")
            return false
        }
        
        let calendar = Calendar.current
        guard let targetDay = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date)) else {
            print("❌ 无效的目标日期")
            return false
        }
        
        // 更大的时间范围，确保清理所有相关数据
        guard let startOfRange = calendar.date(byAdding: .day, value: -1, to: targetDay),
              let endOfRange = calendar.date(byAdding: .day, value: 2, to: targetDay) else {
            print("❌ 无法计算日期范围")
            return false
        }
        
        print("🔥 开始强力清理重复数据")
        print("   时间范围: \(DateFormatter.localizedString(from: startOfRange, dateStyle: .short, timeStyle: .short)) - \(DateFormatter.localizedString(from: endOfRange, dateStyle: .short, timeStyle: .short))")
        
        do {
            // 1. 查询所有相关数据
            let sleepSamples = await querySleepSamples(start: startOfRange, end: endOfRange)
            let stepsSamples = await queryStepsSamples(start: startOfRange, end: endOfRange)
            
            print("   发现睡眠样本: \(sleepSamples.count) 个")
            print("   发现步数样本: \(stepsSamples.count) 个")
            
            // 2. 分析和删除重复的睡眠数据
            if !sleepSamples.isEmpty {
                // 安全的按日期分组，添加错误处理
                var groupedSleep: [Date: [HKCategorySample]] = [:]
                for sample in sleepSamples {
                    // 添加安全检查，防止崩溃
                    guard sample.startDate.timeIntervalSince1970 > 0 else {
                        print("⚠️ 跳过无效的睡眠样本（无效日期）")
                        continue
                    }
                    
                    let dayStart = calendar.startOfDay(for: sample.startDate)
                    if groupedSleep[dayStart] == nil {
                        groupedSleep[dayStart] = []
                    }
                    groupedSleep[dayStart]?.append(sample)
                }
                
                var deletedSleepCount = 0
                for (date, samples) in groupedSleep {
                    if samples.count > 15 { // 如果一天有超过15个样本，认为是重复数据
                        print("   🔥 发现\(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))严重重复数据: \(samples.count) 个")
                        
                        // 删除所有样本
                        try await healthStore.delete(samples)
                        deletedSleepCount += samples.count
                        
                        // 额外的谓词清理
                        let dayStart = calendar.startOfDay(for: date)
                        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                        
                        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
                        let sleepPredicate = HKQuery.predicateForSamples(
                            withStart: dayStart.addingTimeInterval(-6*3600), // 前6小时
                            end: dayEnd.addingTimeInterval(6*3600),         // 后6小时
                            options: []
                        )
                        
                        try await healthStore.deleteObjects(of: sleepType, predicate: sleepPredicate)
                    }
                }
                
                print("   ✅ 删除重复睡眠数据: \(deletedSleepCount) 个")
            }
            
            // 3. 分析和删除重复的步数数据
            if !stepsSamples.isEmpty {
                // 安全的按日期分组，添加错误处理
                var groupedSteps: [Date: [HKQuantitySample]] = [:]
                for sample in stepsSamples {
                    // 添加安全检查，防止崩溃
                    guard sample.startDate.timeIntervalSince1970 > 0 else {
                        print("⚠️ 跳过无效的步数样本（无效日期）")
                        continue
                    }
                    
                    let dayStart = calendar.startOfDay(for: sample.startDate)
                    if groupedSteps[dayStart] == nil {
                        groupedSteps[dayStart] = []
                    }
                    groupedSteps[dayStart]?.append(sample)
                }
                
                var deletedStepsCount = 0
                for (date, samples) in groupedSteps {
                    if samples.count > 30 { // 如果一天有超过30个样本，认为是重复数据
                        print("   🔥 发现\(DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none))严重重复数据: \(samples.count) 个")
                        
                        // 删除所有样本
                        try await healthStore.delete(samples)
                        deletedStepsCount += samples.count
                        
                        // 额外的谓词清理
                        let dayStart = calendar.startOfDay(for: date)
                        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                        
                        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
                        let stepsPredicate = HKQuery.predicateForSamples(
                            withStart: dayStart,
                            end: dayEnd,
                            options: []
                        )
                        
                        try await healthStore.deleteObjects(of: stepsType, predicate: stepsPredicate)
                    }
                }
                
                print("   ✅ 删除重复步数数据: \(deletedStepsCount) 个")
            }
            
            print("✅ 强力清理完成")
            return true
            
        } catch {
            print("❌ 强力清理失败: \(error.localizedDescription)")
            await MainActor.run {
                lastError = error
            }
            return false
        }
    }
    
    // MARK: - 快速批量删除（防卡死优化版）
    func fastBulkDelete(startDate: Date, endDate: Date) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权")
            return false
        }
        
        let calendar = Calendar.current
        let safeStartDate = calendar.startOfDay(for: startDate)
        let safeEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        
        // 🚀 减少日志输出，避免卡顿
        
        do {
            // 使用简单的谓词删除，避免复杂查询
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let sleepPredicate = HKQuery.predicateForSamples(
                withStart: safeStartDate,
                end: safeEndDate,
                options: []
            )
            
            let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
            let stepsPredicate = HKQuery.predicateForSamples(
                withStart: safeStartDate,
                end: safeEndDate,
                options: []
            )
            
            // 并行执行删除操作
            async let sleepDelete = healthStore.deleteObjects(of: sleepType, predicate: sleepPredicate)
            async let stepsDelete = healthStore.deleteObjects(of: stepsType, predicate: stepsPredicate)
            
            let _ = try await sleepDelete
            let _ = try await stepsDelete
            
            // 成功删除，减少日志输出
            return true
            
        } catch {
            print("❌ 快速批量删除失败: \(error.localizedDescription)")
            await MainActor.run {
                lastError = error
            }
            return false
        }
    }
    
    // MARK: - 删除数据（用于测试）
    func deleteAllTestData() async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权")
            return false
        }
        
        do {
            // 删除睡眠数据
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let sleepPredicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-365*24*60*60), end: Date(), options: .strictEndDate)
            
            try await healthStore.deleteObjects(of: sleepType, predicate: sleepPredicate)
            
            // 删除步数数据
            let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
            let stepsPredicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-365*24*60*60), end: Date(), options: .strictEndDate)
            
            try await healthStore.deleteObjects(of: stepsType, predicate: stepsPredicate)
            
            print("✅ 测试数据删除成功")
            return true
            
        } catch {
            print("❌ 删除测试数据失败: \(error.localizedDescription)")
            await MainActor.run {
                lastError = error
            }
            return false
        }
    }
    
    // MARK: - 个性化数据写入功能
    
    // 写入单个步数增量
    @MainActor
    func writeStepIncrement(_ increment: StepIncrement) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权，无法写入步数增量")
            return false
        }
        
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("❌ 无法获取步数数据类型")
            return false
        }
        
        let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: Double(increment.steps))
        let endDate = increment.timestamp
        let startDate = Calendar.current.date(byAdding: .minute, value: -1, to: endDate) ?? endDate
        
        let sample = HKQuantitySample(
            type: stepsType,
            quantity: quantity,
            start: startDate,
            end: endDate,
            device: createiPhoneDevice(),
            metadata: createiPhoneMetadata(extraData: [
                "ActivityType": increment.activityType.rawValue,
                "IncrementType": "MicroIncrement"
            ])
        )
        
        return await withCheckedContinuation { continuation in
            healthStore.save(sample) { success, error in
                if let error = error {
                    print("❌ 步数增量写入失败: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    print("✅ 步数增量写入成功: +\(increment.steps)步 at \(increment.timestamp)")
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    // 批量写入步数增量
    @MainActor 
    func writeStepIncrements(_ increments: [StepIncrement]) async -> Int {
        guard isAuthorized else {
            print("❌ HealthKit未授权，无法写入步数增量")
            return 0
        }
        
        // 使用并发批量写入提高性能
        let batchSize = 10 // 每批最多10个增量
        var successCount = 0
        
        // 将增量分批处理
        for batchIndex in 0..<((increments.count + batchSize - 1) / batchSize) {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, increments.count)
            let batch = Array(increments[startIndex..<endIndex])
            
            // 并发写入当前批次
            let batchResults = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
                for increment in batch {
                    group.addTask {
                        await self.writeStepIncrement(increment)
                    }
                }
                
                var results: [Bool] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            successCount += batchResults.filter { $0 }.count
            
            // 只在批次之间稍作延迟，避免HealthKit限制
            if batchIndex < ((increments.count + batchSize - 1) / batchSize) - 1 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms批次间隔
            }
        }
        
        print("✅ 批量写入完成: \(successCount)/\(increments.count) 成功")
        return successCount
    }
    
    // 写入个性化睡眠数据
    @MainActor
    func writePersonalizedSleepData(_ sleepData: SleepData) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权，无法写入睡眠数据")
            return false
        }
        
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("❌ 无法获取睡眠分析数据类型")
            return false
        }
        
        var samples: [HKCategorySample] = []
        
        // 主要睡眠阶段
        let device = createiPhoneDevice()
        
        let inBedSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.inBed.rawValue,
            start: sleepData.bedTime,
            end: sleepData.wakeTime,
            device: device,
            metadata: createiPhoneMetadata(extraData: [
                "SleepType": "InBed"
            ])
        )
        samples.append(inBedSample)
        
        let asleepSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleep.rawValue,
            start: sleepData.bedTime,
            end: sleepData.wakeTime,
            device: device,
            metadata: createiPhoneMetadata(extraData: [
                "SleepType": "Asleep"
            ])
        )
        samples.append(asleepSample)
        
        // 写入详细睡眠阶段（如果有）
        for stage in sleepData.sleepStages {
            let stageValue: Int
            switch stage.stage {
            case .light:
                stageValue = HKCategoryValueSleepAnalysis.asleep.rawValue
            case .deep:
                stageValue = HKCategoryValueSleepAnalysis.asleep.rawValue
            case .rem:
                stageValue = HKCategoryValueSleepAnalysis.asleep.rawValue
            case .awake:
                stageValue = HKCategoryValueSleepAnalysis.awake.rawValue
            }
            
            let stageSample = HKCategorySample(
                type: sleepType,
                value: stageValue,
                start: stage.startTime,
                end: stage.endTime,
                device: device,
                metadata: createiPhoneMetadata(extraData: [
                    "SleepStage": stage.stage.rawValue
                ])
            )
            samples.append(stageSample)
        }
        
        return await withCheckedContinuation { continuation in
            healthStore.save(samples) { success, error in
                if let error = error {
                    print("❌ 个性化睡眠数据写入失败: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    print("✅ 个性化睡眠数据写入成功: \(samples.count) 个样本")
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    // 删除指定日期范围的个性化数据
    @MainActor
    func deletePersonalizedData(from startDate: Date, to endDate: Date) async -> Bool {
        guard isAuthorized else {
            print("❌ HealthKit未授权，无法删除数据")
            return false
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let metadataPredicate = HKQuery.predicateForObjects(withMetadataKey: "PersonalizedDataSource")
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, metadataPredicate])
        
        // 删除步数数据
        let stepsDeleteSuccess = await deleteData(
            type: HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            predicate: combinedPredicate
        )
        
        // 删除睡眠数据
        let sleepDeleteSuccess = await deleteData(
            type: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            predicate: combinedPredicate
        )
        
        let success = stepsDeleteSuccess && sleepDeleteSuccess
        if success {
            print("✅ 个性化数据删除成功: \(startDate) 到 \(endDate)")
        } else {
            print("❌ 个性化数据删除失败")
        }
        
        return success
    }
    
    // 辅助方法：删除指定类型的数据
    private func deleteData(type: HKSampleType, predicate: NSPredicate) async -> Bool {
        return await withCheckedContinuation { continuation in
            healthStore.deleteObjects(of: type, predicate: predicate) { success, deletedCount, error in
                if let error = error {
                    print("❌ 删除\(type.identifier)数据失败: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    print("✅ 删除\(type.identifier)数据成功: \(deletedCount)条")
                    continuation.resume(returning: true)
                }
            }
        }
    }
}

// MARK: - 睡眠数据模型
struct SleepData: Codable {
    let date: Date
    let bedTime: Date
    let wakeTime: Date
    let sleepStages: [SleepStage]
    
    /// 睡眠持续时间（小时）
    var duration: Double {
        return wakeTime.timeIntervalSince(bedTime) / 3600.0
    }
    
    /// 保持向后兼容性
    var totalSleepTime: TimeInterval {
        return sleepStages.reduce(0) { result, stage in
            if stage.stage != .awake {
                return result + stage.duration
            }
            return result
        }
    }
    
    /// 保持向后兼容性
    var totalSleepHours: Double {
        return totalSleepTime / 3600.0
    }
}

// MARK: - 睡眠阶段
struct SleepStage: Codable {
    let stage: SleepStageType
    let startTime: Date
    let endTime: Date
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

// MARK: - 睡眠阶段类型
enum SleepStageType: String, Codable {
    case awake = "awake"
    case light = "light"
    case deep = "deep"
    case rem = "rem"
    
    var displayName: String {
        switch self {
        case .awake:
            return "清醒"
        case .light:
            return "轻度睡眠"
        case .deep:
            return "深度睡眠"
        case .rem:
            return "REM睡眠"
        }
    }
}

// MARK: - 步数数据模型
struct StepsData {
    let date: Date
    let hourlySteps: [HourlySteps]
    let stepsIntervals: [StepsInterval] // 精细时间间隔的步数数据
    
    var totalSteps: Int {
        return hourlySteps.reduce(0) { $0 + $1.steps }
    }
    
    // 向后兼容的初始化方法（只有hourlySteps）
    init(date: Date, hourlySteps: [HourlySteps]) {
        self.date = date
        self.hourlySteps = hourlySteps
        self.stepsIntervals = [] // 空数组作为默认值
    }
    
    // 新的初始化方法（包含精细间隔）
    init(date: Date, hourlySteps: [HourlySteps], stepsIntervals: [StepsInterval]) {
        self.date = date
        self.hourlySteps = hourlySteps
        self.stepsIntervals = stepsIntervals
    }
}

// MARK: - 小时步数
struct HourlySteps {
    let hour: Int
    let steps: Int
    let startTime: Date
    let endTime: Date
}

// MARK: - 时间段步数（更精细的粒度）
struct StepsInterval {
    let steps: Int
    let startTime: Date
    let endTime: Date
}

// MARK: - HKAuthorizationStatus扩展
extension HKAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "未确定"
        case .sharingDenied:
            return "拒绝"
        case .sharingAuthorized:
            return "已授权"
        @unknown default:
            return "未知"
        }
    }
}

// MARK: - 数据删除扩展
extension HealthKitManager {
    
    // 删除睡眠数据
    func deleteSleepData() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            guard let samples = samples, error == nil else { return }
            
            self.healthStore.delete(samples) { success, error in
                print(success ? "✅ 睡眠数据删除成功" : "❌ 睡眠数据删除失败: \(error?.localizedDescription ?? "未知错误")")
                
                // 清除缓存的今日睡眠数据
                if success {
                    DispatchQueue.main.async {
                        SyncStateManager.shared.todaySleepData = nil
                        SyncStateManager.shared.historicalSleepData.removeAll()
                    }
                }
            }
        }
        
        self.healthStore.execute(query)
    }
    
    // 删除步数数据
    func deleteStepsData() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)
        
        let query = HKSampleQuery(sampleType: stepsType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            guard let samples = samples, error == nil else { return }
            
            self.healthStore.delete(samples) { success, error in
                print(success ? "✅ 步数数据删除成功" : "❌ 步数数据删除失败: \(error?.localizedDescription ?? "未知错误")")
                
                // 清除缓存的今日步数数据
                if success {
                    DispatchQueue.main.async {
                        SyncStateManager.shared.todayStepsData = nil
                        SyncStateManager.shared.historicalStepsData.removeAll()
                    }
                }
            }
        }
        
        self.healthStore.execute(query)
    }
    
    // 删除所有数据
    func deleteAllData() async {
        await deleteSleepData()
        await deleteStepsData()
        
        // 确保清理所有缓存
        DispatchQueue.main.async {
            SyncStateManager.shared.resetTodayData()
            SyncStateManager.shared.clearHistoricalData()
        }
    }
} 