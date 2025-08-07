//
//  DateRangeTest.swift
//  SSDG - 日期范围测试
//
//  验证历史数据生成的日期范围是否正确
//

import Foundation

class DateRangeTest {
    
    static func testDateRanges() {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        
        print("📅 日期范围测试")
        print("===============")
        print("当前时间: \(DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .short))")
        print("今天开始: \(DateFormatter.localizedString(from: todayStart, dateStyle: .medium, timeStyle: .short))")
        print("昨天开始: \(DateFormatter.localizedString(from: yesterdayStart, dateStyle: .medium, timeStyle: .short))")
        print("")
        
        // 测试原来的逻辑（错误的）
        print("🔴 原来的逻辑 (sleepEndDate = yesterdayStart):")
        let oldSleepEndDate = yesterdayStart
        let oldStartDate = calendar.date(byAdding: .day, value: -7, to: oldSleepEndDate)!
        
        print("开始日期: \(DateFormatter.localizedString(from: oldStartDate, dateStyle: .medium, timeStyle: .short))")
        print("结束日期: \(DateFormatter.localizedString(from: oldSleepEndDate, dateStyle: .medium, timeStyle: .short))")
        
        var oldCurrentDate = oldStartDate
        var oldDays: [String] = []
        while oldCurrentDate < oldSleepEndDate {
            oldDays.append(DateFormatter.localizedString(from: oldCurrentDate, dateStyle: .short, timeStyle: .none))
            oldCurrentDate = calendar.date(byAdding: .day, value: 1, to: oldCurrentDate)!
        }
        print("生成的天数: \(oldDays.joined(separator: ", "))")
        print("缺少昨天数据: \(oldDays.contains(DateFormatter.localizedString(from: yesterdayStart, dateStyle: .short, timeStyle: .none)) ? "否" : "是")")
        print("")
        
        // 测试修复后的逻辑（正确的）
        print("✅ 修复后的逻辑 (sleepEndDate = todayStart):")
        let newSleepEndDate = todayStart
        let newStartDate = calendar.date(byAdding: .day, value: -7, to: newSleepEndDate)!
        
        print("开始日期: \(DateFormatter.localizedString(from: newStartDate, dateStyle: .medium, timeStyle: .short))")
        print("结束日期: \(DateFormatter.localizedString(from: newSleepEndDate, dateStyle: .medium, timeStyle: .short))")
        
        var newCurrentDate = newStartDate
        var newDays: [String] = []
        while newCurrentDate < newSleepEndDate {
            newDays.append(DateFormatter.localizedString(from: newCurrentDate, dateStyle: .short, timeStyle: .none))
            newCurrentDate = calendar.date(byAdding: .day, value: 1, to: newCurrentDate)!
        }
        print("生成的天数: \(newDays.joined(separator: ", "))")
        print("包含昨天数据: \(newDays.contains(DateFormatter.localizedString(from: yesterdayStart, dateStyle: .short, timeStyle: .none)) ? "是" : "否")")
        print("")
        
        // 测试PersonalizedDataGenerator的逻辑
        print("🔵 PersonalizedDataGenerator逻辑:")
        let days = 7
        for dayOffset in (1...days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) {
                let dayString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
                let isYesterday = calendar.isDate(date, inSameDayAs: yesterdayStart)
                print("dayOffset=\(dayOffset): \(dayString) \(isYesterday ? "(昨天)" : "")")
            }
        }
        
        print("\n✅ 测试完成")
    }
}