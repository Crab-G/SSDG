import Foundation

struct TestSleepDataFix {
    static func runTest() {
        print("🧪 测试异常睡眠数据修复")
        print(String(repeating: "=", count: 50))
        
        // 创建测试用户（紊乱型，更容易出现异常数据）
        let user = VirtualUser(
            id: "test_irregular_user",
            age: 25,
            gender: .female,
            height: 165,
            weight: 60,
            sleepBaseline: 7.5,
            stepsBaseline: 7000,
            createdAt: Date(),
            deviceModel: "iPhone 15 Pro",
            deviceSerialNumber: "F2LTEST2",
            deviceUUID: "TEST-UUID-SLEEP-FIX-2"
        )
        
        print("\n📊 生成10天的睡眠数据，检查是否有异常")
        let calendar = Calendar.current
        
        for i in 1...10 {
            let testDate = calendar.date(byAdding: .day, value: -i, to: Date())!
            let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
                for: user,
                date: testDate,
                mode: .simple
            )
            
            print("\n第\(i)天 (\(testDate)):")
            print("  入睡时间: \(sleepData.bedTime)")
            print("  起床时间: \(sleepData.wakeTime)")
            print("  段落数: \(sleepData.sleepStages.count)")
            print("  总睡眠时长: \(String(format: "%.2f", sleepData.totalSleepHours))小时")
            
            // 检查异常情况
            var hasIssues = false
            
            // 1. 检查总睡眠时长
            if sleepData.totalSleepHours > 12.0 {
                print("  ❌ 异常：总睡眠时长超过12小时！")
                hasIssues = true
            }
            
            // 2. 检查段落数量
            if sleepData.sleepStages.count > 6 {
                print("  ❌ 异常：睡眠段落数超过6个！")
                hasIssues = true
            }
            
            // 3. 检查是否有重叠段落
            for i in 0..<sleepData.sleepStages.count {
                for j in (i+1)..<sleepData.sleepStages.count {
                    let stage1 = sleepData.sleepStages[i]
                    let stage2 = sleepData.sleepStages[j]
                    
                    if stage1.startTime < stage2.endTime && stage2.startTime < stage1.endTime {
                        print("  ❌ 异常：发现重叠段落！")
                        print("    段落\(i+1): \(stage1.startTime) - \(stage1.endTime)")
                        print("    段落\(j+1): \(stage2.startTime) - \(stage2.endTime)")
                        hasIssues = true
                    }
                }
            }
            
            // 4. 检查极短段落
            for (index, stage) in sleepData.sleepStages.enumerated() {
                let durationMinutes = stage.duration / 60
                if durationMinutes < 1.0 {
                    print("  ❌ 异常：发现极短段落（<1分钟）！")
                    print("    段落\(index+1): \(String(format: "%.2f", durationMinutes))分钟")
                    hasIssues = true
                }
            }
            
            // 5. 显示所有段落详情
            if hasIssues {
                print("\n  段落详情:")
                for (index, stage) in sleepData.sleepStages.enumerated() {
                    let durationHours = stage.duration / 3600
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    print("    \(index+1). \(stage.stage == .awake ? "清醒" : "睡眠"): \(formatter.string(from: stage.startTime)) - \(formatter.string(from: stage.endTime)) (\(String(format: "%.2f", durationHours))小时)")
                }
            } else {
                print("  ✅ 数据正常")
            }
        }
        
        print("\n🎉 测试完成！")
    }
}