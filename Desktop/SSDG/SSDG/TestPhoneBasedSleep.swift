import Foundation

/// 测试基于手机使用模式的睡眠数据生成
struct TestPhoneBasedSleep {
    static func runTest() {
        print("🧪 测试基于手机使用模式的睡眠数据生成")
        print(String(repeating: "=", count: 50))
        
        // 测试不同类型的用户
        let testUsers = [
            (VirtualUser(
                id: "nightowl_user",
                age: 25,
                gender: .male,
                height: 175,
                weight: 70,
                sleepBaseline: 7.0,
                stepsBaseline: 8000,
                createdAt: Date(),
                deviceModel: "iPhone 15 Pro",
                deviceSerialNumber: "F2LNIGHT1",
                deviceUUID: "TEST-UUID-NIGHTOWL"
            ), "夜猫子型"),
            
            (VirtualUser(
                id: "earlybird_user",
                age: 35,
                gender: .female,
                height: 165,
                weight: 60,
                sleepBaseline: 8.0,
                stepsBaseline: 10000,
                createdAt: Date(),
                deviceModel: "iPhone 14",
                deviceSerialNumber: "F2LEARLY1",
                deviceUUID: "TEST-UUID-EARLYBIRD"
            ), "早起型"),
            
            (VirtualUser(
                id: "irregular_user",
                age: 28,
                gender: .male,
                height: 180,
                weight: 75,
                sleepBaseline: 6.5,
                stepsBaseline: 6000,
                createdAt: Date(),
                deviceModel: "iPhone 15",
                deviceSerialNumber: "F2LIRREG1",
                deviceUUID: "TEST-UUID-IRREGULAR"
            ), "紊乱型")
        ]
        
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        for (user, typeName) in testUsers {
            print("\n\n📱 测试\(typeName)用户的睡眠数据")
            print(String(repeating: "-", count: 40))
            
            let sleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
                for: user,
                date: yesterday,
                mode: .simple
            )
            
            print("基本信息:")
            print("  入睡时间: \(sleepData.bedTime)")
            print("  起床时间: \(sleepData.wakeTime)")
            print("  总时长: \(String(format: "%.2f", sleepData.totalSleepHours))小时")
            print("  段落总数: \(sleepData.sleepStages.count)")
            
            // 分析段落类型
            let awakeStages = sleepData.sleepStages.filter { $0.stage == .awake }
            let sleepStages = sleepData.sleepStages.filter { $0.stage != .awake }
            
            print("\n段落分析:")
            print("  卧床时间段: \(sleepStages.count)个")
            print("  间隔（空白）: \(sleepStages.count > 1 ? "\(sleepStages.count - 1)个" : "无")")
            
            // 显示时间线
            print("\n时间线详情:")
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            for (index, stage) in sleepData.sleepStages.enumerated() {
                if stage.stage != .awake {  // 只显示卧床时间段
                    let duration = Int(stage.duration / 60)
                    let hours = duration / 60
                    let minutes = duration % 60
                    print("  \(index+1). \(formatter.string(from: stage.startTime))-\(formatter.string(from: stage.endTime)) (\(hours)小时\(minutes)分钟)")
                }
            }
            
            // 找出主睡眠段
            if let mainSleep = sleepStages.max(by: { $0.duration < $1.duration }) {
                let mainDuration = mainSleep.duration / 3600
                print("\n主睡眠段:")
                print("  时间: \(formatter.string(from: mainSleep.startTime))-\(formatter.string(from: mainSleep.endTime))")
                print("  时长: \(String(format: "%.2f", mainDuration))小时")
            }
            
            // 如果有多个段，显示间隔
            if sleepStages.count > 1 {
                print("\n段落间隔:")
                for i in 0..<(sleepStages.count - 1) {
                    let gap = sleepStages[i+1].startTime.timeIntervalSince(sleepStages[i].endTime)
                    let gapMinutes = Int(gap / 60)
                    print("  间隔\(i+1): \(gapMinutes)分钟")
                }
            }
        }
        
        print("\n\n🎉 测试完成！")
        print("新的睡眠数据生成模式更贴合iPhone的实际检测行为")
    }
}