//
//  SleepDataVariationDiagnostic.swift
//  SSDG
//
//  Created by Claude on 2025/8/1.
//

import Foundation

/// 🔍 睡眠数据多样性诊断工具
struct SleepDataVariationDiagnostic {
    
    /// 🎯 诊断睡眠数据为什么缺乏多样性
    @MainActor
    static func diagnoseSleepVariation() {
        print("\n🔍 睡眠数据多样性诊断")
        print(String(repeating: "=", count: 60))
        
        guard let user = SyncStateManager.shared.currentUser else {
            print("❌ 无用户数据，无法诊断")
            return
        }
        
        print("✅ 用户: \(user.personalizedProfile.sleepType.displayName)")
        
        // 1. 测试种子生成多样性
        print("\n🧪 测试种子生成多样性...")
        testSeedGeneration(user: user)
        
        // 2. 测试睡眠时长生成多样性
        print("\n🧪 测试睡眠时长生成多样性...")
        testSleepDurationGeneration(user: user)
        
        // 3. 测试完整睡眠数据生成多样性
        print("\n🧪 测试完整睡眠数据生成多样性...")
        testCompleteSleepGeneration(user: user)
        
        print("\n" + String(repeating: "=", count: 60))
        print("🔍 诊断完成")
    }
    
    /// 🌱 测试种子生成多样性
    private static func testSeedGeneration(user: VirtualUser) {
        let calendar = Calendar.current
        let today = Date()
        
        print("   测试最近7天的种子生成:")
        var seeds: [Int] = []
        
        for i in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: today)) else { continue }
            
            let seedString = user.id + date.timeIntervalSince1970.description
            let seed = abs(seedString.hashValue) % 100000
            seeds.append(seed)
            
            let dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
            print("     \(dateStr): 种子=\(seed), 输入=\"\(seedString)\"")
        }
        
        // 检查种子重复性
        let uniqueSeeds = Set(seeds)
        print("   种子分析:")
        print("     总种子数: \(seeds.count)")
        print("     唯一种子数: \(uniqueSeeds.count)")
        print("     重复率: \(String(format: "%.1f", (1.0 - Double(uniqueSeeds.count) / Double(seeds.count)) * 100))%")
        
        if uniqueSeeds.count < seeds.count {
            print("     ❌ 发现种子重复！这是导致数据相同的原因")
        }
    }
    
    /// 💤 测试睡眠时长生成多样性
    private static func testSleepDurationGeneration(user: VirtualUser) {
        let calendar = Calendar.current
        let today = Date()
        let sleepType = user.personalizedProfile.sleepType
        
        print("   睡眠类型: \(sleepType.displayName)")
        print("   时长范围: \(sleepType.durationRange.min)-\(sleepType.durationRange.max)小时")
        print("   一致性: \(sleepType.consistency)")
        
        print("   测试最近7天的睡眠时长:")
        var durations: [Double] = []
        
        for i in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: today)) else { continue }
            
            let seedString = user.id + date.timeIntervalSince1970.description
            let seed = abs(seedString.hashValue) % 100000
            var generator = SeededRandomGenerator(seed: UInt64(abs(seed)))
            
            let range = sleepType.durationRange
            let duration = Double(generator.nextFloat(in: Float(range.min)...Float(range.max)))
            durations.append(duration)
            
            let dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
            print("     \(dateStr): \(String(format: "%.2f", duration))小时 (种子: \(seed))")
        }
        
        // 分析时长多样性
        let uniqueDurations = Set(durations.map { String(format: "%.1f", $0) })
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let maxDuration = durations.max() ?? 0
        let minDuration = durations.min() ?? 0
        
        print("   时长分析:")
        print("     平均时长: \(String(format: "%.2f", avgDuration))小时")
        print("     最大时长: \(String(format: "%.2f", maxDuration))小时")
        print("     最小时长: \(String(format: "%.2f", minDuration))小时")
        print("     变化范围: \(String(format: "%.2f", maxDuration - minDuration))小时")
        print("     唯一值数: \(uniqueDurations.count)/\(durations.count)")
        
        if maxDuration - minDuration < 0.5 {
            print("     ❌ 变化范围太小！这解释了为什么所有数据看起来一样")
        }
    }
    
    /// 🛏️ 测试完整睡眠数据生成多样性
    private static func testCompleteSleepGeneration(user: VirtualUser) {
        let calendar = Calendar.current
        let today = Date()
        
        print("   测试最近5天的完整睡眠数据:")
        
        for i in 1...5 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: today)) else { continue }
            
            let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
                for: user, 
                date: date, 
                mode: .simple
            )
            
            let dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
            let bedTimeStr = DateFormatter.localizedString(from: sleepData.bedTime, dateStyle: .none, timeStyle: .short)
            let wakeTimeStr = DateFormatter.localizedString(from: sleepData.wakeTime, dateStyle: .none, timeStyle: .short)
            
            print("     \(dateStr):")
            print("       入睡: \(bedTimeStr)")
            print("       起床: \(wakeTimeStr)")
            print("       时长: \(String(format: "%.2f", sleepData.totalSleepHours))小时")
            print("       阶段数: \(sleepData.sleepStages.count)")
        }
    }
    
    /// 🔧 测试修复后的效果
    @MainActor
    static func testImprovedSeedGeneration() {
        print("\n🔧 测试改进的种子生成方案")
        print(String(repeating: "=", count: 60))
        
        guard let user = SyncStateManager.shared.currentUser else {
            print("❌ 无用户数据")
            return
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        print("   改进方案对比:")
        
        for i in 1...5 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: today)) else { continue }
            
            // 原始方案
            let oldSeedString = user.id + date.timeIntervalSince1970.description
            let oldSeed = abs(oldSeedString.hashValue) % 100000
            
            // 改进方案（更多变化因子）
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            let newSeedString = user.id + dateString + String(Int(date.timeIntervalSince1970) % 86400)
            let newSeed = abs(newSeedString.hashValue) % 100000
            
            let dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
            print("     \(dateStr): 原始=\(oldSeed), 改进=\(newSeed)")
        }
    }
}

// MARK: - 便捷调用函数
@MainActor
func diagnoseSleepVariation() {
    SleepDataVariationDiagnostic.diagnoseSleepVariation()
}

@MainActor 
func testImprovedSeedGeneration() {
    SleepDataVariationDiagnostic.testImprovedSeedGeneration()
}