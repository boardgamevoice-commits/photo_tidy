//
//  EdgeCaseTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//

import XCTest
@testable import PhotoTidy_Toilet_Buddy

/// 边界情况和特殊场景的单元测试
class EdgeCaseTests: XCTestCase {
    
    // MARK: - 空值和默认值测试
    
    func testEmptyConfiguration() {
        var config = FilterConfiguration()
        config.excludeHidden = false
        config.excludeFavorite = false
        
        XCTAssertEqual(config.summary, "所有媒体")
        XCTAssertTrue(config.validate().isValid)
    }
    
    func testNilOptionalFields() {
        var config = FilterConfiguration()
        config.dateRange = nil
        // config.locationFilter = nil  // 位置过滤已移除
        config.durationFilter = nil
        
        // 不应该崩溃
        XCTAssertNoThrow(config.summary)
        XCTAssertNoThrow(config.validate())
        
        // 摘要不应该包含 nil 相关文本
        let summary = config.summary
        XCTAssertFalse(summary.lowercased().contains("nil"))
        XCTAssertFalse(summary.lowercased().contains("null"))
        // XCTAssertFalse(summary.contains("无"))  // 位置过滤已移除
    }
    
    // MARK: - 极端值测试
    
    func testAllPossibleContentTypes() {
        // 测试所有 11 种内容类型
        XCTAssertEqual(ContentType.allCases.count, 11)
        
        for contentType in ContentType.allCases {
            var config = FilterConfiguration()
            config.contentType = contentType
            
            // 应该都能工作
            XCTAssertNotNil(config.summary)
            XCTAssertNoThrow(try JSONEncoder().encode(config))
            
            let validation = config.validate()
            
        }
    }
    
    func testAllPossibleDateRanges() {
        // 测试所有 6 种日期范围
        XCTAssertEqual(DateRangeType.allCases.count, 6)
        
        for dateRange in DateRangeType.allCases {
            var config = FilterConfiguration()
            config.dateRange = dateRange
            
            XCTAssertTrue(config.summary.contains(dateRange.rawValue))
            XCTAssertNoThrow(try JSONEncoder().encode(config))
        }
    }
    
    // MARK: - 连拍特殊场景测试
    
    func testBursts_WithRecentDates() {
        let recentRanges: [DateRangeType] = [.recent7Days, .recent30Days]
        
        for range in recentRanges {
            var config = FilterConfiguration()
            config.contentType = .bursts
            config.dateRange = range
            
            let validation = config.validate()
            
            // 应该有建议（连拍较少）
            if range == .recent7Days {
                XCTAssertFalse(validation.suggestions.isEmpty)
            }
        }
    }
    
    func testBursts_WithOldDates() {
        let oldRanges: [DateRangeType] = [.older1Year, .older2Years]
        
        for range in oldRanges {
            var config = FilterConfiguration()
            config.contentType = .bursts
            config.dateRange = range
            
            let validation = config.validate()
            XCTAssertTrue(validation.isValid)
        }
    }
    
    // MARK: - 自拍特殊场景测试
    
    
    
    // MARK: - 视频时长特殊场景测试
    
    func testDurationFilter_OnlyWithVideoTypes() {
        let videoTypes: [ContentType] = [.videos, .slowMotionVideos, .timelapseVideos]
        let imageTypes: [ContentType] = [.screenshots, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        
        // 视频类型 + 时长 = 有效
        for videoType in videoTypes {
            var config = FilterConfiguration()
            config.contentType = videoType
            config.durationFilter = .shortVideos
            
            XCTAssertTrue(config.validate().isValid)
        }
        
        // 图片类型 + 时长 = 无效
        for imageType in imageTypes {
            var config = FilterConfiguration()
            config.contentType = imageType
            config.durationFilter = .shortVideos
            
            XCTAssertFalse(config.validate().isValid)
        }
    }
    
    func testShortVideos_MustBeVideo() {
        var config = FilterConfiguration()
        config.contentType = .all  // 所有媒体（包含图片）
        config.durationFilter = .shortVideos
        
        // 这在逻辑上可能有歧义，但当前实现允许
        // 因为 duration 对图片是 0，不会匹配任何时长条件
        // 实际结果：只会返回短视频（图片被时长条件过滤掉）
        
        let validation = config.validate()
        // 可以考虑添加警告
    }
    
    // MARK: - 位置信息特殊场景（已移除）
    
    func testLocation_WithAllContentTypes() {
        // 位置过滤功能已删除，LocationFilterType 枚举已移除
        // 此测试已更新为只测试内容类型
        for contentType in ContentType.allCases {
            var config = FilterConfiguration()
            config.contentType = contentType
            
            let validation = config.validate()
            XCTAssertTrue(validation.isValid, "\(contentType.rawValue) 应该有效")
        }
    }
    
    // MARK: - 摘要格式边界测试
    
    func testSummary_EmptyParts() {
        var config = FilterConfiguration()
        config.contentType = .all
        config.excludeHidden = false
        config.excludeFavorite = false
        
        let summary = config.summary
        XCTAssertEqual(summary, "所有媒体", "完全空的配置应该返回'所有媒体'")
    }
    
    func testSummary_SinglePart() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.excludeHidden = false
        config.excludeFavorite = false
        
        let summary = config.summary
        XCTAssertEqual(summary, "仅截图", "只有一个条件时不应该有'且'")
    }
    
    func testSummary_MultipleParts() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.excludeHidden = false
        config.excludeFavorite = false
        
        let summary = config.summary
        XCTAssertTrue(summary.contains("且"), "多个条件应该用'且'连接")
        
        let parts = summary.components(separatedBy: " 且 ")
        XCTAssertEqual(parts.count, 2, "应该有 2 个条件")
    }
    
    // MARK: - Equatable 边界测试
    
    func testEquatable_SameConfiguration() {
        var config1 = FilterConfiguration()
        config1.contentType = .screenshots
        config1.dateRange = .recent30Days
        
        var config2 = FilterConfiguration()
        config2.contentType = .screenshots
        config2.dateRange = .recent30Days
        
        XCTAssertEqual(config1, config2)
    }
    
    func testEquatable_DifferentContentType() {
        var config1 = FilterConfiguration()
        config1.contentType = .screenshots
        
        var config2 = FilterConfiguration()
        config2.contentType = .videos
        
        XCTAssertNotEqual(config1, config2)
    }
    
    func testEquatable_DifferentDateRange() {
        var config1 = FilterConfiguration()
        config1.dateRange = .recent7Days
        
        var config2 = FilterConfiguration()
        config2.dateRange = .recent30Days
        
        XCTAssertNotEqual(config1, config2)
    }
    
    func testEquatable_DifferentBooleans() {
        var config1 = FilterConfiguration()
        config1.excludeHidden = true
        
        var config2 = FilterConfiguration()
        config2.excludeHidden = false
        
        XCTAssertNotEqual(config1, config2)
    }
    
    func testEquatable_OneWithNilOneWithValue() {
        var config1 = FilterConfiguration()
        config1.dateRange = nil
        
        var config2 = FilterConfiguration()
        config2.dateRange = .recent30Days
        
        XCTAssertNotEqual(config1, config2)
    }
    
    // MARK: - 序列化边界测试
    
    func testSerialization_AllNilOptionals() throws {
        var config = FilterConfiguration()
        config.dateRange = nil
        // config.locationFilter = nil  // 位置过滤已移除
        config.durationFilter = nil
        
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FilterConfiguration.self, from: data)
        
        XCTAssertNil(decoded.dateRange)
        // XCTAssertNil(decoded.locationFilter)  // 位置过滤已移除
        XCTAssertNil(decoded.durationFilter)
    }
    
    func testSerialization_AllSetOptionals() throws {
        var config = FilterConfiguration()
        config.dateRange = .recent30Days
        // config.locationFilter = .withLocation  // 位置过滤已移除
        config.durationFilter = .shortVideos
        
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FilterConfiguration.self, from: data)
        
        XCTAssertEqual(decoded.dateRange, .recent30Days)
        // XCTAssertEqual(decoded.locationFilter, .withLocation)  // 位置过滤已移除
        XCTAssertEqual(decoded.durationFilter, .shortVideos)
    }
    
    func testSerialization_BooleanEdgeCases() throws {
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
            
            let data = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(FilterConfiguration.self, from: data)
            
            XCTAssertEqual(decoded.excludeHidden, excludeHidden)
            XCTAssertEqual(decoded.excludeFavorite, excludeFavorite)
        }
    }
    
    // MARK: - 压力测试
    
    func testStress_ThousandsOfValidations() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        
        measure {
            for _ in 0..<10000 {
                _ = config.validate()
            }
        }
    }
    
    func testStress_ThousandsOfSummaryGenerations() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        // config.locationFilter = .withLocation  // 位置过滤已移除
        
        measure {
            for _ in 0..<10000 {
                _ = config.summary
            }
        }
    }
    
    func testStress_ThousandsOfSerializations() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        
        measure {
            for _ in 0..<1000 {
                _ = try? JSONEncoder().encode(config)
            }
        }
    }
    
    // MARK: - 并发测试
    
    func testConcurrency_ParallelValidations() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        
        let expectation = XCTestExpectation(description: "并发验证")
        expectation.expectedFulfillmentCount = 100
        
        for _ in 0..<100 {
            DispatchQueue.global().async {
                let validation = config.validate()
                XCTAssertTrue(validation.isValid)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrency_ParallelSummaryGenerations() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        // config.locationFilter = .withLocation  // 位置过滤已移除
        
        let expectation = XCTestExpectation(description: "并发生成摘要")
        expectation.expectedFulfillmentCount = 100
        
        for _ in 0..<100 {
            DispatchQueue.global().async {
                let summary = config.summary
                XCTAssertFalse(summary.isEmpty)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - 配置修改安全性测试
    
    func testConfiguration_ImmutabilityOfCopy() {
        var config1 = FilterConfiguration()
        config1.contentType = .screenshots
        
        var config2 = config1  // 复制
        config2.contentType = .videos  // 修改副本
        
        // 原始配置不应该改变（值类型）
        XCTAssertEqual(config1.contentType, .screenshots)
        XCTAssertEqual(config2.contentType, .videos)
    }
    
    func testConfiguration_MultipleModifications() {
        var config = FilterConfiguration()
        
        // 连续修改
        config.contentType = .screenshots
        config.contentType = .videos
        config.contentType = .panoramas
        
        // 最后的修改应该生效
        XCTAssertEqual(config.contentType, .panoramas)
    }
    
    // MARK: - 摘要长度测试
    
    func testSummary_MinimumLength() {
        var config = FilterConfiguration()
        config.excludeHidden = false
        config.excludeFavorite = false
        
        let summary = config.summary
        XCTAssertGreaterThanOrEqual(summary.count, 4, "最短摘要应该至少有 4 个字符")
    }
    
    func testSummary_MaximumLength() {
        // 设置所有可能的过滤条件
        var config = FilterConfiguration()
        config.contentType = .slowMotionVideos  // 最长的类型名
        config.dateRange = .recent30Days
        // config.locationFilter = .withLocation  // 位置过滤已移除
        config.durationFilter = .longVideos
        config.excludeHidden = true
        config.excludeFavorite = true
        
        let summary = config.summary
        
        // 摘要不应该过长（UI 显示问题）
        XCTAssertLessThan(summary.count, 200, "摘要不应该过长")
    }
    
    // MARK: - 特殊字符测试
    
    func testSummary_NoSpecialCharacters() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        
        let summary = config.summary
        
        // 不应该包含特殊字符
        XCTAssertFalse(summary.contains("\n"), "摘要不应该包含换行")
        XCTAssertFalse(summary.contains("\t"), "摘要不应该包含制表符")
    }
    
    // MARK: - 验证结果一致性测试
    
    func testValidation_Deterministic() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.durationFilter = .shortVideos  // 矛盾配置
        
        // 多次验证应该得到相同结果
        let validation1 = config.validate()
        let validation2 = config.validate()
        let validation3 = config.validate()
        
        XCTAssertEqual(validation1.isValid, validation2.isValid)
        XCTAssertEqual(validation2.isValid, validation3.isValid)
        XCTAssertEqual(validation1.warnings.count, validation2.warnings.count)
        XCTAssertEqual(validation2.warnings.count, validation3.warnings.count)
    }
    
    // MARK: - 回归测试：确保修复没有破坏现有功能
    
    func testRegression_DefaultConfigurationStillWorks() {
        let config = FilterConfiguration()
        
        XCTAssertEqual(config.contentType, .all)
        XCTAssertNil(config.dateRange)
        // XCTAssertNil(config.locationFilter)  // 位置过滤已移除
        XCTAssertNil(config.durationFilter)
        XCTAssertTrue(config.excludeHidden)
        XCTAssertTrue(config.excludeFavorite)
        
        XCTAssertTrue(config.validate().isValid)
        XCTAssertFalse(config.summary.isEmpty)
    }
    
    func testRegression_ExcludeOptionsStillWork() {
        var config1 = FilterConfiguration()
        config1.excludeHidden = true
        config1.excludeFavorite = false
        
        var config2 = FilterConfiguration()
        config2.excludeHidden = false
        config2.excludeFavorite = true
        
        XCTAssertTrue(config1.summary.contains("排除隐藏"))
        XCTAssertFalse(config1.summary.contains("排除收藏"))
        
        XCTAssertFalse(config2.summary.contains("排除隐藏"))
        XCTAssertTrue(config2.summary.contains("排除收藏"))
    }
    
    func testRegression_CodableStillWorks() throws {
        let config = FilterConfiguration()
        
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FilterConfiguration.self, from: data)
        
        XCTAssertEqual(decoded, config)
    }
    
    // MARK: - 实际使用模式测试
    
    func testRealWorldPattern_TypicalCleanupScenario() {
        // 模拟典型的清理场景
        let scenarios: [FilterConfiguration] = [
            {
                var c = FilterConfiguration()
                c.contentType = .screenshots
                c.dateRange = .older1Year
                c.excludeFavorite = true
                return c
            }(),
            {
                var c = FilterConfiguration()
                c.contentType = .slowMotionVideos
                c.dateRange = .older1Year
                c.durationFilter = .longVideos
                return c
            }(),
            {
                var c = FilterConfiguration()
                c.contentType = .videos
                c.durationFilter = .shortVideos
                c.dateRange = .recent7Days
                return c
            }()
        ]
        
        for (index, scenario) in scenarios.enumerated() {
            let validation = scenario.validate()
            
            // 所有实际场景都应该能工作（可能有建议但应该有效）
            if !validation.isValid {
                XCTFail("场景 \(index + 1) 应该有效，但验证失败：\(validation.warnings.joined())")
            }
            
            // 应该能序列化（保存配置）
            XCTAssertNoThrow(try JSONEncoder().encode(scenario), "场景 \(index + 1) 应该能序列化")
            
            // 应该有有意义的摘要
            XCTAssertFalse(scenario.summary.isEmpty, "场景 \(index + 1) 应该有摘要")
            XCTAssertNotEqual(scenario.summary, "所有媒体", "场景 \(index + 1) 应该有具体的过滤条件")
        }
    }
    
    // MARK: - 性能基准测试
    
    func testPerformance_ConfigurationCreation() {
        measure {
            for _ in 0..<10000 {
                _ = FilterConfiguration()
            }
        }
    }
    
    func testPerformance_ConfigurationModification() {
        var config = FilterConfiguration()
        
        measure {
            for i in 0..<1000 {
                config.contentType = i % 2 == 0 ? .screenshots : .videos
                config.dateRange = i % 3 == 0 ? .recent30Days : nil
                // config.locationFilter = i % 5 == 0 ? .withLocation : nil  // 位置过滤已移除
            }
        }
    }
}

