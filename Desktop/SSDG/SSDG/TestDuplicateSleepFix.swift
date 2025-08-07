import Foundation

// 测试睡眠数据去重修复
struct TestDuplicateSleepFix {
    static func runTest() {
        print("🧪 测试睡眠数据去重修复")
        print(String(repeating: "=", count: 50))
        
        // 创建测试用户
        let user = VirtualUser(
            id: "test_user",
            age: 30,
            gender: .male,
            height: 175,
            weight: 70,
            sleepBaseline: 8.0,
            stepsBaseline: 8000,
            createdAt: Date(),
            deviceModel: "iPhone 14 Pro",
            deviceSerialNumber: "F2LTEST1",
            deviceUUID: "TEST-UUID-SLEEP-FIX"
        )
        
        // 测试1：生成昨晚的睡眠数据
        print("\n📊 测试1：生成昨晚的睡眠数据")
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        let sleepData1 = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: yesterday,
            mode: .simple
        )
        
        print("生成的睡眠数据：")
        print("  日期: \(sleepData1.date)")
        print("  入睡: \(sleepData1.bedTime)")
        print("  起床: \(sleepData1.wakeTime)")
        print("  段落数: \(sleepData1.sleepStages.count)")
        
        // 显示所有睡眠段
        print("\n睡眠段详情：")
        for (index, stage) in sleepData1.sleepStages.enumerated() {
            let duration = stage.duration / 3600 // 转换为小时
            print("  段落\(index + 1): \(stage.startTime) - \(stage.endTime) (\(String(format: "%.2f", duration))小时)")
        }
        
        // 检查是否有重复或重叠的段落
        print("\n检查重复/重叠：")
        var hasOverlap = false
        for i in 0..<sleepData1.sleepStages.count {
            for j in (i+1)..<sleepData1.sleepStages.count {
                let stage1 = sleepData1.sleepStages[i]
                let stage2 = sleepData1.sleepStages[j]
                
                // 检查是否有重叠
                if stage1.startTime < stage2.endTime && stage2.startTime < stage1.endTime {
                    hasOverlap = true
                    print("  ❌ 发现重叠: 段落\(i+1) 和 段落\(j+1)")
                }
            }
        }
        
        if !hasOverlap {
            print("  ✅ 没有发现重叠的睡眠段")
        }
        
        // 测试2：再次生成相同日期的睡眠数据
        print("\n📊 测试2：再次生成相同日期的睡眠数据")
        let sleepData2 = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user,
            date: yesterday,
            mode: .simple
        )
        
        // 比较两次生成的数据
        print("\n比较两次生成的数据：")
        print("  第一次段落数: \(sleepData1.sleepStages.count)")
        print("  第二次段落数: \(sleepData2.sleepStages.count)")
        print("  入睡时间相同: \(sleepData1.bedTime == sleepData2.bedTime)")
        print("  起床时间相同: \(sleepData1.wakeTime == sleepData2.wakeTime)")
        
        // 测试3：测试历史数据生成
        print("\n📊 测试3：生成3天历史数据")
        let historicalData = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: user,
            days: 3,
            mode: .simple
        )
        
        print("生成的历史睡眠数据：")
        for (index, sleep) in historicalData.sleepData.enumerated() {
            print("  \(index + 1). 日期: \(sleep.date), 段落数: \(sleep.sleepStages.count)")
        }
        
        // 检查是否有重复日期
        print("\n检查重复日期：")
        var dateSet = Set<Date>()
        var hasDuplicateDates = false
        
        for sleep in historicalData.sleepData {
            let startOfDay = calendar.startOfDay(for: sleep.date)
            if dateSet.contains(startOfDay) {
                hasDuplicateDates = true
                print("  ❌ 发现重复日期: \(startOfDay)")
            } else {
                dateSet.insert(startOfDay)
            }
        }
        
        if !hasDuplicateDates {
            print("  ✅ 没有发现重复的日期")
        }
        
        print("\n🎉 测试完成！")
    }
}

