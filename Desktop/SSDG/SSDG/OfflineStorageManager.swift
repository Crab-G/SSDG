import Foundation

/// 离线存储管理器 - 负责预缓存数据的本地存储
class OfflineStorageManager {
    
    // MARK: - Singleton
    static let shared = OfflineStorageManager()
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let cacheDirectoryName = "OfflineDataCache"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    private init() {
        setupEncoder()
        setupDecoder()
        createCacheDirectoryIfNeeded()
    }
    
    /// 设置JSON编码器
    private func setupEncoder() {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    /// 设置JSON解码器
    private func setupDecoder() {
        decoder.dateDecodingStrategy = .iso8601
    }
    
    /// 创建缓存目录
    private func createCacheDirectoryIfNeeded() {
        let cacheURL = getCacheDirectoryURL()
        
        if !fileManager.fileExists(atPath: cacheURL.path) {
            do {
                try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
                print("📁 缓存目录已创建: \(cacheURL.path)")
            } catch {
                print("❌ 创建缓存目录失败: \(error)")
            }
        }
    }
    
    // MARK: - 周数据包管理
    
    /// 保存周数据包
    func saveWeeklyPackage(_ package: WeeklyDataPackage) async {
        let url = getWeeklyPackageURL(for: package.weekStartDate)
        
        do {
            let data = try encoder.encode(package)
            try data.write(to: url)
            
            print("💾 周数据包已保存")
            print("   文件: \(url.lastPathComponent)")
            print("   大小: \(formatFileSize(data.count))")
            print("   周期: \(package.weekDescription)")
            
            // 保存元数据
            await savePackageMetadata(package)
            
        } catch {
            print("❌ 保存周数据包失败: \(error)")
        }
    }
    
    /// 加载周数据包
    func loadWeeklyPackage(for date: Date) async -> WeeklyDataPackage? {
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: date)
        let url = getWeeklyPackageURL(for: weekStart)
        
        guard fileManager.fileExists(atPath: url.path) else {
            print("⚠️ 周数据包文件不存在: \(url.lastPathComponent)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let package = try decoder.decode(WeeklyDataPackage.self, from: data)
            
            print("📂 周数据包已加载")
            print("   文件: \(url.lastPathComponent)")
            print("   大小: \(formatFileSize(data.count))")
            print("   周期: \(package.weekDescription)")
            
            // 验证数据完整性
            let isValid = await validatePackage(package)
            if !isValid {
                print("⚠️ 数据包验证失败，可能已损坏")
                return nil
            }
            
            return package
            
        } catch {
            print("❌ 加载周数据包失败: \(error)")
            return nil
        }
    }
    
    /// 删除周数据包
    func deleteWeeklyPackage(for date: Date) async {
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: date)
        let url = getWeeklyPackageURL(for: weekStart)
        
        do {
            try fileManager.removeItem(at: url)
            print("🗑️ 周数据包已删除: \(url.lastPathComponent)")
            
            // 删除元数据
            await deletePackageMetadata(for: weekStart)
            
        } catch {
            print("❌ 删除周数据包失败: \(error)")
        }
    }
    
    // MARK: - 数据清理
    
    /// 清理过期数据
    func cleanExpiredData() async {
        let cacheURL = getCacheDirectoryURL()
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
            )
            
            var deletedCount = 0
            var reclaimedSpace = 0
            
            for file in files {
                guard file.pathExtension == "json" else { continue }
                
                let resourceValues = try file.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                
                if let creationDate = resourceValues.creationDate,
                   creationDate < cutoffDate {
                    
                    let fileSize = resourceValues.fileSize ?? 0
                    
                    try fileManager.removeItem(at: file)
                    deletedCount += 1
                    reclaimedSpace += fileSize
                    
                    print("🗑️ 已清理过期文件: \(file.lastPathComponent)")
                }
            }
            
            if deletedCount > 0 {
                print("✅ 清理完成")
                print("   删除文件: \(deletedCount)个")
                print("   回收空间: \(formatFileSize(reclaimedSpace))")
            } else {
                print("ℹ️ 无需清理，所有文件都是最新的")
            }
            
        } catch {
            print("❌ 清理过期数据失败: \(error)")
        }
    }
    
    /// 清理所有缓存数据
    func clearAllCache() async {
        let cacheURL = getCacheDirectoryURL()
        
        do {
            try fileManager.removeItem(at: cacheURL)
            createCacheDirectoryIfNeeded()
            print("🗑️ 所有缓存已清理")
        } catch {
            print("❌ 清理所有缓存失败: \(error)")
        }
    }
    
    // MARK: - 存储统计
    
    /// 获取存储统计信息
    func getStorageStats() async -> StorageStats {
        let cacheURL = getCacheDirectoryURL()
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
            )
            
            var totalSize = 0
            var fileCount = 0
            var oldestDate: Date?
            var newestDate: Date?
            
            for file in files {
                guard file.pathExtension == "json" else { continue }
                
                let resourceValues = try file.resourceValues(
                    forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
                )
                
                if let fileSize = resourceValues.fileSize {
                    totalSize += fileSize
                    fileCount += 1
                }
                
                if let creationDate = resourceValues.creationDate {
                    if oldestDate == nil || creationDate < oldestDate! {
                        oldestDate = creationDate
                    }
                    if newestDate == nil || creationDate > newestDate! {
                        newestDate = creationDate
                    }
                }
            }
            
            // 获取可用空间
            let availableSpace = getAvailableSpace()
            
            return StorageStats(
                fileCount: fileCount,
                totalSize: totalSize,
                availableSpace: availableSpace,
                oldestDate: oldestDate,
                newestDate: newestDate,
                lastCleanup: getLastCleanupDate()
            )
            
        } catch {
            print("❌ 获取存储统计失败: \(error)")
            return StorageStats.empty
        }
    }
    
    /// 获取可用存储空间
    private func getAvailableSpace() -> Int64 {
        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(resourceValues.volumeAvailableCapacity ?? 0)
        } catch {
            print("❌ 获取可用空间失败: \(error)")
            return 0
        }
    }
    
    /// 获取上次清理时间
    private func getLastCleanupDate() -> Date? {
        return UserDefaults.standard.object(forKey: "LastCacheCleanupDate") as? Date
    }
    
    /// 保存清理时间
    private func saveLastCleanupDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "LastCacheCleanupDate")
    }
    
    // MARK: - 数据验证
    
    /// 验证数据包完整性
    private func validatePackage(_ package: WeeklyDataPackage) async -> Bool {
        // 基础验证
        guard !package.dailyPlans.isEmpty else {
            print("⚠️ 数据包验证失败: 缺少每日计划")
            return false
        }
        
        guard package.dailyPlans.count == 7 else {
            print("⚠️ 数据包验证失败: 每日计划数量不正确 (\(package.dailyPlans.count))")
            return false
        }
        
        // 检查日期连续性
        let calendar = Calendar.current
        let sortedPlans = package.dailyPlans.sorted { $0.date < $1.date }
        
        for (index, plan) in sortedPlans.enumerated() {
            let expectedDate = calendar.date(byAdding: .day, value: index, to: package.weekStartDate)!
            
            if !calendar.isDate(plan.date, inSameDayAs: expectedDate) {
                print("⚠️ 数据包验证失败: 日期不连续 (第\(index)天)")
                return false
            }
        }
        
        // 检查数据合理性
        for plan in package.dailyPlans {
            // 检查睡眠数据
            if let sleepData = plan.sleepData {
                if sleepData.duration < 4 || sleepData.duration > 12 {
                    print("⚠️ 数据包验证失败: 睡眠时长异常 (\(sleepData.duration)小时)")
                    return false
                }
            }
            
            // 检查步数数据
            if plan.stepDistribution.totalSteps < 0 || plan.stepDistribution.totalSteps > 50000 {
                print("⚠️ 数据包验证失败: 步数异常 (\(plan.stepDistribution.totalSteps))")
                return false
            }
        }
        
        print("✅ 数据包验证通过")
        return true
    }
    
    // MARK: - 元数据管理
    
    /// 保存数据包元数据
    private func savePackageMetadata(_ package: WeeklyDataPackage) async {
        let metadata = PackageMetadata(
            packageID: package.id,
            userID: package.userID,
            weekStartDate: package.weekStartDate,
            generatedDate: package.generatedDate,
            totalSleepHours: package.totalSleepHours,
            totalSteps: package.totalSteps,
            dataVersion: package.dataVersion
        )
        
        let url = getMetadataURL(for: package.weekStartDate)
        
        do {
            let data = try encoder.encode(metadata)
            try data.write(to: url)
            print("📋 元数据已保存: \(url.lastPathComponent)")
        } catch {
            print("❌ 保存元数据失败: \(error)")
        }
    }
    
    /// 删除数据包元数据
    private func deletePackageMetadata(for weekStart: Date) async {
        let url = getMetadataURL(for: weekStart)
        
        do {
            try fileManager.removeItem(at: url)
            print("🗑️ 元数据已删除: \(url.lastPathComponent)")
        } catch {
            print("❌ 删除元数据失败: \(error)")
        }
    }
    
    // MARK: - 文件路径管理
    
    /// 获取缓存目录URL
    private func getCacheDirectoryURL() -> URL {
        return documentsPath.appendingPathComponent(cacheDirectoryName)
    }
    
    /// 获取周数据包文件URL
    private func getWeeklyPackageURL(for weekStart: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "week_\(formatter.string(from: weekStart)).json"
        
        return getCacheDirectoryURL().appendingPathComponent(filename)
    }
    
    /// 获取元数据文件URL
    private func getMetadataURL(for weekStart: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "meta_\(formatter.string(from: weekStart)).json"
        
        return getCacheDirectoryURL().appendingPathComponent(filename)
    }
    
    // MARK: - 工具方法
    
    /// 格式化文件大小
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - 导出和备份
    
    /// 导出所有缓存数据
    func exportAllData() async -> URL? {
        _ = documentsPath.appendingPathComponent("SSDG_Cache_Export_\(Date().timeIntervalSince1970).zip")
        
        // 这里可以实现ZIP压缩导出功能
        // 暂时返回缓存目录URL
        return getCacheDirectoryURL()
    }
    
    /// 从备份恢复数据
    func restoreFromBackup(backupURL: URL) async -> Bool {
        // 这里可以实现从备份恢复功能
        // 暂时返回false
        return false
    }
}

// MARK: - 数据结构

/// 存储统计信息
struct StorageStats {
    let fileCount: Int
    let totalSize: Int
    let availableSpace: Int64
    let oldestDate: Date?
    let newestDate: Date?
    let lastCleanup: Date?
    
    /// 格式化的总大小
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSize))
    }
    
    /// 格式化的可用空间
    var formattedAvailableSpace: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: availableSpace)
    }
    
    /// 是否需要清理
    var needsCleanup: Bool {
        guard let lastCleanup = lastCleanup else { return true }
        let daysSinceCleanup = Date().timeIntervalSince(lastCleanup) / 86400
        return daysSinceCleanup > 7 // 超过7天需要清理
    }
    
    /// 存储使用率
    var storageUsagePercentage: Double {
        guard availableSpace > 0 else { return 0 }
        let totalSpace = Double(totalSize) + Double(availableSpace)
        return Double(totalSize) / totalSpace * 100
    }
    
    /// 空的统计信息
    static let empty = StorageStats(
        fileCount: 0,
        totalSize: 0,
        availableSpace: 0,
        oldestDate: nil,
        newestDate: nil,
        lastCleanup: nil
    )
}

/// 数据包元数据
private struct PackageMetadata: Codable {
    let packageID: UUID
    let userID: String
    let weekStartDate: Date
    let generatedDate: Date
    let totalSleepHours: Double
    let totalSteps: Int
    let dataVersion: String
}

// MARK: - 清除缓存扩展
extension OfflineStorageManager {
    
    // 清除缓存
    func clearCache() {
        // 清除所有缓存数据
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "PreCacheStatus")
        defaults.removeObject(forKey: "WeeklyPackageMetadata")
        
        print("✅ OfflineStorageManager: 缓存已清除")
    }
} 