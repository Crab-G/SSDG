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
            print("  清醒段(手机使用): \(awakeStages.count)个")
            print("  睡眠段: \(sleepStages.count)个")
            
            // 显示时间线
            print("\n时间线详情:")
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            for (index, stage) in sleepData.sleepStages.enumerated() {
                let duration = Int(stage.duration / 60)
                let type = stage.stage == .awake ? "📱使用" : "😴睡眠"
                print("  \(index+1). \(formatter.string(from: stage.startTime))-\(formatter.string(from: stage.endTime)) (\(duration)分钟) \(type)")
            }
            
            // 找出主睡眠段
            if let mainSleep = sleepStages.max(by: { $0.duration < $1.duration }) {
                let mainDuration = mainSleep.duration / 3600
                print("\n主睡眠段:")
                print("  时间: \(formatter.string(from: mainSleep.startTime))-\(formatter.string(from: mainSleep.endTime))")
                print("  时长: \(String(format: "%.2f", mainDuration))小时")
            }
            
            // 统计手机使用模式
            let beforeBedAwake = awakeStages.filter { $0.endTime <= sleepData.bedTime }
            let nightAwake = awakeStages.filter { $0.startTime > sleepData.bedTime && $0.endTime < sleepData.wakeTime }
            let morningAwake = awakeStages.filter { $0.startTime >= sleepData.wakeTime.addingTimeInterval(-1800) }
            
            print("\n手机使用模式:")
            print("  睡前使用: \(beforeBedAwake.count)次")
            print("  夜间查看: \(nightAwake.count)次")
            print("  早晨使用: \(morningAwake.count)次")
        }
        
        print("\n\n🎉 测试完成！")
        print("新的睡眠数据生成模式更贴合iPhone的实际检测行为")
    }
}