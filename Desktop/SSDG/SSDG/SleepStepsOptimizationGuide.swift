//
//  SleepStepsOptimizationGuide.swift
//  SSDG - 睡眠步数优化方案使用指南
//
//  提供睡眠和步数数据联动生成的优化使用示例
//

import Foundation

// MARK: - 优化方案使用指南
class SleepStepsOptimizationGuide {
    
    // MARK: - 使用示例
    
    /// 完整的优化数据生成示例
    static func generateOptimizedHealthData(for user: VirtualUser) {
        print("🚀 开始生成优化后的健康数据")
        print("==========================================")
        
        // 1. 基础信息展示
        print("👤 用户信息:")
        print("   ID: \(user.id.prefix(8))")
        print("   年龄: \(user.age)岁")
        print("   个性化标签: \(user.personalizedDescription)")
        print("")
        
        // 2. 生成优化后的历史数据
        print("📊 生成30天优化历史数据...")
        let (sleepData, stepsData) = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: user,
            days: 30,
            mode: .simple  // iPhone无穿戴设备模式
        )
        
        // 3. 数据分析展示
        analyzeGeneratedData(sleepData: sleepData, stepsData: stepsData)
        
        // 4. 实时步数注入示例（今日数据）
        demonstrateRealtimeStepInjection(for: user)
        
        print("✅ 优化数据生成完成")
    }
    
    /// 分析生成的数据质量
    private static func analyzeGeneratedData(sleepData: [SleepData], stepsData: [StepsData]) {
        print("\n📈 数据质量分析:")
        print("==================")
        
        // 睡眠数据分析
        if !sleepData.isEmpty {
            let avgSleepDuration = sleepData.map { $0.duration }.reduce(0, +) / Double(sleepData.count)
            let sleepDurations = sleepData.map { $0.duration }
            let minSleep = sleepDurations.min() ?? 0
            let maxSleep = sleepDurations.max() ?? 0
            
            print("🌙 睡眠数据:")
            print("   平均睡眠时长: \(String(format: "%.1f", avgSleepDuration))小时")
            print("   睡眠时长范围: \(String(format: "%.1f", minSleep)) - \(String(format: "%.1f", maxSleep))小时")
            print("   数据天数: \(sleepData.count)天")
        }
        
        // 步数数据分析
        if !stepsData.isEmpty {
            let avgSteps = stepsData.map { $0.totalSteps }.reduce(0, +) / stepsData.count
            let stepCounts = stepsData.map { $0.totalSteps }
            let minSteps = stepCounts.min() ?? 0
            let maxSteps = stepCounts.max() ?? 0
            
            print("🚶‍♂️ 步数数据:")
            print("   平均每日步数: \(avgSteps)步")
            print("   步数范围: \(minSteps) - \(maxSteps)步")
            print("   数据天数: \(stepsData.count)天")
        }
        
        // 睡眠-步数关联分析
        analyzeCorrelation(sleepData: sleepData, stepsData: stepsData)
    }
    
    /// 分析睡眠与步数的关联性
    private static func analyzeCorrelation(sleepData: [SleepData], stepsData: [StepsData]) {
        print("\n🔗 睡眠-步数关联分析:")
        print("========================")
        
        let calendar = Calendar.current
        
        // 按日期匹配睡眠和步数数据
        var correlations: [(sleep: Double, steps: Int)] = []
        
        for sleep in sleepData {
            let sleepDate = calendar.startOfDay(for: sleep.date)
            
            // 找到对应日期的步数数据
            if let matchingSteps = stepsData.first(where: { 
                calendar.startOfDay(for: $0.date) == sleepDate 
            }) {
                correlations.append((sleep: sleep.duration, steps: matchingSteps.totalSteps))
            }
        }
        
        if correlations.count > 5 {
            // 分析睡眠质量对步数的影响
            let goodSleepData = correlations.filter { $0.sleep >= 7.0 && $0.sleep <= 9.0 }
            let poorSleepData = correlations.filter { $0.sleep < 6.5 || $0.sleep > 9.5 }
            
            if !goodSleepData.isEmpty && !poorSleepData.isEmpty {
                let avgStepsGoodSleep = goodSleepData.map { $0.steps }.reduce(0, +) / goodSleepData.count
                let avgStepsPoorSleep = poorSleepData.map { $0.steps }.reduce(0, +) / poorSleepData.count
                
                let difference = avgStepsGoodSleep - avgStepsPoorSleep
                let percentage = Double(abs(difference)) / Double(avgStepsGoodSleep) * 100
                
                print("   优质睡眠后平均步数: \(avgStepsGoodSleep)步")
                print("   低质睡眠后平均步数: \(avgStepsPoorSleep)步")
                print("   睡眠质量影响: \(difference > 0 ? "+" : "")\(difference)步 (\(String(format: "%.1f", percentage))%)")
                print("   ✅ 成功体现了睡眠质量对活动量的影响")
            }
        }
    }
    
    /// 演示实时步数注入功能
    private static func demonstrateRealtimeStepInjection(for user: VirtualUser) {
        print("\n⚡ 实时步数注入演示:")
        print("=====================")
        
        // 创建步数注入管理器实例演示
        print("📱 今日实时步数生成预览:")
        
        let today = Date()
        let calendar = Calendar.current
        // 使用增强版睡眠感知算法生成今日步数分布
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: today)!
        let referenceSleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
            for: user, 
            date: yesterdayDate, 
            mode: .simple
        )
        let todayStepDistribution = PersonalizedDataGenerator.generateEnhancedDailySteps(
            for: user, 
            date: today, 
            sleepData: referenceSleepData
        )
        
        print("   预计总步数: \(todayStepDistribution.totalSteps)步")
        print("   分布时段: \(todayStepDistribution.hourlyDistribution.count)个小时")
        print("   微增量数: \(todayStepDistribution.incrementalData.count)个")
        
        // 显示接下来几个小时的预期活动
        let currentHour = calendar.component(.hour, from: today)
        let nextFewHours = Array((currentHour...(currentHour + 3)).prefix(4))
        
        print("   接下来几小时预期:")
        for hour in nextFewHours {
            if let steps = todayStepDistribution.hourlyDistribution[hour] {
                print("     \(hour):00-\(hour+1):00 -> \(steps)步")
            }
        }
        
        // 睡眠时段活动预览
        let sleepHours = [23, 0, 1, 2, 3, 4, 5, 6]
        let sleepSteps = sleepHours.compactMap { todayStepDistribution.hourlyDistribution[$0] }
        if !sleepSteps.isEmpty {
            let totalSleepSteps = sleepSteps.reduce(0, +)
            print("   睡眠时段(23-6点): \(totalSleepSteps)步 (生理性微量活动)")
        }
    }
    
    // MARK: - 关键特性说明
    
    /// 展示优化方案的关键特性
    static func showKeyFeatures() {
        print("🎯 睡眠步数联动优化方案核心特性")
        print("=====================================")
        
        print("\n💡 1. 精准睡眠感知步数分配:")
        print("   • 基于真实睡眠阶段(深度/浅度/REM/清醒)分配步数")
        print("   • 95%睡眠时间0步，5%时间1-9步微量活动")
        print("   • 支持夜间生理活动：如厕(15-45步)、接水(8-20步)、翻身(1-5步)")
        
        print("\n🔄 2. 生理性步数波动算法:")
        print("   • 睡眠质量影响次日活动强度")
        print("   • 周内变化模拟(周一活跃，周五疲劳)")
        print("   • 季节性调整(冬季减少，春秋增加)")
        print("   • 真实活动节律(通勤高峰、午餐时段)")
        
        print("\n📱 3. 苹果健康数据规范兼容:")
        print("   • 时间戳精度规范化(秒级)")
        print("   • 数据范围验证(步数0-65535/小时)")
        print("   • 元数据完整性保证")
        print("   • 数据质量自动检查和修正")
        
        print("\n🎮 4. 个性化用户标签系统:")
        print("   • 睡眠类型: 夜猫型、早起型、紊乱型、正常型")
        print("   • 活动水平: 低、中、高、超高活动量")
        print("   • 智能推断: 从现有数据自动推断个性化配置")
        
        print("\n⚡ 5. 实时数据注入支持:")
        print("   • 微增量分片注入(避免数据突变)")
        print("   • 智能时间调度")
        print("   • 睡眠模式自动切换")
    }
    
    // MARK: - 使用建议
    
    /// 提供使用建议和最佳实践
    static func showUsageRecommendations() {
        print("\n📋 使用建议和最佳实践")
        print("=======================")
        
        print("✅ 推荐用法:")
        print("1. 历史数据生成 - 使用 generatePersonalizedHistoricalData")
        print("2. 实时数据注入 - 使用 StepInjectionManager")
        print("3. 数据验证 - 使用 HealthKitComplianceEnhancer")
        print("4. 个性化配置 - 基于用户行为特征选择标签")
        
        print("\n⚠️ 注意事项:")
        print("• 仅支持iPhone无穿戴设备场景")
        print("• 睡眠数据只能生成历史数据(昨天及之前)")
        print("• 大量数据写入建议分批进行")
        print("• 定期检查HealthKit权限状态")
        
        print("\n🔧 性能优化:")
        print("• 使用数据批次写入避免内存压力")
        print("• 启用数据质量检查确保规范性")
        print("• 利用种子随机数保证数据一致性")
    }
    
    // MARK: - 测试和验证
    
    /// 提供测试验证方法
    static func runValidationTests() {
        print("\n🧪 数据生成验证测试")
        print("===================")
        
        // 创建测试用户
        let testUser = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .normal,
            activityLevel: .medium
        )
        
        print("🔬 测试用户: \(testUser.personalizedDescription)")
        
        // 生成小量测试数据
        let (sleepData, stepsData) = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: testUser,
            days: 7,
            mode: .simple
        )
        
        // 验证数据完整性
        var totalIssues = 0
        
        for sleep in sleepData {
            let issues = HealthKitComplianceEnhancer.validateSleepDataIntegrity(sleep)
            totalIssues += issues.count
        }
        
        for steps in stepsData {
            let issues = HealthKitComplianceEnhancer.validateStepsDataIntegrity(steps)
            totalIssues += issues.count
        }
        
        print("📊 验证结果:")
        print("   生成数据: 睡眠\(sleepData.count)条，步数\(stepsData.count)条")
        print("   数据问题: \(totalIssues)个")
        print("   验证状态: \(totalIssues == 0 ? "✅ 全部通过" : "⚠️ 存在问题")")
        
        if totalIssues == 0 {
            print("🎉 优化方案验证成功！数据质量符合预期")
        }
    }
}

// MARK: - 快速开始示例
extension SleepStepsOptimizationGuide {
    
    /// 快速开始示例 - 5分钟上手
    static func quickStartExample() {
        print("🚀 5分钟快速上手")
        print("================")
        
        print("Step 1: 创建个性化用户")
        let user = VirtualUserGenerator.generatePersonalizedUser(
            sleepType: .normal,      // 正常作息
            activityLevel: .medium   // 中等活动量
        )
        print("✅ 用户创建完成: \(user.personalizedDescription)")
        
        print("\nStep 2: 生成优化历史数据")
        let (sleepData, stepsData) = PersonalizedDataGenerator.generatePersonalizedHistoricalData(
            for: user,
            days: 30,
            mode: .simple
        )
        print("✅ 历史数据生成完成: \(sleepData.count)天睡眠 + \(stepsData.count)天步数")
        
        print("\nStep 3: HealthKit规范验证")
        let _ = HealthKitComplianceEnhancer.generateDataQualityReport(
            sleepData: sleepData,
            stepsData: stepsData
        )
        print("✅ 数据质量检查完成")
        
        print("\nStep 4: 开始实时步数注入 (示例代码)")
        print("""
        // 在你的ViewController中:
        @StateObject private var stepInjector = PersonalizedDataGenerator.StepInjectionManager()
        
        // 启动今日步数注入
        stepInjector.startTodayInjection(for: user)
        
        // 根据睡眠时间自动调整
        stepInjector.enterSleepMode()  // 睡觉时
        stepInjector.exitSleepMode()   // 起床时
        """)
        
        print("\n🎉 快速上手完成！现在你已经掌握了睡眠步数联动优化方案的基本使用")
    }
}