//
//  YesterdayDataTest.swift
//  SSDG - 昨天数据生成测试
//
//  测试修复后是否能正确生成昨天的数据
//

import Foundation

class YesterdayDataTest {
    
    static func testYesterdayDataGeneration() {
        print("🧪 昨天数据生成测试")
        print("==================")
        
        // 创建测试用户
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .normal,
            activityLevel: .medium
        )
        
        print("👤 测试用户: \(testUser.personalizedDescription)")
        
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        
        print("📅 时间信息:")
        print("   当前时间: \(DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .short))")
        print("   今天开始: \(DateFormatter.localizedString(from: todayStart, dateStyle: .medium, timeStyle: .short))")
        print("   昨天开始: \(DateFormatter.localizedString(from: yesterdayStart, dateStyle: .medium, timeStyle: .short))")
        print("")
        
        // 测试生成3天数据（应该包含昨天）
        print("🔄 生成3天历史数据...")
        let (sleepData, stepsData) = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: testUser,
            days: 3,
            mode: .simple
        )
        
        print("📊 生成结果:")
        print("   睡眠数据: \(sleepData.count)条")
        print("   步数数据: \(stepsData.count)条")
        print("")
        
        // 检查是否包含昨天的数据
        print("🔍 检查昨天数据:")
        let yesterdaySleepData = sleepData.filter { sleep in
            calendar.isDate(sleep.date, inSameDayAs: yesterdayStart)
        }
        
        let yesterdayStepsData = stepsData.filter { steps in
            calendar.isDate(steps.date, inSameDayAs: yesterdayStart)
        }
        
        print("   昨天睡眠数据: \(yesterdaySleepData.count)条")
        print("   昨天步数数据: \(yesterdayStepsData.count)条")
        
        if !yesterdaySleepData.isEmpty {
            let sleep = yesterdaySleepData.first!
            print("   ✅ 昨天睡眠: \(DateFormatter.localizedString(from: sleep.bedTime, dateStyle: .none, timeStyle: .short)) - \(DateFormatter.localizedString(from: sleep.wakeTime, dateStyle: .none, timeStyle: .short))")
        } else {
            print("   ❌ 缺少昨天睡眠数据")
        }
        
        if !yesterdayStepsData.isEmpty {
            let steps = yesterdayStepsData.first!
            print("   ✅ 昨天步数: \(steps.totalSteps)步")
        } else {
            print("   ❌ 缺少昨天步数数据")
        }
        
        // 显示所有生成的日期
        print("\n📋 所有生成的日期:")
        print("睡眠数据日期:")
        for (index, sleep) in sleepData.enumerated() {
            let dateString = DateFormatter.localizedString(from: sleep.date, dateStyle: .short, timeStyle: .none)
            let isYesterday = calendar.isDate(sleep.date, inSameDayAs: yesterdayStart)
            let isToday = calendar.isDate(sleep.date, inSameDayAs: todayStart)
            let dayLabel = isYesterday ? " (昨天)" : (isToday ? " (今天)" : "")
            print("   \(index + 1). \(dateString)\(dayLabel)")
        }
        
        print("步数数据日期:")
        for (index, steps) in stepsData.enumerated() {
            let dateString = DateFormatter.localizedString(from: steps.date, dateStyle: .short, timeStyle: .none)
            let isYesterday = calendar.isDate(steps.date, inSameDayAs: yesterdayStart)
            let isToday = calendar.isDate(steps.date, inSameDayAs: todayStart)
            let dayLabel = isYesterday ? " (昨天)" : (isToday ? " (今天)" : "")
            print("   \(index + 1). \(dateString)\(dayLabel) - \(steps.totalSteps)步")
        }
        
        let hasYesterdayData = !yesterdaySleepData.isEmpty && !yesterdayStepsData.isEmpty
        print("\n\(hasYesterdayData ? "✅" : "❌") 测试结果: \(hasYesterdayData ? "成功生成昨天数据" : "缺少昨天数据")")
        
        if hasYesterdayData {
            print("🎉 修复成功！现在可以正确生成包含昨天的历史数据")
        } else {
            print("⚠️ 仍有问题，需要进一步检查")
        }
    }
    
    // 简化版测试，只测试日期逻辑
    static func testDateLogic() {
        print("\n🧮 日期逻辑验证")
        print("================")
        
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        print("生成7天历史数据的日期范围:")
        let days = 7
        
        for dayOffset in (1...days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) {
                let dateString = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                let dayOfWeek = DateFormatter().weekdaySymbols[calendar.component(.weekday, from: date) - 1]
                let isYesterday = dayOffset == 1
                print("   Day -\(dayOffset): \(dateString) (\(dayOfWeek))\(isYesterday ? " ← 昨天" : "")")
                
                // 验证这个日期是否通过sleep数据生成的时间检查
                let passesCheck = date < todayStart
                print("     通过睡眠数据时间检查: \(passesCheck ? "✅" : "❌")")
            }
        }
    }
}