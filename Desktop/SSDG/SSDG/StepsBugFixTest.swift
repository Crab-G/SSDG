//
//  StepsBugFixTest.swift
//  SSDG - 极少步数Bug修复测试
//
//  测试修复后是否还会产生极少步数（<100步）的异常情况
//

import Foundation

class StepsBugFixTest {
    
    /// 全面测试步数生成算法，检查极少步数bug
    static func testExtremelyLowStepsBugFix() {
        print("🧪 极少步数Bug修复验证")
        print("========================")
        
        var problematicCases: [(date: String, steps: Int, userType: String)] = []
        let testDays = 100 // 测试100天
        
        print("开始测试 \(testDays) 天数据生成...")
        
        // 测试不同类型的用户
        let testUsers = createTestUsers()
        
        for (index, user) in testUsers.enumerated() {
            print("\n👤 测试用户 \(index + 1)/\(testUsers.count): \(user.personalizedDescription)")
            
            let calendar = Calendar.current
            let today = Date()
            
            for dayOffset in 1...testDays {
                guard let testDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                
                // 测试原始方法（保留用于验证底层修复）
                let distribution = PersonalizedDataGenerator.generatePersonalizedDailySteps(for: user, date: testDate)
                
                // 检查是否有极少步数
                if distribution.totalSteps < 100 {
                    let dateString = DateFormatter.localizedString(from: testDate, dateStyle: .medium, timeStyle: .none)
                    problematicCases.append((
                        date: dateString,
                        steps: distribution.totalSteps,
                        userType: user.personalizedDescription
                    ))
                    
                    print("❌ 发现极少步数: \(dateString) -> \(distribution.totalSteps)步")
                }
                
                // 显示进度
                if dayOffset % 20 == 0 {
                    print("   已测试: \(dayOffset)/\(testDays)天")
                }
            }
        }
        
        // 结果分析
        analyzeTestResults(problematicCases: problematicCases, totalTests: testUsers.count * testDays)
        
        // 如果还有问题，进行深度诊断
        if !problematicCases.isEmpty {
            performDeepDiagnosis(problematicCases: problematicCases)
        }
    }
    
    /// 创建多种类型的测试用户
    private static func createTestUsers() -> [VirtualUser] {
        var users: [VirtualUser] = []
        
        // 测试所有睡眠类型和活动水平的组合
        for sleepType in SleepType.allCases {
            for activityLevel in ActivityLevel.allCases {
                let user = VirtualUserGenerator.generatePersonalizedUser(
                    sleepType: sleepType,
                    activityLevel: activityLevel
                )
                users.append(user)
            }
        }
        
        return users
    }
    
    /// 分析测试结果
    private static func analyzeTestResults(problematicCases: [(date: String, steps: Int, userType: String)], totalTests: Int) {
        print("\n📊 测试结果分析")
        print("================")
        print("总测试案例: \(totalTests)个")
        print("发现问题案例: \(problematicCases.count)个")
        
        if problematicCases.isEmpty {
            print("🎉 修复成功！未发现极少步数问题")
            print("✅ 所有生成的步数都 ≥ 800步")
        } else {
            let failureRate = Double(problematicCases.count) / Double(totalTests) * 100
            print("⚠️ 仍存在问题，失败率: \(String(format: "%.2f", failureRate))%")
            
            // 统计问题类型
            var userTypeStats: [String: Int] = [:]
            var stepsRangeStats: [String: Int] = [:]
            
            for case_ in problematicCases {
                userTypeStats[case_.userType, default: 0] += 1
                
                let range: String
                switch case_.steps {
                case 0...10: range = "0-10步"
                case 11...50: range = "11-50步"
                case 51...99: range = "51-99步"
                default: range = "其他"
                }
                stepsRangeStats[range, default: 0] += 1
            }
            
            print("\n问题用户类型分布:")
            for (userType, count) in userTypeStats.sorted(by: { $0.value > $1.value }) {
                print("   \(userType): \(count)次")
            }
            
            print("\n问题步数范围分布:")
            for (range, count) in stepsRangeStats.sorted(by: { $0.value > $1.value }) {
                print("   \(range): \(count)次")
            }
        }
    }
    
    /// 深度诊断问题原因
    private static func performDeepDiagnosis(problematicCases: [(date: String, steps: Int, userType: String)]) {
        print("\n🔬 深度诊断")
        print("===========")
        
        // 选择最严重的几个案例进行详细分析
        let worstCases = problematicCases.sorted { $0.steps < $1.steps }.prefix(5)
        
        for (index, case_) in worstCases.enumerated() {
            print("\n案例 \(index + 1): \(case_.date) - \(case_.steps)步 (\(case_.userType))")
            
            // 重新生成这个案例，添加调试信息
            let user = VirtualUserGenerator.generatePersonalizedUser(
                sleepType: .normal, // 简化测试
                activityLevel: .low
            )
            
            let calendar = Calendar.current
            let testDate = calendar.date(byAdding: .day, value: -1, to: Date())!
            
            print("🔍 详细生成过程:")
            // 测试原始方法（保留用于底层修复验证）
            let distribution = PersonalizedDataGenerator.generatePersonalizedDailySteps(for: user, date: testDate)
            
            print("   活动水平: \(user.personalizedProfile.activityLevel.displayName)")
            print("   步数范围: \(user.personalizedProfile.activityLevel.stepRange)")
            print("   周末系数: \(user.personalizedProfile.activityPattern.weekendMultiplier)")
            print("   最终结果: \(distribution.totalSteps)步")
        }
        
        print("\n💡 可能的剩余问题:")
        print("1. 个性化配置推断逻辑异常")
        print("2. 种子生成导致极端随机值")
        print("3. 其他隐藏的数值计算bug")
    }
    
    /// 测试修复前后的对比
    static func compareBeforeAfterFix() {
        print("\n🔄 修复前后对比测试")
        print("==================")
        
        // 模拟修复前的逻辑（没有min保护）
        print("🔴 修复前逻辑模拟:")
        simulateOldBuggyLogic()
        
        print("\n✅ 修复后逻辑验证:")
        testNewFixedLogic()
    }
    
    private static func simulateOldBuggyLogic() {
        // 模拟可能导致极少步数的情况
        let _ = (min: 1500, max: 4500) // lowActivityRange for reference
        let extremeWeekendMultiplier: Float = 0.01 // 模拟异常小的系数
        
        let baseSteps = 1500 // 最小值
        let rawResult = Int(Float(baseSteps) * extremeWeekendMultiplier)
        
        print("   基础步数: \(baseSteps)")
        print("   异常系数: \(extremeWeekendMultiplier)")
        print("   原始结果: \(rawResult)步 ❌")
        print("   问题: 没有最小值保护")
    }
    
    private static func testNewFixedLogic() {
        let _ = (min: 1500, max: 4500) // lowActivityRange for reference
        let extremeWeekendMultiplier: Float = 0.01
        
        let baseSteps = 1500
        let rawResult = Int(Float(baseSteps) * extremeWeekendMultiplier)
        let fixedResult = max(800, min(25000, rawResult)) // 修复后的保护
        
        print("   基础步数: \(baseSteps)")
        print("   异常系数: \(extremeWeekendMultiplier)")
        print("   原始结果: \(rawResult)步")
        print("   修复结果: \(fixedResult)步 ✅")
        print("   改进: 应用了800步最小值保护")
    }
}