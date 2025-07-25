//
//  VirtualUserTests.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation

// MARK: - 虚拟用户生成测试
class VirtualUserTests {
    
    // 测试单个用户生成
    static func testSingleUserGeneration() {
        print("🧪 开始测试单个用户生成...")
        
        let user = VirtualUserGenerator.generateRandomUser()
        
        print("✅ 生成的用户信息：")
        print(user.detailedDescription)
        print()
        
        // 验证用户数据有效性
        if user.isValid {
            print("✅ 用户数据验证通过")
        } else {
            print("❌ 用户数据验证失败：")
            user.validationErrors.forEach { print("   - \($0)") }
        }
        print()
    }
    
    // 测试批量用户生成
    static func testBatchUserGeneration(count: Int = 10) {
        print("🧪 开始测试批量用户生成（\(count)个用户）...")
        
        let users = VirtualUserGenerator.generateMultipleUsers(count: count)
        let statistics = UserStatistics(users: users)
        
        print("✅ 生成 \(users.count) 个用户")
        print("📊 统计信息：")
        print("   平均年龄: \(String(format: "%.1f", statistics.averageAge))岁")
        print("   性别分布: \(statistics.genderDistribution)")
        print("   平均身高: \(String(format: "%.1f", statistics.averageHeight))cm")
        print("   平均体重: \(String(format: "%.1f", statistics.averageWeight))kg")
        print("   平均BMI: \(String(format: "%.1f", statistics.averageBMI))")
        print("   平均睡眠基准: \(String(format: "%.1f", statistics.averageSleepBaseline))小时")
        print("   平均步数基准: \(String(format: "%.0f", statistics.averageStepsBaseline))步")
        print()
        
        // 验证所有用户
        let validUsers = users.filter { $0.isValid }
        print("✅ 有效用户数: \(validUsers.count)/\(users.count)")
        
        if validUsers.count < users.count {
            print("❌ 无效用户详情：")
            users.filter { !$0.isValid }.forEach { user in
                print("   用户ID: \(user.id.prefix(8))")
                user.validationErrors.forEach { print("     - \($0)") }
            }
        }
        print()
    }
    
    // 测试种子随机数生成器的一致性
    static func testSeededRandomGeneration() {
        print("🧪 开始测试种子随机数生成器的一致性...")
        
        let seed: UInt64 = 12345
        var generator1 = SeededRandomGenerator(seed: seed)
        var generator2 = SeededRandomGenerator(seed: seed)
        
        print("✅ 使用相同种子生成随机数：")
        for i in 1...5 {
            let value1 = generator1.nextInt(in: 1...100)
            let value2 = generator2.nextInt(in: 1...100)
            print("   第\(i)次: \(value1) == \(value2) -> \(value1 == value2 ? "✅" : "❌")")
        }
        print()
    }
    
    // 测试用户属性范围
    static func testUserAttributeRanges(count: Int = 100) {
        print("🧪 开始测试用户属性范围（\(count)个用户样本）...")
        
        let users = VirtualUserGenerator.generateMultipleUsers(count: count)
        
        let ages = users.map { $0.age }
        let heights = users.map { $0.height }
        let weights = users.map { $0.weight }
        let sleepBaselines = users.map { $0.sleepBaseline }
        let stepsBaselines = users.map { $0.stepsBaseline }
        
        print("✅ 属性范围检查：")
        print("   年龄范围: \(ages.min()!) - \(ages.max()!)岁 (期望: 18-80)")
        print("   身高范围: \(String(format: "%.1f", heights.min()!)) - \(String(format: "%.1f", heights.max()!))cm (期望: 150.0-200.0)")
        print("   体重范围: \(String(format: "%.1f", weights.min()!)) - \(String(format: "%.1f", weights.max()!))kg (期望: 50.0-100.0)")
        print("   睡眠基准范围: \(String(format: "%.1f", sleepBaselines.min()!)) - \(String(format: "%.1f", sleepBaselines.max()!))小时 (期望: 7.0-9.0)")
        print("   步数基准范围: \(stepsBaselines.min()!) - \(stepsBaselines.max()!)步 (期望: 5000-15000)")
        print()
        
        // 检查是否有超出范围的值
        let ageValid = ages.allSatisfy { $0 >= 18 && $0 <= 80 }
        let heightValid = heights.allSatisfy { $0 >= 150.0 && $0 <= 200.0 }
        let weightValid = weights.allSatisfy { $0 >= 50.0 && $0 <= 100.0 }
        let sleepValid = sleepBaselines.allSatisfy { $0 >= 7.0 && $0 <= 9.0 }
        let stepsValid = stepsBaselines.allSatisfy { $0 >= 5000 && $0 <= 15000 }
        
        print("✅ 范围验证结果：")
        print("   年龄: \(ageValid ? "✅" : "❌")")
        print("   身高: \(heightValid ? "✅" : "❌")")
        print("   体重: \(weightValid ? "✅" : "❌")")
        print("   睡眠基准: \(sleepValid ? "✅" : "❌")")
        print("   步数基准: \(stepsValid ? "✅" : "❌")")
        print()
    }
    
    // 测试性别和体重的相关性
    static func testGenderWeightCorrelation(count: Int = 100) {
        print("🧪 开始测试性别和体重的相关性（\(count)个用户样本）...")
        
        let users = VirtualUserGenerator.generateMultipleUsers(count: count)
        
        let maleUsers = users.filter { $0.gender == .male }
        let femaleUsers = users.filter { $0.gender == .female }
        let otherUsers = users.filter { $0.gender == .other }
        
        if !maleUsers.isEmpty {
            let maleAvgWeight = maleUsers.map { $0.weight }.reduce(0, +) / Double(maleUsers.count)
            print("   男性平均体重: \(String(format: "%.1f", maleAvgWeight))kg (\(maleUsers.count)人)")
        }
        
        if !femaleUsers.isEmpty {
            let femaleAvgWeight = femaleUsers.map { $0.weight }.reduce(0, +) / Double(femaleUsers.count)
            print("   女性平均体重: \(String(format: "%.1f", femaleAvgWeight))kg (\(femaleUsers.count)人)")
        }
        
        if !otherUsers.isEmpty {
            let otherAvgWeight = otherUsers.map { $0.weight }.reduce(0, +) / Double(otherUsers.count)
            print("   其他性别平均体重: \(String(format: "%.1f", otherAvgWeight))kg (\(otherUsers.count)人)")
        }
        print()
    }
    
    // 运行所有测试
    static func runAllTests() {
        print("🚀 开始运行虚拟用户生成测试套件")
        print(String(repeating: "=", count: 50))
        
        testSingleUserGeneration()
        testBatchUserGeneration()
        testSeededRandomGeneration()
        testUserAttributeRanges()
        testGenderWeightCorrelation()
        
        print("✅ 所有测试完成！")
        print(String(repeating: "=", count: 50))
    }
} 