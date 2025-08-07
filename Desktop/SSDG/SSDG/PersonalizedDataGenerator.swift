//
//  PersonalizedDataGenerator.swift
//  SSDG
//
//  Created by 谢铭麟 on 2025/7/12.
//

import Foundation

// MARK: - 个性化数据生成器
class PersonalizedDataGenerator {
    
    // MARK: - 增强的标签化数据生成函数
    
    // 增强的睡眠时间生成 - 更强烈的标签特征
    private static func generateEnhancedSleepTiming(for sleepType: SleepType, date: Date, using generator: inout SeededRandomGenerator) -> (bedtime: Date, wakeTime: Date) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let isFriday = weekday == 6
        
        // 标签特定的睡眠时间定义
        let (baseBedhour, baseWakehour): (Float, Float)
        switch sleepType {
        case .nightOwl:
            // 夜猫子：凌晨1-3点睡，上午10-12点醒
            baseBedhour = isWeekend ? 26.0 : 25.0  // 26 = 凌晨2点, 25 = 凌晨1点
            baseWakehour = isWeekend ? 11.0 : 10.0
        case .earlyBird:
            // 早起型：晚上9-10点睡，早上5-6点醒
            baseBedhour = isWeekend ? 22.0 : 21.0
            baseWakehour = isWeekend ? 6.0 : 5.0
        case .irregular:
            // 紊乱型：随机性更大
            let randomHour = generator.nextInt(in: 0...23)
            baseBedhour = Float(randomHour) + generator.nextFloat(in: 0...1)
            baseWakehour = baseBedhour + Float(generator.nextInt(in: 4...10))
        case .normal:
            // 正常型：晚上10-11点睡，早上6-7点醒
            baseBedhour = isWeekend ? 23.0 : 22.0
            baseWakehour = isWeekend ? 7.0 : 6.0
        }
        
        // 周五晚上特殊处理（所有类型都会晚睡一些）
        var adjustedBedhour = baseBedhour
        var adjustedWakehour = baseWakehour
        if isFriday && sleepType != .earlyBird {
            adjustedBedhour += generator.nextFloat(in: 0.5...1.5)
        }
        
        // 根据一致性添加变化 - 增加更大的时间变化范围
        let maxVariationHours: Float = 2.0 // 增加到2小时变化
        let consistencyFactor = sleepType.consistency
        let variationRange = (1.0 - consistencyFactor) * maxVariationHours
        
        // 添加生物钟周期性变化（模拟月度波动）
        let dayOfMonth = calendar.component(.day, from: date)
        let biorhythmFactor = Float(sin(Double(dayOfMonth) * .pi / 15) * 0.5) // ±0.5小时的周期性变化
        
        adjustedBedhour += generator.nextFloat(in: -variationRange...variationRange) + biorhythmFactor
        adjustedWakehour += generator.nextFloat(in: -variationRange...variationRange) + biorhythmFactor
        
        // 添加随机的"熬夜"事件（10%概率）
        if generator.nextFloat(in: 0...1) < 0.1 && sleepType != .earlyBird {
            adjustedBedhour += generator.nextFloat(in: 1...3) // 熬夜1-3小时
            adjustedWakehour += generator.nextFloat(in: 0.5...1.5) // 起床也相应推迟
        }
        
        // 添加"早起"事件（5%概率）
        if generator.nextFloat(in: 0...1) < 0.05 {
            adjustedWakehour -= generator.nextFloat(in: 1...2) // 早起1-2小时
        }
        
        // 生成实际时间
        var bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        // 处理睡眠时间
        if adjustedBedhour >= 24 {
            // 凌晨睡觉（如25.5 = 凌晨1:30）
            bedtimeComponents.hour = Int(adjustedBedhour) % 24
            bedtimeComponents.minute = Int((adjustedBedhour - Float(Int(adjustedBedhour))) * 60)
            // 注意：date 已经是"睡眠日期"，凌晨睡觉应该是在这一天的凌晨
        } else {
            // 晚上睡觉（如22.5 = 晚上10:30）
            bedtimeComponents.hour = Int(adjustedBedhour)
            bedtimeComponents.minute = Int((adjustedBedhour - Float(Int(adjustedBedhour))) * 60)
        }
        
        let bedtime = calendar.date(from: bedtimeComponents) ?? date
        
        // 计算起床时间
        let sleepDuration = adjustedWakehour > adjustedBedhour ? 
            (adjustedWakehour - adjustedBedhour) : 
            (24 - adjustedBedhour + adjustedWakehour)
        let wakeTime = bedtime.addingTimeInterval(TimeInterval(sleepDuration * 3600))
        
        return (bedtime: bedtime, wakeTime: wakeTime)
    }
    
    // 增强的睡眠时长生成 - 考虑活动水平的影响
    private static func generateEnhancedSleepDuration(for sleepType: SleepType, activityLevel: ActivityLevel, date: Date, using generator: inout SeededRandomGenerator) -> Double {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let isFriday = weekday == 6
        let dayOfMonth = calendar.component(.day, from: date)
        
        // 基础睡眠时长 - 增加更多变化
        var baseDuration: Double
        switch sleepType {
        case .nightOwl:
            // 夜猫子：通常睡得晚但睡眠时长正常
            baseDuration = isWeekend ? generator.nextDouble(in: 7.5...10.0) : generator.nextDouble(in: 6.0...8.0)
        case .earlyBird:
            // 早起型：睡眠规律且充足
            baseDuration = isWeekend ? generator.nextDouble(in: 7.0...8.5) : generator.nextDouble(in: 6.5...8.0)
        case .irregular:
            // 紊乱型：睡眠时长变化大，但极端情况较少
            let irregularRandom = generator.nextFloat(in: 0...1)
            if irregularRandom < 0.7 {
                // 70%：相对正常的睡眠时长
                baseDuration = generator.nextDouble(in: 5.5...9.0)
            } else if irregularRandom < 0.95 {
                // 25%：偏短或偏长
                baseDuration = generator.nextDouble(in: 4.0...11.0)
            } else {
                // 5%：极端情况（失眠或补觉）
                baseDuration = generator.nextDouble(in: 2.5...13.0)
            }
        case .normal:
            // 正常型：稳定的睡眠时长
            baseDuration = isWeekend ? generator.nextDouble(in: 7.0...9.0) : generator.nextDouble(in: 6.5...8.0)
        }
        
        // 周五效应（可能晚睡）
        if isFriday {
            baseDuration -= generator.nextDouble(in: 0...1.5)
        }
        
        // 活动水平对睡眠的影响
        switch activityLevel {
        case .low:
            // 低活动量可能睡眠质量差，时长不定
            baseDuration += generator.nextDouble(in: -1.0...0.5)
        case .medium:
            // 中等活动量，睡眠正常
            baseDuration += generator.nextDouble(in: -0.5...0.5)
        case .high:
            // 高活动量需要更多恢复时间
            baseDuration += generator.nextDouble(in: 0...1.0)
        case .veryHigh:
            // 超高活动量需要充足睡眠
            baseDuration += generator.nextDouble(in: 0.5...1.5)
        }
        
        // 添加生物钟周期性变化（模拟月度波动）
        let biorhythmFactor = sin(Double(dayOfMonth) * .pi / 15) * 0.5
        baseDuration += biorhythmFactor
        
        // 添加偶尔的极端情况（根据睡眠类型调整概率）
        let extremeProbability: Float
        switch sleepType {
        case .irregular:
            extremeProbability = 0.08  // 8%概率出现极端情况
        case .nightOwl:
            extremeProbability = 0.03  // 3%概率
        case .normal:
            extremeProbability = 0.02  // 2%概率
        case .earlyBird:
            extremeProbability = 0.01  // 1%概率（早起型最规律）
        }
        
        if generator.nextFloat(in: 0...1) < extremeProbability {
            let extremeType = generator.nextFloat(in: 0...1)
            if extremeType < 0.6 {
                // 60%概率：睡眠不足
                baseDuration = generator.nextDouble(in: 3.5...5.0)
            } else {
                // 40%概率：补觉
                baseDuration = generator.nextDouble(in: 9.5...11.5)
            }
        }
        
        // 确保在合理范围内
        return max(3.0, min(14.0, baseDuration))
    }
    
    // 增强的简单睡眠生成 - 更贴合标签特征
    private static func generateEnhancedSimpleSleep(
        bedtime: Date,
        wakeTime: Date,
        totalDuration: Double,
        sleepType: SleepType,
        generator: inout SeededRandomGenerator
    ) -> SleepData {
        let calendar = Calendar.current
        var stages: [SleepStage] = []
        
        // 生成睡前手机使用记录（模拟真实用户行为）
        let phoneUsageChance = generator.nextFloat(in: 0...1)
        var actualBedtime = bedtime
        
        // 根据睡眠类型决定睡前手机使用概率
        let usageProbability: Float
        let minUsageCount: Int
        let maxUsageCount: Int
        
        switch sleepType {
        case .nightOwl:
            usageProbability = 0.7  // 70%概率有睡前手机使用
            minUsageCount = 1
            maxUsageCount = 3  // 减少到1-3次
        case .irregular:
            usageProbability = 0.6  // 60%概率
            minUsageCount = 1
            maxUsageCount = 2  // 减少到1-2次
        case .normal:
            usageProbability = 0.5  // 50%概率
            minUsageCount = 1
            maxUsageCount = 2  // 减少到1-2次
        case .earlyBird:
            usageProbability = 0.3  // 30%概率（早起型通常很快入睡）
            minUsageCount = 1
            maxUsageCount = 1  // 最多1次
        }
        
        if phoneUsageChance < usageProbability {
            // 生成睡前手机使用时段（简化版）
            let usageCount = generator.nextInt(in: minUsageCount...maxUsageCount)
            let preSleepTime = bedtime.addingTimeInterval(-1800) // 从睡前30分钟开始
            
            for i in 0..<usageCount {
                // 手机使用时间（1-5分钟）
                let usageDuration = generator.nextDouble(in: 60...300)
                let startTime = preSleepTime.addingTimeInterval(Double(i * 600)) // 每10分钟一次
                let endTime = startTime.addingTimeInterval(usageDuration)
                
                // 确保不超过预定睡觉时间
                if endTime > bedtime {
                    break
                }
                
                // 创建清醒时段
                let stage = SleepStage(
                    stage: .awake,
                    startTime: startTime,
                    endTime: endTime
                )
                stages.append(stage)
            }
            
            // 实际入睡时间就是计划的入睡时间
            actualBedtime = bedtime
        }
        
        // 计算实际睡眠时长
        let actualSleepDuration = wakeTime.timeIntervalSince(actualBedtime)
        
        // 只在极端情况下调整睡眠时间
        // 根据睡眠类型决定最小睡眠时长
        let minSleepDuration: TimeInterval
        switch sleepType {
        case .irregular:
            minSleepDuration = 3600 * 2.5  // 紊乱型：最少2.5小时
        case .nightOwl:
            minSleepDuration = 3600 * 4    // 夜猫子：最少4小时
        case .earlyBird:
            minSleepDuration = 3600 * 5    // 早起型：最少5小时
        case .normal:
            minSleepDuration = 3600 * 4.5  // 正常型：最少4.5小时
        }
        
        // 只有在睡眠时间极短且不符合类型特征时才调整
        if actualSleepDuration < minSleepDuration {
            // 根据睡眠类型决定是否接受极短睡眠
            let acceptShortSleep = generator.nextFloat(in: 0...1)
            
            // 紊乱型有20%概率接受极短睡眠（如失眠夜）
            if sleepType == .irregular && acceptShortSleep < 0.2 {
                // 接受这次极短睡眠，继续生成
            } else {
                // 其他情况调整起床时间以确保合理睡眠时长
                let adjustedDuration = max(minSleepDuration / 3600, totalDuration * 0.8)
                let newWakeTime = actualBedtime.addingTimeInterval(adjustedDuration * 3600)
                return generateEnhancedSimpleSleep(
                    bedtime: bedtime,
                    wakeTime: newWakeTime,
                    totalDuration: adjustedDuration,
                    sleepType: sleepType,
                    generator: &generator
                )
            }
        }
        
        // 根据睡眠类型决定分段策略
        let segmentCount: Int
        let randomValue = generator.nextFloat(in: 0...1)
        
        switch sleepType {
        case .nightOwl:
            // 夜猫子：70%一段，20%两段，10%三段
            if randomValue < 0.7 {
                segmentCount = 1
            } else if randomValue < 0.9 {
                segmentCount = 2
            } else {
                segmentCount = 3
            }
        case .earlyBird:
            // 早起者：50%一段，35%两段，15%三段
            if randomValue < 0.5 {
                segmentCount = 1
            } else if randomValue < 0.85 {
                segmentCount = 2
            } else {
                segmentCount = 3
            }
        case .irregular:
            // 紊乱型：20%一段，40%两段，30%三段，10%四段
            if randomValue < 0.2 {
                segmentCount = 1
            } else if randomValue < 0.6 {
                segmentCount = 2
            } else if randomValue < 0.9 {
                segmentCount = 3
            } else {
                segmentCount = 4
            }
        case .normal:
            // 正常型：40%一段，40%两段，20%三段
            if randomValue < 0.4 {
                segmentCount = 1
            } else if randomValue < 0.8 {
                segmentCount = 2
            } else {
                segmentCount = 3
            }
        }
        
        // 生成睡眠段落
        var currentTime = actualBedtime  // 使用实际入睡时间
        var allocatedTime: TimeInterval = 0
        let totalSeconds = actualSleepDuration  // 使用实际睡眠时长
        
        for i in 0..<segmentCount {
            let isLastSegment = i == segmentCount - 1
            
            // 计算段落时长
            let remainingTime = totalSeconds - allocatedTime
            let segmentRatio = isLastSegment ? 1.0 : generator.nextDouble(in: 0.3...0.7)
            let segmentDuration = remainingTime * segmentRatio
            
            let segmentEnd = currentTime.addingTimeInterval(segmentDuration)
            
            stages.append(SleepStage(
                stage: .light,
                startTime: currentTime,
                endTime: min(segmentEnd, wakeTime)
            ))
            
            allocatedTime += segmentDuration
            
            // 添加中断（如果不是最后一段）
            if !isLastSegment {
                // 生成更真实的中断时长
                let interruptionType = generator.nextFloat(in: 0...1)
                let gapDuration: TimeInterval
                
                switch sleepType {
                case .irregular:
                    // 紊乱型：中断模式多变
                    if interruptionType < 0.5 {
                        // 50%: 非常短暂（0-3分钟）
                        gapDuration = generator.nextDouble(in: 0...180)
                    } else if interruptionType < 0.75 {
                        // 25%: 短暂中断（3-8分钟）
                        gapDuration = generator.nextDouble(in: 180...480)
                    } else if interruptionType < 0.9 {
                        // 15%: 中等中断（8-20分钟）
                        gapDuration = generator.nextDouble(in: 480...1200)
                    } else {
                        // 10%: 长时间醒来（20-40分钟）
                        gapDuration = generator.nextDouble(in: 1200...2400)
                    }
                case .nightOwl:
                    // 夜猫子：中断较少且通常很短
                    if interruptionType < 0.7 {
                        // 70%: 非常短暂（0-2分钟）
                        gapDuration = generator.nextDouble(in: 0...120)
                    } else if interruptionType < 0.95 {
                        // 25%: 短暂中断（2-5分钟）
                        gapDuration = generator.nextDouble(in: 120...300)
                    } else {
                        // 5%: 稍长中断（5-10分钟）
                        gapDuration = generator.nextDouble(in: 300...600)
                    }
                case .earlyBird:
                    // 早起者：规律的短暂中断
                    if interruptionType < 0.6 {
                        // 60%: 非常短暂（0-2分钟）
                        gapDuration = generator.nextDouble(in: 0...120)
                    } else if interruptionType < 0.9 {
                        // 30%: 短暂中断（2-5分钟）
                        gapDuration = generator.nextDouble(in: 120...300)
                    } else {
                        // 10%: 稍长中断（5-8分钟）
                        gapDuration = generator.nextDouble(in: 300...480)
                    }
                case .normal:
                    // 正常型：大多数是短暂中断
                    if interruptionType < 0.6 {
                        // 60%: 非常短暂（0-2分钟）
                        gapDuration = generator.nextDouble(in: 0...120)
                    } else if interruptionType < 0.85 {
                        // 25%: 短暂中断（2-5分钟）
                        gapDuration = generator.nextDouble(in: 120...300)
                    } else if interruptionType < 0.95 {
                        // 10%: 中等中断（5-10分钟）
                        gapDuration = generator.nextDouble(in: 300...600)
                    } else {
                        // 5%: 较长中断（10-20分钟）
                        gapDuration = generator.nextDouble(in: 600...1200)
                    }
                }
                currentTime = segmentEnd.addingTimeInterval(gapDuration)
            }
        }
        
        // 在睡眠段落中添加额外的短暂醒来（模拟真实的睡眠中断）
        var finalStages = stages
        
        // 根据睡眠类型决定额外醒来的次数（大幅减少）
        let extraAwakenings: Int
        switch sleepType {
        case .irregular:
            extraAwakenings = generator.nextInt(in: 1...2)  // 减少到1-2次
        case .normal:
            extraAwakenings = generator.nextInt(in: 0...1)  // 减少到0-1次
        case .nightOwl:
            extraAwakenings = generator.nextInt(in: 0...1)  // 减少到0-1次
        case .earlyBird:
            extraAwakenings = 0  // 早起型睡眠质量好，不额外醒来
        }
        
        // 在睡眠期间随机添加短暂醒来
        for _ in 0..<extraAwakenings {
            // 随机选择一个时间点
            let totalSleepDuration = wakeTime.timeIntervalSince(actualBedtime)
            let awakeOffset = generator.nextDouble(in: totalSleepDuration * 0.2...totalSleepDuration * 0.8)
            let awakeTime = actualBedtime.addingTimeInterval(awakeOffset)
            
            // 生成醒来时长
            let awakeDuration: TimeInterval
            let durationRandom = generator.nextFloat(in: 0...1)
            if durationRandom < 0.5 {
                // 50%: 0分钟（瞬间醒来）
                awakeDuration = 0
            } else if durationRandom < 0.8 {
                // 30%: 0-2分钟
                awakeDuration = generator.nextDouble(in: 0...120)
            } else if durationRandom < 0.95 {
                // 15%: 2-5分钟
                awakeDuration = generator.nextDouble(in: 120...300)
            } else {
                // 5%: 5-10分钟
                awakeDuration = generator.nextDouble(in: 300...600)
            }
            
            let awakeStage = SleepStage(
                stage: .awake,
                startTime: awakeTime,
                endTime: awakeTime.addingTimeInterval(awakeDuration)
            )
            finalStages.append(awakeStage)
        }
        
        // 按时间排序
        finalStages.sort { $0.startTime < $1.startTime }
        
        // 🔥 修复：去重和合并重叠的睡眠段
        finalStages = removeDuplicateAndMergeOverlappingStages(finalStages)
        
        let baseData = SleepData(
            date: calendar.startOfDay(for: bedtime),  // 使用睡眠开始日期，而非起床日期
            bedTime: bedtime,
            wakeTime: wakeTime,
            sleepStages: finalStages
        )
        
        // 处理特殊睡眠情况
        return handleSpecialSleepConditions(
            baseData: baseData,
            sleepType: sleepType,
            date: calendar.startOfDay(for: bedtime),
            generator: &generator
        )
    }
    
    // 处理特殊睡眠情况（失眠、午睡、分段睡眠等）
    private static func handleSpecialSleepConditions(
        baseData: SleepData,
        sleepType: SleepType,
        date: Date,
        generator: inout SeededRandomGenerator
    ) -> SleepData {
        let calendar = Calendar.current
        let specialEventChance = generator.nextFloat(in: 0...1)
        
        // 根据睡眠类型调整失眠概率
        let insomniaChance: Float
        switch sleepType {
        case .irregular:
            insomniaChance = 0.02  // 2%概率
        case .normal:
            insomniaChance = 0.005 // 0.5%概率
        case .nightOwl:
            insomniaChance = 0.01  // 1%概率
        case .earlyBird:
            insomniaChance = 0.003 // 0.3%概率（早起型很少失眠）
        }
        
        // 失眠情况（但不是完全未睡）
        if specialEventChance < insomniaChance {
            // 创建多个短暂的"尝试入睡"片段
            var insomniaStages: [SleepStage] = []
            let attemptCount = generator.nextInt(in: 3...6)
            var currentTime = baseData.bedTime
            
            for _ in 0..<attemptCount {
                // 失眠时的睡眠尝试通常是断断续续的
                let attemptDuration = generator.nextDouble(in: 600...3600) // 10-60分钟
                let endTime = currentTime.addingTimeInterval(attemptDuration)
                
                if endTime < baseData.wakeTime {
                    insomniaStages.append(SleepStage(
                        stage: .light,
                        startTime: currentTime,
                        endTime: endTime
                    ))
                }
                
                // 添加清醒时间（失眠时的清醒间隔通常较长）
                let awakeDuration = generator.nextDouble(in: 900...2700) // 15-45分钟
                currentTime = endTime.addingTimeInterval(awakeDuration)
                
                if currentTime >= baseData.wakeTime {
                    break
                }
            }
            
            return SleepData(
                date: baseData.date,
                bedTime: baseData.bedTime,
                wakeTime: baseData.wakeTime,
                sleepStages: insomniaStages
            )
        }
        
        // 5%概率：午睡（仅适用于正常和不规律类型）
        if specialEventChance < 0.08 && (sleepType == .normal || sleepType == .irregular) {
            // 添加午睡段
            var stagesWithNap = baseData.sleepStages
            
            // 生成午睡时间（13:00-16:00之间）
            var napComponents = calendar.dateComponents([.year, .month, .day], from: date)
            napComponents.hour = generator.nextInt(in: 13...15)
            napComponents.minute = generator.nextInt(in: 0...45)
            
            if let napStart = calendar.date(from: napComponents) {
                let napDuration = generator.nextDouble(in: 1200...5400) // 20-90分钟
                let napEnd = napStart.addingTimeInterval(napDuration)
                
                stagesWithNap.append(SleepStage(
                    stage: .light,
                    startTime: napStart,
                    endTime: napEnd
                ))
                
                // 按时间排序
                stagesWithNap.sort { $0.startTime < $1.startTime }
            }
            
            return SleepData(
                date: baseData.date,
                bedTime: baseData.bedTime,
                wakeTime: baseData.wakeTime,
                sleepStages: stagesWithNap
            )
        }
        
        // 默认返回原数据
        return baseData
    }
    
    // MARK: - 睡眠感知的步数调整
    
    // 根据睡眠数据调整步数分布
    private static func adjustStepsForSleep(distribution: DailyStepDistribution, sleepData: SleepData) -> DailyStepDistribution {
        var adjustedHourlyDistribution = distribution.hourlyDistribution
        var adjustedIncrementalData = distribution.incrementalData
        let calendar = Calendar.current
        
        // 获取所有睡眠时段
        var sleepPeriods: [(start: Date, end: Date)] = []
        for stage in sleepData.sleepStages {
            sleepPeriods.append((start: stage.startTime, end: stage.endTime))
        }
        
        // 调整每小时的步数
        for hour in 0..<24 {
            var hourComponents = calendar.dateComponents([.year, .month, .day], from: distribution.date)
            hourComponents.hour = hour
            guard let hourStart = calendar.date(from: hourComponents) else { continue }
            let hourEnd = hourStart.addingTimeInterval(3600)
            
            // 检查这个小时是否与睡眠时段重叠
            var sleepOverlapRatio: Double = 0.0
            for period in sleepPeriods {
                let overlapStart = max(hourStart, period.start)
                let overlapEnd = min(hourEnd, period.end)
                
                if overlapStart < overlapEnd {
                    let overlapDuration = overlapEnd.timeIntervalSince(overlapStart)
                    sleepOverlapRatio += overlapDuration / 3600.0
                }
            }
            
            // 根据睡眠重叠比例调整步数
            if sleepOverlapRatio > 0 {
                let currentSteps = adjustedHourlyDistribution[hour] ?? 0
                if sleepOverlapRatio >= 0.9 {
                    // 几乎整个小时都在睡觉，步数设为0-5
                    adjustedHourlyDistribution[hour] = Int.random(in: 0...5)
                } else if sleepOverlapRatio >= 0.5 {
                    // 超过一半时间在睡觉，大幅减少步数
                    adjustedHourlyDistribution[hour] = Int(Double(currentSteps) * (1 - sleepOverlapRatio) * 0.3)
                } else {
                    // 部分时间睡觉，适度减少
                    adjustedHourlyDistribution[hour] = Int(Double(currentSteps) * (1 - sleepOverlapRatio * 0.8))
                }
            }
        }
        
        // 调整增量数据
        adjustedIncrementalData = adjustedIncrementalData.filter { increment in
            // 移除睡眠时段内的大部分步数增量
            for period in sleepPeriods {
                if increment.timestamp >= period.start && increment.timestamp < period.end {
                    // 95%概率移除睡眠时段内的活动
                    return Double.random(in: 0...1) < 0.05
                }
            }
            return true
        }
        
        // 在醒来后添加一些起床活动
        for period in sleepPeriods {
            let wakeTime = period.end
            // 醒来后30分钟内添加一些步数
            for i in 0..<3 {
                let minutesAfterWake = i * 10 + Int.random(in: 0...5)
                let activityTime = wakeTime.addingTimeInterval(Double(minutesAfterWake * 60))
                
                // 添加起床活动：20-50步
                adjustedIncrementalData.append(StepIncrement(
                    timestamp: activityTime,
                    steps: Int.random(in: 20...50),
                    activityType: .walking
                ))
            }
        }
        
        // 重新计算总步数
        let newTotalSteps = adjustedHourlyDistribution.values.reduce(0, +)
        
        return DailyStepDistribution(
            date: distribution.date,
            totalSteps: newTotalSteps,
            hourlyDistribution: adjustedHourlyDistribution,
            incrementalData: adjustedIncrementalData.sorted { $0.timestamp < $1.timestamp }
        )
    }
    
    // MARK: - 每日数据生成
    
    // 生成个性化每日数据
    static func generatePersonalizedDailyData(
        for user: VirtualUser,
        date: Date,
        recentSleepData: [SleepData],
        recentStepsData: [StepsData],
        mode: DataMode = .simple
    ) -> (sleepData: SleepData?, stepsData: StepsData) {
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let requestDate = calendar.startOfDay(for: date)
        
        var sleepData: SleepData? = nil
        
        // 生成睡眠数据：睡眠数据记录在睡眠开始的日期
        // 例如：8月6日晚上11点睡觉到第二天早上7点，记录在“8月6日”
        // 但今天的睡眠要等到今晚才会生成，所以只生成昨天及之前的
        if requestDate < today {
            sleepData = generatePersonalizedSleepData(for: user, date: date, mode: mode)
        }
        
        // 生成步数数据：只为今天或过去的日期生成
        let stepsData: StepsData
        if requestDate <= today {
            // 🔥 关键修复：对于今天的步数，需要使用昨晚的睡眠数据
            var effectiveSleepData: SleepData
            
            if let sleepData = sleepData {
                // 有当天的睡眠数据（过去的日期）
                effectiveSleepData = sleepData
            } else if requestDate == today {
                // 今天：查找昨晚的睡眠数据（睡眠跨越到今天）
                let yesterday = calendar.date(byAdding: .day, value: -1, to: requestDate)!
                
                // 从最近的睡眠数据中查找昨天的记录
                if let yesterdaySleep = recentSleepData.first(where: { 
                    calendar.isDate($0.date, inSameDayAs: yesterday) 
                }) {
                    // 使用昨晚的睡眠数据
                    effectiveSleepData = yesterdaySleep
                    print("📊 今天的步数生成使用昨晚的睡眠数据：")
                    print("   睡眠时段: \(yesterdaySleep.bedTime) - \(yesterdaySleep.wakeTime)")
                } else {
                    // 没有找到昨晚的睡眠数据，使用默认值
                    effectiveSleepData = SleepData(
                        date: yesterday,
                        bedTime: calendar.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday)!,
                        wakeTime: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: requestDate)!,
                        sleepStages: []
                    )
                    print("⚠️ 未找到昨晚的睡眠数据，使用默认睡眠时段")
                }
            } else {
                // 其他情况：使用空的睡眠数据
                effectiveSleepData = SleepData(
                    date: date,
                    bedTime: date,
                    wakeTime: date,
                    sleepStages: []
                )
            }
            
            stepsData = generateContinuousPersonalizedSteps(
                for: user,
                date: date,
                sleepData: effectiveSleepData,
                recentSteps: recentStepsData.map { $0.totalSteps }
            )
        } else {
            // 未来日期返回空数据
            stepsData = StepsData(date: date, hourlySteps: [])
        }
        
        return (sleepData: sleepData, stepsData: stepsData)
    }
    
    // MARK: - 辅助函数
    
    // 从字符串生成种子（改进版，确保更多变化）
    private static func generateSeed(from string: String) -> Int {
        // 使用多重哈希确保更好的分布
        let hash1 = abs(string.hashValue)
        let hash2 = abs(String(string.reversed()).hashValue)
        let combinedHash = hash1 ^ (hash2 << 16)
        return abs(combinedHash) % 1000000  // 扩大种子范围
    }
    
    /// 去重和合并重叠的睡眠段
    private static func removeDuplicateAndMergeOverlappingStages(_ stages: [SleepStage]) -> [SleepStage] {
        guard !stages.isEmpty else { return stages }
        
        // 先按开始时间排序
        let sortedStages = stages.sorted { $0.startTime < $1.startTime }
        var mergedStages: [SleepStage] = []
        
        // 遍历所有段落
        for stage in sortedStages {
            // 如果是第一个段落，直接添加
            if mergedStages.isEmpty {
                mergedStages.append(stage)
                continue
            }
            
            // 获取最后一个已合并的段落
            let lastStage = mergedStages[mergedStages.count - 1]
            
            // 检查是否有重叠或相邻（1分钟内）
            if stage.startTime <= lastStage.endTime.addingTimeInterval(60) {
                // 有重叠或相邻，需要合并
                // 如果是相同类型的睡眠阶段，合并
                if stage.stage == lastStage.stage {
                    // 更新结束时间为两者中较晚的时间
                    let mergedEndTime = max(lastStage.endTime, stage.endTime)
                    mergedStages[mergedStages.count - 1] = SleepStage(
                        stage: lastStage.stage,
                        startTime: lastStage.startTime,
                        endTime: mergedEndTime
                    )
                } else {
                    // 不同类型的睡眠阶段，检查是否完全重复
                    // 如果新段落完全在上一个段落内，跳过
                    if stage.endTime <= lastStage.endTime {
                        continue
                    }
                    // 否则调整新段落的开始时间，避免重叠
                    let adjustedStage = SleepStage(
                        stage: stage.stage,
                        startTime: lastStage.endTime,
                        endTime: stage.endTime
                    )
                    // 只有当调整后的段落有效时才添加
                    if adjustedStage.duration > 0 {
                        mergedStages.append(adjustedStage)
                    }
                }
            } else {
                // 没有重叠，直接添加
                mergedStages.append(stage)
            }
        }
        
        // 最后再次过滤，确保没有时长为0的段落
        return mergedStages.filter { $0.duration > 0 }
    }
    
    // MARK: - 睡眠数据生成
    
    // 生成个性化睡眠数据（严格时间边界控制）
    static func generatePersonalizedSleepData(for user: VirtualUser, date: Date, mode: DataMode = .simple) -> SleepData {
        _ = Calendar.current
        let profile = PersonalizedProfile.inferFromUser(user)
        
        // 改进种子生成
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let seedInput = user.id + dateString + String(dayOfYear) + "sleep"
        let seed = generateSeed(from: seedInput)
        var generator = SeededRandomGenerator(seed: UInt64(abs(seed)))
        
        // 基于睡眠类型生成睡眠时间，增强标签影响
        let sleepTiming = generateEnhancedSleepTiming(for: profile.sleepType, date: date, using: &generator)
        let sleepDuration = generateEnhancedSleepDuration(for: profile.sleepType, activityLevel: profile.activityLevel, date: date, using: &generator)
        
        // 生成睡眠阶段数据
        if mode == .wearableDevice {
            return generateComprehensiveSleep(
                bedtime: sleepTiming.bedtime,
                wakeTime: sleepTiming.wakeTime,
                totalDuration: sleepDuration,
                consistency: profile.sleepType.consistency,
                generator: &generator
            )
        } else {
            // 使用改进的分段睡眠生成
            return generateEnhancedSimpleSleep(
                bedtime: sleepTiming.bedtime,
                wakeTime: sleepTiming.wakeTime,
                totalDuration: sleepDuration,
                sleepType: profile.sleepType,
                generator: &generator
            )
        }
    }
    
    // MARK: - 步数数据生成（预计算+分片注入）
    
    // 生成个性化每日步数分布
    static func generatePersonalizedDailySteps(for user: VirtualUser, date: Date) -> DailyStepDistribution {
        let profile = PersonalizedProfile.inferFromUser(user)
        
        // 🔧 改进种子生成：使用更多变化因子
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let seedInput = user.id + dateString + String(dayOfYear) + "steps"
        let seed = generateSeed(from: seedInput)
        
        print("🚶‍♂️ 个性化步数生成 - \(profile.activityLevel.displayName)")
        
        let distribution = DailyStepDistribution.generate(for: profile, date: date, seed: UInt64(abs(seed)))
        
        print("   目标步数: \(distribution.totalSteps)")
        print("   活跃时段: \(distribution.hourlyDistribution.count)小时")
        print("   微增量数据点: \(distribution.incrementalData.count)个")
        
        // 显示时间段分布概况
        let calendar = Calendar.current
        let isWeekend = calendar.component(.weekday, from: date) == 1 || calendar.component(.weekday, from: date) == 7
        print("   作息模式: \(isWeekend ? "周末" : "工作日")")
        
        // 显示主要活跃时段
        let sortedHours = distribution.hourlyDistribution.sorted { $0.value > $1.value }
        let topHours = sortedHours.prefix(3)
        let topHoursStr = topHours.map { "\($0.key):00(\($0.value)步)" }.joined(separator: ", ")
        print("   主要活跃: \(topHoursStr)")
        
        return distribution
    }
    
    // 转换为HealthKit兼容的小时聚合数据
    static func convertToHourlySteps(from distribution: DailyStepDistribution) -> [StepsData] {
        var hourlySteps: [HourlySteps] = []
        let calendar = Calendar.current
        
        for (hour, steps) in distribution.hourlyDistribution.sorted(by: { $0.key < $1.key }) {
            var components = calendar.dateComponents([.year, .month, .day], from: distribution.date)
            components.hour = hour
            components.minute = 0
            components.second = 0
            
            if let hourStartDate = calendar.date(from: components) {
                let hourEndDate = calendar.date(byAdding: .hour, value: 1, to: hourStartDate) ?? hourStartDate
                let hourlyStep = HourlySteps(
                    hour: hour,
                    steps: steps,
                    startTime: hourStartDate,
                    endTime: hourEndDate
                )
                hourlySteps.append(hourlyStep)
            }
        }
        
        return [StepsData(date: distribution.date, hourlySteps: hourlySteps)]
    }
    
    // MARK: - 历史数据生成
    
    // 生成个性化历史数据 - 增强版
    static func generatePersonalizedHistoricalData(
        for user: VirtualUser,
        days: Int,
        mode: DataMode = .simple
    ) -> (sleepData: [SleepData], stepsData: [StepsData]) {
        
        var allSleepData: [SleepData] = []
        var allStepsData: [StepsData] = []
        
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)
        
        // 使用批处理优化大量数据生成
        let batchSize = 30 // 每批处理30天
        let totalBatches = (days + batchSize - 1) / batchSize
        
        // 维护睡眠债务和活动趋势以增强连续性
        var sleepDebtAccumulator: Double = 0.0
        var recentSleepHours: [Double] = []
        var recentSteps: [Int] = []
        
        for batch in 0..<totalBatches {
            autoreleasepool {
                // 修改起始点，从0开始以包含"昨晚"的睡眠（记录在昨天）
                let startDay = batch * batchSize
                let endDay = min((batch + 1) * batchSize, days) - 1
                
                for dayOffset in (startDay...endDay).reversed() {
                    guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else { continue }
                    
                    // 跳过今天（不生成今晚的睡眠数据）
                    if calendar.isDate(date, inSameDayAs: today) {
                        continue
                    }
                    
                    // 生成具有连续性的睡眠数据
                    let sleepData = generateContinuousPersonalizedSleepData(
                        for: user,
                        date: date,
                        sleepDebt: sleepDebtAccumulator,
                        recentSleepHours: recentSleepHours,
                        mode: mode
                    )
                    
                    // 🔥 修复：检查是否已存在相同日期的睡眠数据，避免重复
                    let existingIndex = allSleepData.firstIndex { existingSleep in
                        calendar.isDate(existingSleep.date, inSameDayAs: sleepData.date)
                    }
                    
                    if let index = existingIndex {
                        // 替换已存在的数据
                        allSleepData[index] = sleepData
                    } else {
                        // 添加新数据
                        allSleepData.append(sleepData)
                    }
                    
                    // 更新睡眠债务和历史记录
                    let actualSleep = sleepData.duration
                    sleepDebtAccumulator += (user.sleepBaseline - actualSleep)
                    sleepDebtAccumulator = max(-5, min(5, sleepDebtAccumulator)) // 限制债务范围
                    
                    recentSleepHours.append(actualSleep)
                    if recentSleepHours.count > 7 {
                        recentSleepHours.removeFirst()
                    }
                    
                    // 生成具有连续性的步数数据
                    // 只为今天或过去的日期生成步数
                    if calendar.compare(date, to: today, toGranularity: .day) != .orderedDescending {
                        // 🔥 关键修复：考虑跨天睡眠 - 今天的步数需要知道昨晚的睡眠时段
                        var effectiveSleepData = sleepData
                        
                        // 检查是否需要前一天的睡眠数据（当睡眠跨越到当天）
                        if dayOffset > 0 && allSleepData.count > 0 {
                            let previousSleep = allSleepData[allSleepData.count - 1]
                            // 如果前一天的睡眠结束时间在当天，使用前一天的睡眠数据
                            if calendar.isDate(previousSleep.wakeTime, inSameDayAs: date) {
                                effectiveSleepData = previousSleep
                                print("📊 使用前一天的睡眠数据生成 \(date) 的步数")
                            }
                        }
                        
                        let dailySteps = generateContinuousPersonalizedSteps(
                            for: user,
                            date: date,
                            sleepData: effectiveSleepData,
                            recentSteps: recentSteps
                        )
                        allStepsData.append(dailySteps)
                        
                        // 更新步数历史
                        recentSteps.append(dailySteps.totalSteps)
                        if recentSteps.count > 7 {
                            recentSteps.removeFirst()
                        }
                    }
                }
            }
        }
        
        return (sleepData: allSleepData, stepsData: allStepsData)
    }
    
    // 生成具有连续性的个性化睡眠数据
    private static func generateContinuousPersonalizedSleepData(
        for user: VirtualUser,
        date: Date,
        sleepDebt: Double,
        recentSleepHours: [Double],
        mode: DataMode
    ) -> SleepData {
        let profile = PersonalizedProfile.inferFromUser(user)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        
        // 改进种子生成
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let seedInput = user.id + dateString + "sleep-continuous"
        let seed = generateSeed(from: seedInput)
        var generator = SeededRandomGenerator(seed: UInt64(abs(seed)))
        
        // 基础睡眠时长
        var sleepDuration = generateEnhancedSleepDuration(for: profile.sleepType, activityLevel: profile.activityLevel, date: date, using: &generator)
        
        // 睡眠债务补偿
        if sleepDebt > 1.0 {
            // 有睡眠债务，增加睡眠时间
            let compensation = min(sleepDebt * 0.3, 1.5) // 最多补偿1.5小时
            if isWeekend {
                sleepDuration += compensation * generator.nextDouble(in: 0.8...1.2)
            } else {
                sleepDuration += compensation * generator.nextDouble(in: 0.2...0.5)
            }
        } else if sleepDebt < -1.0 {
            // 睡眠过多，稍微减少
            sleepDuration -= abs(sleepDebt) * 0.1
        }
        
        // 确保在合理范围内
        sleepDuration = max(4, min(12, sleepDuration))
        
        // 生成睡眠时间
        let sleepTiming = generateEnhancedSleepTiming(for: profile.sleepType, date: date, using: &generator)
        
        // 生成睡眠阶段数据
        if mode == .wearableDevice {
            return generateComprehensiveSleep(
                bedtime: sleepTiming.bedtime,
                wakeTime: sleepTiming.wakeTime,
                totalDuration: sleepDuration,
                consistency: profile.sleepType.consistency,
                generator: &generator
            )
        } else {
            // 使用增强版生成方法
            return generateEnhancedSimpleSleep(
                bedtime: sleepTiming.bedtime,
                wakeTime: sleepTiming.wakeTime,
                totalDuration: sleepDuration,
                sleepType: profile.sleepType,
                generator: &generator
            )
        }
    }
    
    // 生成具有连续性的个性化步数数据
    private static func generateContinuousPersonalizedSteps(
        for user: VirtualUser,
        date: Date,
        sleepData: SleepData,
        recentSteps: [Int]
    ) -> StepsData {
        let profile = PersonalizedProfile.inferFromUser(user)
        let calendar = Calendar.current
        _ = calendar.component(.weekday, from: date) == 1 || calendar.component(.weekday, from: date) == 7
        
        // 生成步数分布 - 使用睡眠感知算法
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let seedInput = user.id + dateString + "steps-continuous"
        let seed = generateSeed(from: seedInput)
        var generator = SeededRandomGenerator(seed: UInt64(abs(seed)))
        
        // 计算基础步数
        let baseSteps: Int
        switch profile.activityLevel {
        case .low: baseSteps = generator.nextInt(in: 1500...4500)
        case .medium: baseSteps = generator.nextInt(in: 4500...8500)
        case .high: baseSteps = generator.nextInt(in: 8500...13000)
        case .veryHigh: baseSteps = generator.nextInt(in: 13000...18000)
        }
        
        // 基于睡眠质量调整
        var totalSteps = baseSteps
        let sleepQuality = sleepData.duration / user.sleepBaseline
        
        if sleepQuality < 0.8 {
            totalSteps = Int(Double(totalSteps) * (0.7 + sleepQuality * 0.3))
        } else if sleepQuality > 1.2 {
            totalSteps = Int(Double(totalSteps) * min(1.3, sleepQuality))
        }
        
        // 基于最近趋势调整
        if !recentSteps.isEmpty {
            let avgRecentSteps = recentSteps.reduce(0, +) / recentSteps.count
            let trend = Double(totalSteps - avgRecentSteps) / Double(avgRecentSteps)
            
            if abs(trend) > 0.5 {
                totalSteps = avgRecentSteps + Int(Double(avgRecentSteps) * (trend > 0 ? 0.3 : -0.3))
            }
        }
        
        // 确保步数在合理范围内
        totalSteps = max(500, min(30000, totalSteps))
        
        // 🔥 使用新的真实步数生成器
        let stepIncrements = RealisticStepGenerator.generateDailyStepEvents(
            for: profile,
            date: date,
            totalTargetSteps: totalSteps,
            sleepData: sleepData,
            generator: &generator
        )
        
        print("📊 生成步数事件:")
        print("   总目标步数: \(totalSteps)")
        print("   生成事件数: \(stepIncrements.count)")
        print("   实际总步数: \(stepIncrements.reduce(0) { $0 + $1.steps })")
        
        // 转换为小时分布
        let hourlyDistribution = convertIncrementsToHourlyDistribution(stepIncrements, date: date)
        
        
        let adjustedDistribution = DailyStepDistribution(
            date: date,
            totalSteps: totalSteps,
            hourlyDistribution: hourlyDistribution,
            incrementalData: stepIncrements
        )
        
        // 转换为HourlySteps格式
        var hourlySteps: [HourlySteps] = []
        for (hour, steps) in adjustedDistribution.hourlyDistribution {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = 0
            components.second = 0
            
            if let startTime = calendar.date(from: components),
               let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) {
                hourlySteps.append(HourlySteps(
                    hour: hour,
                    steps: steps,
                    startTime: startTime,
                    endTime: endTime
                ))
            }
        }
        
        // 转换为StepsInterval格式
        var stepsIntervals: [StepsInterval] = []
        for increment in adjustedDistribution.incrementalData {
            stepsIntervals.append(StepsInterval(
                steps: increment.steps,
                startTime: increment.timestamp,
                endTime: increment.timestamp.addingTimeInterval(60) // 1分钟间隔
            ))
        }
        
        // 生成步数数据
        return StepsData(
            date: date,
            hourlySteps: hourlySteps.sorted { $0.hour < $1.hour },
            stepsIntervals: stepsIntervals
        )
    }
    
    // 🚀 保留简化版步数生成（防卡死）
    private static func generateSimplifiedDailySteps(
        for user: VirtualUser,
        date: Date,
        sleepData: SleepData
    ) -> StepsData {
        let profile = PersonalizedProfile.inferFromUser(user)
        
        // 基于活动水平快速生成目标步数
        let baseSteps: Int
        switch profile.activityLevel {
        case .low: baseSteps = Int.random(in: 3000...6000)
        case .medium: baseSteps = Int.random(in: 6000...10000)
        case .high: baseSteps = Int.random(in: 10000...15000)
        case .veryHigh: baseSteps = Int.random(in: 12000...18000)
        }
        
        // 快速生成小时分布（简化版）
        var hourlySteps: [HourlySteps] = []
        let wakingHours = (7...22) // 简化为固定活跃时间
        let stepsPerHour = baseSteps / wakingHours.count
        
        for hour in wakingHours {
            let variation = Int.random(in: -200...200)
            let steps = max(0, stepsPerHour + variation)
            
            if let startTime = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date),
               let endTime = Calendar.current.date(bySettingHour: hour, minute: 59, second: 59, of: date) {
                hourlySteps.append(HourlySteps(
                    hour: hour,
                    steps: steps,
                    startTime: startTime,
                    endTime: endTime
                ))
            }
        }
        
        return StepsData(
            date: date,
            hourlySteps: hourlySteps
        )
    }
    
    // MARK: - 实时步数注入系统
    
    // 步数注入管理器
    @MainActor
    class StepInjectionManager: ObservableObject {
        @Published var isActive = false
        @Published var currentDistribution: DailyStepDistribution?
        @Published var injectedSteps = 0
        @Published var isSleepMode = false
        
        private var injectionTimer: Timer?
        private var pendingIncrements: [StepIncrement] = []
        private var originalDelay: TimeInterval = 0.05 // 原始延迟
        
        // 启动今日步数注入 - 使用睡眠感知算法
        func startTodayInjection(for user: VirtualUser) {
            let today = Date()
            
            // 🔄 获取今日睡眠数据（如果有的话）
            let todaySleepData = getTodaySleepDataIfAvailable(for: user, date: today)
            
            // 🔄 统一使用睡眠感知算法
            let distribution = PersonalizedDataGenerator.generateEnhancedDailySteps(
                for: user, 
                date: today, 
                sleepData: todaySleepData
            )
            
            currentDistribution = distribution
            pendingIncrements = distribution.incrementalData.sorted { $0.timestamp < $1.timestamp }
            injectedSteps = 0
            isActive = true
            
            print("🎯 启动实时步数注入 (睡眠感知)")
            print("   睡眠数据: \(todaySleepData != nil ? "已匹配" : "未获取")")
            print("   计划注入: \(pendingIncrements.count)个增量")
            
            scheduleNextInjection()
        }
        
        // 获取今日睡眠数据（如果可用）
        private func getTodaySleepDataIfAvailable(for user: VirtualUser, date: Date) -> SleepData? {
            // 尝试从已生成的睡眠数据中获取
            // 注意：今日睡眠数据可能还未完成，这是正常的
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: date)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart)!
            
            // 如果是白天，可能还没有今日完整睡眠数据，使用昨日作为参考
            // 这里可以根据实际需求调整逻辑
            // 尝试生成昨日睡眠数据作为模式参考
            let referenceSleepData = PersonalizedDataGenerator.generatePersonalizedSleepData(
                for: user, 
                date: yesterday, 
                mode: .simple
            )
            
            // 将昨日睡眠模式调整到今日
            return adjustSleepDataToToday(referenceSleepData, targetDate: date)
        }
        
        // 将睡眠数据调整到目标日期
        private func adjustSleepDataToToday(_ sleepData: SleepData, targetDate: Date) -> SleepData {
            let calendar = Calendar.current
            let targetDayStart = calendar.startOfDay(for: targetDate)
            
            // 保持相同的睡眠时间偏移，但调整到目标日期
            let originalDayStart = calendar.startOfDay(for: sleepData.date)
            let bedTimeOffset = sleepData.bedTime.timeIntervalSince(originalDayStart)
            let wakeTimeOffset = sleepData.wakeTime.timeIntervalSince(originalDayStart)
            
            let adjustedBedTime: Date
            let adjustedWakeTime: Date
            
            if bedTimeOffset < 0 {
                // 跨日睡眠：前一天晚上开始
                adjustedBedTime = calendar.date(byAdding: .day, value: -1, to: targetDayStart)!
                    .addingTimeInterval(bedTimeOffset + 24 * 3600)
            } else {
                adjustedBedTime = targetDayStart.addingTimeInterval(bedTimeOffset)
            }
            
            if wakeTimeOffset < bedTimeOffset {
                // 跨日睡眠：第二天早上结束
                adjustedWakeTime = calendar.date(byAdding: .day, value: 1, to: targetDayStart)!
                    .addingTimeInterval(wakeTimeOffset)
            } else {
                adjustedWakeTime = targetDayStart.addingTimeInterval(wakeTimeOffset)
            }
            
            return SleepData(
                date: targetDate,
                bedTime: adjustedBedTime,
                wakeTime: adjustedWakeTime,
                sleepStages: [] // 实时注入简化处理
            )
        }
        
        // 停止注入
        func stopInjection() {
            injectionTimer?.invalidate()
            injectionTimer = nil
            isActive = false
            
            print("⏹️ 停止步数注入")
        }
        
        // 调度下一次注入
        private func scheduleNextInjection() {
            guard isActive && !pendingIncrements.isEmpty else {
                print("✅ 步数注入完成，总共注入: \(injectedSteps)步")
                isActive = false
                return
            }
            
            let nextIncrement = pendingIncrements.removeFirst()
            let now = Date()
            
            // 计算延迟时间
            let delay = max(0, nextIncrement.timestamp.timeIntervalSince(now))
            
            // 如果是过去的时间戳，立即注入
            if delay <= 0 {
                injectStepIncrement(nextIncrement)
                scheduleNextInjection()
            } else {
                // 调度未来的注入
                injectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.injectStepIncrement(nextIncrement)
                        self?.scheduleNextInjection()
                    }
                }
            }
        }
        
        // 注入步数增量
        private func injectStepIncrement(_ increment: StepIncrement) {
            print("📍 \(DateFormatter.localizedString(from: increment.timestamp, dateStyle: .none, timeStyle: .medium)) +\(increment.steps)步 (\(increment.activityType.rawValue))")
            
            injectedSteps += increment.steps
            
            // 实际注入到HealthKit
            Task { @MainActor in
                let success = await HealthKitManager.shared.writeStepIncrement(increment)
                if success {
                    print("✅ 步数增量已写入HealthKit")
                } else {
                    print("❌ 步数增量写入HealthKit失败")
                }
            }
        }
        
        // MARK: - 睡眠模式控制
        
        // 进入睡眠模式
        func enterSleepMode() {
            isSleepMode = true
            print("😴 步数注入进入睡眠模式")
            
            // 过滤掉睡眠时间的步数增量，或将其降至个位数
            filterSleepTimeIncrements()
            
            // 调整注入频率
            adjustInjectionFrequency(sleepMode: true)
        }
        
        // 退出睡眠模式
        func exitSleepMode() {
            isSleepMode = false
            print("🌅 步数注入退出睡眠模式")
            
            // 恢复正常注入频率
            adjustInjectionFrequency(sleepMode: false)
        }
        
        // 过滤睡眠时间的步数增量
        private func filterSleepTimeIncrements() {
            let calendar = Calendar.current
            
            // 定义睡眠时间段（晚上11点到早上6点）
            let sleepStartHour = 23
            let sleepEndHour = 6
            
            // 过滤待注入的增量
            pendingIncrements = pendingIncrements.compactMap { increment in
                let hour = calendar.component(.hour, from: increment.timestamp)
                
                // 检查是否在睡眠时间段
                let isInSleepTime = (hour >= sleepStartHour) || (hour < sleepEndHour)
                
                if isInSleepTime {
                    // 睡眠时间：95%概率为0步，5%概率为个位数步数
                    let shouldHaveSteps = Int.random(in: 1...100) <= 5 // 5%概率
                    
                    let sleepSteps: Int
                    if shouldHaveSteps {
                        // 5%概率：1-9步的个位数步数
                        sleepSteps = Int.random(in: 1...9)
                    } else {
                        // 95%概率：0步
                        sleepSteps = 0
                    }
                    
                    return StepIncrement(
                        timestamp: increment.timestamp,
                        steps: sleepSteps,
                        activityType: .idle // 标记为睡眠时间的静息活动
                    )
                } else {
                    // 非睡眠时间：保持原样
                    return increment
                }
            }
            
            print("😴 已调整睡眠时间段的步数增量 (95%为0步，5%为1-9步)")
        }
        
        // 智能调整注入频率
        private func adjustInjectionFrequency(sleepMode: Bool) {
            if sleepMode {
                // 睡眠模式：大幅降低注入频率
                originalDelay = 30.0 // 30秒一次
            } else {
                // 正常模式：恢复原始频率
                originalDelay = 0.05 // 50毫秒一次
            }
        }
    }
    
    // MARK: - 私有辅助方法
    
    private static func generateSleepTiming(for sleepType: SleepType, date: Date, using generator: inout SeededRandomGenerator) -> (bedtime: Date, wakeTime: Date) {
        let calendar = Calendar.current
        let sleepRange = sleepType.sleepTimeRange
        let consistency = sleepType.consistency
        
        // 🔧 方案A：缩小变化范围到合理水平
        let maxVariationHours: Double = 1.0 // 最大1小时变化
        let baseVariationHours = (1.0 - Double(consistency)) * maxVariationHours // 0-1小时变化
        let dailyVariationFactor = Double(generator.nextFloat(in: 0.8...1.2)) // 微调变化系数
        let variationHours = baseVariationHours * dailyVariationFactor
        
        let bedtimeVariation = generator.nextFloat(in: Float(-variationHours)...Float(variationHours))
        let wakeVariation = generator.nextFloat(in: Float(-variationHours)...Float(variationHours))
        
        // 计算入睡时间
        var bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let bedtimeHour = Float(sleepRange.start) + bedtimeVariation
        bedtimeComponents.hour = Int(bedtimeHour)
        bedtimeComponents.minute = Int((bedtimeHour - Float(Int(bedtimeHour))) * 60)
        
        // 如果入睡时间在第二天（跨日睡眠）
        if sleepRange.start < sleepRange.end {
            // 同日睡眠，不需要调整
        } else {
            // 跨日睡眠，入睡时间在前一天
            bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: -1, to: date) ?? date)
            bedtimeComponents.hour = Int(bedtimeHour)
            bedtimeComponents.minute = Int((bedtimeHour - Float(Int(bedtimeHour))) * 60)
        }
        
        let bedtime = calendar.date(from: bedtimeComponents) ?? date
        
        // 计算起床时间
        var wakeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let wakeHour = Float(sleepRange.end) + wakeVariation
        wakeComponents.hour = Int(wakeHour)
        wakeComponents.minute = Int((wakeHour - Float(Int(wakeHour))) * 60)
        
        let wakeTime = calendar.date(from: wakeComponents) ?? date
        
        return (bedtime: bedtime, wakeTime: wakeTime)
    }
    
    private static func generateSleepDuration(for sleepType: SleepType, using generator: inout SeededRandomGenerator) -> Double {
        let range = sleepType.durationRange
        
        // 🔧 改进时长生成：增加更多变化精度
        let baseDuration = Double(generator.nextFloat(in: Float(range.min)...Float(range.max)))
        let fineVariation = generator.nextFloat(in: -0.5...0.5) // 增加±0.5小时的微调
        let finalDuration = max(Double(range.min), min(Double(range.max), baseDuration + Double(fineVariation)))
        
        return finalDuration
    }
    
    private static func generateComprehensiveSleep(
        bedtime: Date,
        wakeTime: Date,
        totalDuration: Double,
        consistency: Float,
        generator: inout SeededRandomGenerator
    ) -> SleepData {
        
        // 生成睡眠阶段
        let cycleCount = Int(totalDuration / 1.5) // 每个周期约1.5小时
        var stages: [SleepStage] = []
        
        let stageDuration = totalDuration * 3600 / Double(cycleCount) // 秒
        var currentTime = bedtime
        let calendar = Calendar.current
        
        for cycle in 0..<cycleCount {
            let isEarlyCycle = cycle < cycleCount / 2
            
            // 早期周期更多深度睡眠，后期更多REM
            if isEarlyCycle {
                // 轻度睡眠
                stages.append(SleepStage(
                    stage: .light,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.4), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.4), to: currentTime) ?? currentTime
                
                // 深度睡眠
                stages.append(SleepStage(
                    stage: .deep,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.4), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.4), to: currentTime) ?? currentTime
                
                // REM睡眠
                stages.append(SleepStage(
                    stage: .rem,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.2), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.2), to: currentTime) ?? currentTime
            } else {
                // 后期周期
                stages.append(SleepStage(
                    stage: .light,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.3), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.3), to: currentTime) ?? currentTime
                
                stages.append(SleepStage(
                    stage: .deep,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.2), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.2), to: currentTime) ?? currentTime
                
                stages.append(SleepStage(
                    stage: .rem,
                    startTime: currentTime,
                    endTime: calendar.date(byAdding: .second, value: Int(stageDuration * 0.5), to: currentTime) ?? currentTime
                ))
                currentTime = calendar.date(byAdding: .second, value: Int(stageDuration * 0.5), to: currentTime) ?? currentTime
            }
        }
        
        // 添加少量清醒时间
        let awakeCount = Int(Float(cycleCount) * (1.0 - consistency) * 3) // 不规律的人更容易醒
        for _ in 0..<awakeCount {
            let randomIndex = generator.nextInt(in: 0...(stages.count - 1))
            let randomStage = stages[randomIndex]
            let awakeDuration = generator.nextInt(in: 60...600) // 1-10分钟
            
            let awakeTime = calendar.date(byAdding: .second, value: generator.nextInt(in: 0...Int(randomStage.duration)), to: randomStage.startTime) ?? randomStage.startTime
            
            stages.append(SleepStage(
                stage: .awake,
                startTime: awakeTime,
                endTime: calendar.date(byAdding: .second, value: awakeDuration, to: awakeTime) ?? awakeTime
            ))
        }
        
        return SleepData(
            date: bedtime,
            bedTime: bedtime,
            wakeTime: wakeTime,
            sleepStages: stages
        )
    }
    
    private static func generateSimpleSleep(
        bedtime: Date,
        wakeTime: Date,
        totalDuration: Double
    ) -> SleepData {
        let calendar = Calendar.current
        
        // 🔧 修复：创建基本的睡眠阶段，否则睡眠时长会是0
        let mainSleepStage = SleepStage(
            stage: .light,  // 简单模式使用浅睡眠
            startTime: bedtime,
            endTime: wakeTime
        )
        
        return SleepData(
            date: calendar.startOfDay(for: bedtime),  // 使用日期的开始作为date
            bedTime: bedtime,
            wakeTime: wakeTime,
            sleepStages: [mainSleepStage]  // 🔧 修复：至少包含一个睡眠阶段
        )
    }
    
    // MARK: - 增强版步数生成系统
    
    /// 生成整合睡眠感知的步数分布
    static func generateEnhancedDailySteps(for user: VirtualUser, date: Date, sleepData: SleepData?) -> DailyStepDistribution {
        let profile = PersonalizedProfile.inferFromUser(user)
        
        // 🔧 改进种子生成：使用更多变化因子
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let seedInput = user.id + dateString + String(dayOfYear) + "enhanced"
        let seed = generateSeed(from: seedInput)
        var generator = SeededRandomGenerator(seed: UInt64(abs(seed)))
        
        print("🚶‍♂️ 增强版步数生成 - \(profile.activityLevel.displayName)")
        
        // 计算基础日步数
        let baseDailySteps = calculateDailySteps(for: user, date: date)
        
        // 如果有睡眠数据，使用睡眠感知算法
        if let sleepData = sleepData {
            let enhancedIncrements = SleepAwareStepsGenerator.generateSleepBasedStepDistribution(
                sleepData: sleepData,
                totalDailySteps: baseDailySteps,
                date: date,
                userProfile: profile,
                generator: &generator
            )
            
            // 转换为小时分布
            let hourlyDistribution = convertIncrementsToHourlyDistribution(enhancedIncrements, date: date)
            
            // 🔧 额外保护：确保totalSteps符合最小值要求
            let safeTotalSteps = max(800, baseDailySteps)
            
            return DailyStepDistribution(
                date: date,
                totalSteps: safeTotalSteps,
                hourlyDistribution: hourlyDistribution,
                incrementalData: enhancedIncrements
            )
        } else {
            // 没有睡眠数据时使用原来的逻辑
            return DailyStepDistribution.generate(for: profile, date: date, seed: UInt64(abs(seed)))
        }
    }
    
    /// 计算每日步数（基于用户特征和日期）- 优化版
    static func calculateDailySteps(for user: VirtualUser, date: Date) -> Int {
        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(date)
        let weekday = calendar.component(.weekday, from: date)
        
        // 基础步数范围 (根据用户年龄和性别调整)
        let baseMin: Int
        let baseMax: Int
        
        switch user.age {
        case 18...30:
            baseMin = isWeekend ? 6000 : 8000
            baseMax = isWeekend ? 12000 : 15000
        case 31...50:
            baseMin = isWeekend ? 5000 : 7000
            baseMax = isWeekend ? 10000 : 13000
        case 51...70:
            baseMin = isWeekend ? 4000 : 6000
            baseMax = isWeekend ? 8000 : 11000
        default: // 70+
            baseMin = isWeekend ? 3000 : 4000
            baseMax = isWeekend ? 6000 : 8000
        }
        
        // 🔄 周内变化模拟（真实的工作生活模式）
        let weekdayMultiplier: Double
        switch weekday {
        case 2: weekdayMultiplier = 1.1  // 周一：新一周开始，活动较多
        case 3, 4: weekdayMultiplier = 1.0  // 周二三：正常
        case 5: weekdayMultiplier = 0.95 // 周四：略微疲劳
        case 6: weekdayMultiplier = 0.9  // 周五：工作日疲劳峰值
        case 7: weekdayMultiplier = 1.2  // 周六：周末第一天，活动增加
        case 1: weekdayMultiplier = 1.0  // 周日：休息为主
        default: weekdayMultiplier = 1.0
        }
        
        // 性别调整 (统计上男性平均步数略高)
        let genderMultiplier = user.gender == .male ? 1.1 : 1.0
        
        // BMI影响 (健康BMI范围内的用户步数可能更高)
        let bmi = user.weight / pow(user.height / 100, 2)
        let bmiMultiplier: Double
        switch bmi {
        case 18.5...24.9: // 正常BMI
            bmiMultiplier = 1.1
        case 25.0...29.9: // 超重
            bmiMultiplier = 0.9
        case 30...: // 肥胖
            bmiMultiplier = 0.8
        default: // 过轻
            bmiMultiplier = 0.85
        }
        
        // 🌡️ 季节性调整（基于日期）
        let month = calendar.component(.month, from: date)
        let seasonalMultiplier: Double
        switch month {
        case 12, 1, 2: seasonalMultiplier = 0.9  // 冬季：户外活动减少
        case 3, 4, 5: seasonalMultiplier = 1.1   // 春季：活动增加
        case 6, 7, 8: seasonalMultiplier = 1.0   // 夏季：正常（虽然天热但假期多）
        case 9, 10, 11: seasonalMultiplier = 1.05 // 秋季：舒适的运动季节
        default: seasonalMultiplier = 1.0
        }
        
        // 应用所有调整因子
        let adjustedMin = Int(Double(baseMin) * genderMultiplier * bmiMultiplier * weekdayMultiplier * seasonalMultiplier)
        let adjustedMax = Int(Double(baseMax) * genderMultiplier * bmiMultiplier * weekdayMultiplier * seasonalMultiplier)
        
        // 添加每日随机变化 (±20%)
        let baseSteps = Int.random(in: adjustedMin...adjustedMax)
        let variation = Double.random(in: 0.8...1.2)
        let finalSteps = Int(Double(baseSteps) * variation)
        
        // 确保在合理范围内
        return max(800, min(25000, finalSteps))
    }
    
    /// 将步数增量转换为小时分布
    private static func convertIncrementsToHourlyDistribution(_ increments: [StepIncrement], date: Date) -> [Int: Int] {
        var hourlyDistribution: [Int: Int] = [:]
        let calendar = Calendar.current
        
        for increment in increments {
            let hour = calendar.component(.hour, from: increment.timestamp)
            hourlyDistribution[hour, default: 0] += increment.steps
        }
        
        return hourlyDistribution
    }
    
    /// 根据用户特征生成活动模式
    static func generateActivityPattern(for user: VirtualUser, date: Date) -> ActivityPattern {
        let calendar = Calendar.current
        let isWeekend = calendar.isDateInWeekend(date)
        
        // 根据年龄确定活动类型
        let primaryActivity: ActivityType
        let secondaryActivity: ActivityType
        
        switch user.age {
        case 18...25: // 学生/年轻职场
            primaryActivity = isWeekend ? .exercise : .commuting
            secondaryActivity = .walking
        case 26...40: // 职场主力
            primaryActivity = .commuting
            secondaryActivity = isWeekend ? .exercise : .walking
        case 41...60: // 中年职场
            primaryActivity = .walking
            secondaryActivity = isWeekend ? .exercise : .standing
        default: // 退休人群
            primaryActivity = .walking
            secondaryActivity = .standing
        }
        
        return ActivityPattern(
            primaryActivity: primaryActivity,
            secondaryActivity: secondaryActivity,
            peakHours: isWeekend ? [10, 11, 15, 16] : [8, 9, 12, 13, 18, 19],
            lowActivityHours: [0, 1, 2, 3, 4, 5, 6, 22, 23]
        )
    }
}

/// 活动模式
struct ActivityPattern {
    let primaryActivity: ActivityType
    let secondaryActivity: ActivityType
    let peakHours: [Int]
    let lowActivityHours: [Int]
} 
