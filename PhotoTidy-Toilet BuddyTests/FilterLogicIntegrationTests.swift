//
//  FilterLogicIntegrationTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//

import XCTest
import Photos
@testable import PhotoTidy_Toilet_Buddy

/// 过滤逻辑的集成测试（测试多维度组合）
class FilterLogicIntegrationTests: XCTestCase {
    
    // MARK: - 多维度组合测试
    
    /// 测试场景：清理旧的带GPS的截图
    func testScenario_OldScreenshotsWithLocation() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .older1Year
        config.locationFilter = .withLocation
        config.excludeFavorite = true
        
        // 验证配置有效性
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "配置应该有效")
        XCTAssertTrue(validation.warnings.isEmpty, "不应该有警告")
        
        // 验证摘要包含所有维度
        let summary = config.summary
        XCTAssertTrue(summary.contains("仅截图"), "应该包含内容类型")
        XCTAssertTrue(summary.contains("1 年前"), "应该包含日期范围")
        XCTAssertTrue(summary.contains("含位置信息"), "应该包含位置过滤")
        XCTAssertTrue(summary.contains("排除收藏"), "应该包含排除选项")
        
        // 验证 AND 逻辑
        let parts = summary.components(separatedBy: " 且 ")
        XCTAssertEqual(parts.count, 4, "应该有 4 个条件通过'且'连接")
    }
    
    /// 测试场景：清理最近的慢动作长视频
    func testScenario_RecentSlowMotionLongVideos() {
        var config = FilterConfiguration()
        config.contentType = .slowMotionVideos
        config.dateRange = .recent30Days
        config.durationFilter = .longVideos
        config.excludeFavorite = true
        
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "配置应该有效")
        
        // 可能有位置信息建议（视频）
        if config.locationFilter == .withLocation {
            XCTAssertFalse(validation.suggestions.isEmpty)
        }
    }
    
    /// 测试场景：清理无GPS的旧自拍
    func testScenario_OldSelfiesWithoutLocation() {
        var config = FilterConfiguration()
        config.contentType = .selfies
        config.dateRange = .older1Year
        config.locationFilter = .withoutLocation
        config.excludeHidden = true
        config.excludeFavorite = true
        
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "配置应该有效")
        
        // 应该有自拍准确度建议
        XCTAssertFalse(validation.suggestions.isEmpty)
        XCTAssertTrue(validation.suggestions.joined().contains("70%"))
        
        let summary = config.summary
        XCTAssertTrue(summary.contains("仅自拍"))
        XCTAssertTrue(summary.contains("1 年前"))
        XCTAssertTrue(summary.contains("无位置信息"))
    }
    
    /// 测试场景：清理最近的短视频
    func testScenario_RecentShortVideos() {
        var config = FilterConfiguration()
        config.contentType = .videos
        config.dateRange = .recent7Days
        config.durationFilter = .shortVideos
        
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "配置应该有效")
        XCTAssertTrue(validation.warnings.isEmpty, "不应该有警告")
    }
    
    // MARK: - 优先级丢失问题验证（回归测试）
    
    /// 测试：多维度不会因为优先级而丢失
    func testNoPriorityLoss_AllDimensions() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        config.durationFilter = nil  // 注意：这里故意不设置
        
        let summary = config.summary
        
        // 验证所有设置的维度都出现
        XCTAssertTrue(summary.contains("仅截图"), "内容类型不应该丢失")
        XCTAssertTrue(summary.contains("最近 30 天"), "日期范围不应该丢失")
        XCTAssertTrue(summary.contains("含位置信息"), "位置过滤不应该丢失")
        
        // 验证没设置的维度不出现
        XCTAssertFalse(summary.contains("短视频"), "未设置的时长不应该出现")
        XCTAssertFalse(summary.contains("长视频"), "未设置的时长不应该出现")
    }
    
    /// 测试：时长过滤不会覆盖其他维度
    func testNoPriorityLoss_DurationDoesNotOverrideOthers() {
        var config = FilterConfiguration()
        config.contentType = .videos
        config.dateRange = .recent30Days
        config.durationFilter = .shortVideos
        
        let summary = config.summary
        
        // 所有三个维度都应该存在
        XCTAssertTrue(summary.contains("仅视频"), "内容类型不应该被时长覆盖")
        XCTAssertTrue(summary.contains("最近 30 天"), "日期不应该被时长覆盖")
        XCTAssertTrue(summary.contains("短视频"), "时长应该存在")
    }
    
    /// 测试：日期过滤不会覆盖其他维度
    func testNoPriorityLoss_DateDoesNotOverrideOthers() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent7Days
        config.locationFilter = .withLocation
        
        let summary = config.summary
        
        XCTAssertTrue(summary.contains("仅截图"), "内容类型不应该被日期覆盖")
        XCTAssertTrue(summary.contains("最近 7 天"), "日期应该存在")
        XCTAssertTrue(summary.contains("含位置信息"), "位置不应该被日期覆盖")
    }
    
    // MARK: - 矛盾配置集成测试
    
    /// 测试所有可能的矛盾组合
    func testAllConflictingCombinations() {
        let imageTypes: [ContentType] = [.screenshots, .selfies, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        let durationFilters: [DurationFilterType] = [.shortVideos, .longVideos]
        
        var conflictCount = 0
        
        for imageType in imageTypes {
            for duration in durationFilters {
                var config = FilterConfiguration()
                config.contentType = imageType
                config.durationFilter = duration
                
                let validation = config.validate()
                
                if !validation.isValid {
                    conflictCount += 1
                    XCTAssertTrue(validation.warnings.joined().contains("图片类型不支持视频时长"))
                }
            }
        }
        
        // 应该检测到所有矛盾
        XCTAssertEqual(conflictCount, imageTypes.count * durationFilters.count, "应该检测到所有图片类型与时长的矛盾")
    }
    
    // MARK: - 复杂组合压力测试
    
    /// 测试所有维度的笛卡尔积（排除矛盾配置）
    func testCartesianProduct_ValidCombinations() {
        var validCount = 0
        var invalidCount = 0
        
        for contentType in ContentType.allCases {
            for dateRange in [nil] + DateRangeType.allCases.map { Optional($0) } {
                for locationFilter in [nil] + LocationFilterType.allCases.map { Optional($0) } {
                    for durationFilter in [nil] + DurationFilterType.allCases.map { Optional($0) } {
                        var config = FilterConfiguration()
                        config.contentType = contentType
                        config.dateRange = dateRange
                        config.locationFilter = locationFilter
                        config.durationFilter = durationFilter
                        
                        let validation = config.validate()
                        
                        if validation.isValid {
                            validCount += 1
                        } else {
                            invalidCount += 1
                        }
                        
                        // 所有配置都应该能生成摘要
                        XCTAssertFalse(config.summary.isEmpty, "配置应该能生成摘要")
                        
                        // 所有配置都应该能序列化
                        XCTAssertNoThrow(try JSONEncoder().encode(config))
                    }
                }
            }
        }
        
        print("✅ 有效配置: \(validCount)")
        print("⚠️ 无效配置: \(invalidCount)")
        
        XCTAssertGreaterThan(validCount, 0, "应该有有效配置")
    }
    
    // MARK: - 摘要一致性测试
    
    /// 测试摘要与配置的一致性
    func testSummary_ConsistencyWithConfiguration() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        
        let summary = config.summary
        
        // 如果配置了某个维度，摘要中必须包含
        XCTAssertTrue(summary.contains("仅截图"), "配置了截图，摘要必须包含")
        XCTAssertTrue(summary.contains("最近 30 天"), "配置了日期，摘要必须包含")
        
        // 如果没有配置某个维度，摘要中不应该包含相关内容
        XCTAssertFalse(summary.contains("含位置"), "未配置位置，摘要不应该包含")
        XCTAssertFalse(summary.contains("无位置"), "未配置位置，摘要不应该包含")
        XCTAssertFalse(summary.contains("短视频"), "未配置时长，摘要不应该包含")
        XCTAssertFalse(summary.contains("长视频"), "未配置时长，摘要不应该包含")
    }
    
    /// 测试摘要顺序一致性
    func testSummary_OrderConsistency() {
        // 摘要应该按固定顺序显示：内容类型 → 日期 → 位置 → 时长 → 其他
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        config.excludeFavorite = true
        
        let summary = config.summary
        let parts = summary.components(separatedBy: " 且 ")
        
        // 验证顺序
        if parts.count >= 2 {
            // 内容类型应该在前面
            XCTAssertTrue(parts[0].contains("截图") || parts[0].contains("媒体"))
        }
    }
    
    // MARK: - AND 逻辑验证
    
    /// 测试 AND 逻辑：所有条件都必须满足
    func testANDLogic_AllConditionsMustMatch() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        config.excludeHidden = true
        config.excludeFavorite = true
        
        let summary = config.summary
        
        // 验证使用 "且" 连接（表示 AND）
        XCTAssertTrue(summary.contains("且"), "应该使用'且'表示 AND 逻辑")
        
        // 验证所有条件都在摘要中
        let conditions = ["仅截图", "最近 30 天", "含位置信息", "排除隐藏", "排除收藏"]
        for condition in conditions {
            XCTAssertTrue(summary.contains(condition), "摘要应该包含 \(condition)")
        }
    }
    
    /// 测试 AND 逻辑：逐步添加条件，结果应该更精确
    func testANDLogic_AddingConditionsNarrowsResults() {
        // 配置 1：只有内容类型
        var config1 = FilterConfiguration()
        config1.contentType = .screenshots
        
        // 配置 2：内容类型 + 日期
        var config2 = FilterConfiguration()
        config2.contentType = .screenshots
        config2.dateRange = .recent30Days
        
        // 配置 3：内容类型 + 日期 + 位置
        var config3 = FilterConfiguration()
        config3.contentType = .screenshots
        config3.dateRange = .recent30Days
        config3.locationFilter = .withLocation
        
        // 摘要应该逐步变长（条件更多）
        let parts1 = config1.summary.components(separatedBy: " 且 ")
        let parts2 = config2.summary.components(separatedBy: " 且 ")
        let parts3 = config3.summary.components(separatedBy: " 且 ")
        
        XCTAssertLessThan(parts1.count, parts2.count, "添加条件后，条件数应该增加")
        XCTAssertLessThan(parts2.count, parts3.count, "继续添加条件后，条件数应该再增加")
    }
    
    // MARK: - 维度独立性测试
    
    /// 测试各维度相互独立
    func testDimensions_AreIndependent() {
        // 修改一个维度不应该影响其他维度
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        
        // 修改内容类型
        config.contentType = .videos
        
        // 其他维度应该保持不变
        XCTAssertEqual(config.dateRange, .recent30Days, "修改内容类型不应该影响日期")
        XCTAssertEqual(config.locationFilter, .withLocation, "修改内容类型不应该影响位置")
    }
    
    /// 测试日期维度可以独立设置和清除
    func testDateDimension_IndependentSetting() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        
        // 清除日期
        config.dateRange = nil
        
        // 内容类型应该保持
        XCTAssertEqual(config.contentType, .screenshots)
        
        // 摘要不应该包含日期
        XCTAssertFalse(config.summary.contains("最近 30 天"))
    }
    
    // MARK: - 序列化完整性测试
    
    /// 测试复杂配置的序列化和反序列化
    func testComplexConfiguration_SerializationCompleteness() throws {
        var originalConfig = FilterConfiguration()
        originalConfig.contentType = .slowMotionVideos
        originalConfig.dateRange = .older1Year
        originalConfig.locationFilter = .withLocation
        originalConfig.durationFilter = .longVideos
        originalConfig.excludeHidden = false
        originalConfig.excludeFavorite = true
        
        // 序列化
        let data = try JSONEncoder().encode(originalConfig)
        
        // 反序列化
        let decodedConfig = try JSONDecoder().decode(FilterConfiguration.self, from: data)
        
        // 验证所有字段都正确还原
        XCTAssertEqual(decodedConfig.contentType, originalConfig.contentType)
        XCTAssertEqual(decodedConfig.dateRange, originalConfig.dateRange)
        XCTAssertEqual(decodedConfig.locationFilter, originalConfig.locationFilter)
        XCTAssertEqual(decodedConfig.durationFilter, originalConfig.durationFilter)
        XCTAssertEqual(decodedConfig.excludeHidden, originalConfig.excludeHidden)
        XCTAssertEqual(decodedConfig.excludeFavorite, originalConfig.excludeFavorite)
        
        // 验证摘要一致
        XCTAssertEqual(decodedConfig.summary, originalConfig.summary)
        
        // 验证验证结果一致
        XCTAssertEqual(decodedConfig.validate().isValid, originalConfig.validate().isValid)
    }
    
    /// 测试空配置的序列化
    func testEmptyConfiguration_Serialization() throws {
        var config = FilterConfiguration()
        config.excludeHidden = false
        config.excludeFavorite = false
        
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FilterConfiguration.self, from: data)
        
        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.summary, "所有媒体")
    }
    
    // MARK: - 验证逻辑完整性测试
    
    /// 测试所有有效配置都能通过验证
    func testValidation_AllValidConfigurationsPass() {
        let validConfigurations: [FilterConfiguration] = [
            FilterConfiguration(),  // 默认配置
            {
                var c = FilterConfiguration()
                c.contentType = .screenshots
                return c
            }(),
            {
                var c = FilterConfiguration()
                c.contentType = .videos
                c.durationFilter = .shortVideos
                return c
            }(),
            {
                var c = FilterConfiguration()
                c.contentType = .screenshots
                c.dateRange = .recent30Days
                c.locationFilter = .withLocation
                return c
            }()
        ]
        
        for config in validConfigurations {
            let validation = config.validate()
            XCTAssertTrue(validation.isValid || !validation.suggestions.isEmpty, "有效配置应该通过验证或只有建议")
        }
    }
    
    /// 测试所有无效配置都会被检测
    func testValidation_AllInvalidConfigurationsDetected() {
        let invalidConfigurations: [FilterConfiguration] = [
            {
                var c = FilterConfiguration()
                c.contentType = .screenshots  // 图片
                c.durationFilter = .shortVideos  // 时长（矛盾）
                return c
            }(),
            {
                var c = FilterConfiguration()
                c.contentType = .panoramas  // 图片
                c.durationFilter = .longVideos  // 时长（矛盾）
                return c
            }(),
            {
                var c = FilterConfiguration()
                c.contentType = .hdrPhotos  // 图片
                c.durationFilter = .shortVideos  // 时长（矛盾）
                return c
            }()
        ]
        
        for config in invalidConfigurations {
            let validation = config.validate()
            XCTAssertFalse(validation.isValid, "矛盾配置应该验证失败")
            XCTAssertFalse(validation.warnings.isEmpty, "矛盾配置应该有警告")
        }
    }
    
    // MARK: - 边界情况测试
    
    /// 测试nil值的处理
    func testNilValues_HandledCorrectly() {
        var config = FilterConfiguration()
        config.dateRange = nil
        config.locationFilter = nil
        config.durationFilter = nil
        
        let summary = config.summary
        
        // nil 值不应该出现在摘要中
        XCTAssertFalse(summary.contains("nil"))
        XCTAssertFalse(summary.contains("null"))
        
        // 验证应该通过
        let validation = config.validate()
        XCTAssertTrue(validation.isValid)
    }
    
    /// 测试所有布尔值组合
    func testBooleanCombinations() {
        let combinations: [(Bool, Bool)] = [
            (true, true),
            (true, false),
            (false, true),
            (false, false)
        ]
        
        for (excludeHidden, excludeFavorite) in combinations {
            var config = FilterConfiguration()
            config.excludeHidden = excludeHidden
            config.excludeFavorite = excludeFavorite
            
            let validation = config.validate()
            XCTAssertTrue(validation.isValid, "布尔值组合 (\(excludeHidden), \(excludeFavorite)) 应该有效")
            
            let summary = config.summary
            
            if excludeHidden {
                XCTAssertTrue(summary.contains("排除隐藏"))
            } else {
                XCTAssertFalse(summary.contains("排除隐藏"))
            }
            
            if excludeFavorite {
                XCTAssertTrue(summary.contains("排除收藏"))
            } else {
                XCTAssertFalse(summary.contains("排除收藏"))
            }
        }
    }
    
    // MARK: - 实际使用场景模拟
    
    /// 模拟用户工作流 1：逐步添加过滤条件
    func testUserWorkflow_GraduallyAddingFilters() {
        var config = FilterConfiguration()
        
        // 步骤 1：选择内容类型
        config.contentType = .screenshots
        XCTAssertTrue(config.validate().isValid)
        XCTAssertTrue(config.summary.contains("仅截图"))
        
        // 步骤 2：添加日期范围
        config.dateRange = .recent30Days
        XCTAssertTrue(config.validate().isValid)
        XCTAssertTrue(config.summary.contains("最近 30 天"))
        
        // 步骤 3：添加位置过滤
        config.locationFilter = .withLocation
        XCTAssertTrue(config.validate().isValid)
        XCTAssertTrue(config.summary.contains("含位置信息"))
        
        // 步骤 4：设置排除选项
        config.excludeFavorite = true
        XCTAssertTrue(config.validate().isValid)
        XCTAssertTrue(config.summary.contains("排除收藏"))
        
        // 最终配置应该包含所有步骤
        let finalSummary = config.summary
        XCTAssertTrue(finalSummary.contains("仅截图"))
        XCTAssertTrue(finalSummary.contains("最近 30 天"))
        XCTAssertTrue(finalSummary.contains("含位置信息"))
        XCTAssertTrue(finalSummary.contains("排除收藏"))
    }
    
    /// 模拟用户工作流 2：修改配置
    func testUserWorkflow_ModifyingFilters() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent7Days
        
        let initialSummary = config.summary
        
        // 修改日期范围
        config.dateRange = .recent30Days
        
        let modifiedSummary = config.summary
        
        // 应该反映修改
        XCTAssertTrue(modifiedSummary.contains("最近 30 天"))
        XCTAssertFalse(modifiedSummary.contains("最近 7 天"))
        
        // 其他维度保持不变
        XCTAssertTrue(modifiedSummary.contains("仅截图"))
    }
    
    /// 模拟用户工作流 3：清除过滤条件
    func testUserWorkflow_ClearingFilters() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        
        // 清除日期
        config.dateRange = nil
        
        let summary = config.summary
        XCTAssertFalse(summary.contains("最近 30 天"), "清除后不应该包含日期")
        XCTAssertTrue(summary.contains("仅截图"), "其他条件应该保持")
        XCTAssertTrue(summary.contains("含位置信息"), "其他条件应该保持")
    }
    
    // MARK: - 错误恢复测试
    
    /// 测试从矛盾配置恢复
    func testErrorRecovery_FromConflictingConfiguration() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.durationFilter = .shortVideos  // 矛盾
        
        let validation1 = config.validate()
        XCTAssertFalse(validation1.isValid, "矛盾配置应该无效")
        
        // 修复：移除时长过滤
        config.durationFilter = nil
        
        let validation2 = config.validate()
        XCTAssertTrue(validation2.isValid, "修复后应该有效")
        XCTAssertTrue(validation2.warnings.isEmpty, "修复后不应该有警告")
    }
    
    /// 测试从矛盾配置恢复 - 另一种方式
    func testErrorRecovery_ChangeContentType() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.durationFilter = .shortVideos  // 矛盾
        
        XCTAssertFalse(config.validate().isValid)
        
        // 修复：改为视频类型
        config.contentType = .videos
        
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "改为视频类型后应该有效")
    }
}

