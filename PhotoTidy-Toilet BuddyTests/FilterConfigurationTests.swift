//
//  FilterConfigurationTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//

import XCTest
@testable import PhotoTidy_Toilet_Buddy

/// FilterConfiguration 过滤逻辑的单元测试
class FilterConfigurationTests: XCTestCase {
    
    // MARK: - 基础配置测试
    
    /// 测试默认配置
    func testDefaultConfiguration() {
        let config = FilterConfiguration()
        
        XCTAssertEqual(config.contentType, .all, "默认应该选择所有媒体")
        XCTAssertNil(config.dateRange, "默认应该没有日期范围限制")
        XCTAssertNil(config.locationFilter, "默认应该没有位置过滤")
        XCTAssertNil(config.durationFilter, "默认应该没有时长过滤")
        XCTAssertTrue(config.excludeHidden, "默认应该排除隐藏照片")
        XCTAssertTrue(config.excludeFavorite, "默认应该排除收藏照片")
    }
    
    /// 测试配置摘要生成 - 默认配置
    func testSummaryForDefaultConfiguration() {
        let config = FilterConfiguration()
        let summary = config.summary
        
        XCTAssertTrue(summary.contains("排除隐藏"), "摘要应该包含'排除隐藏'")
        XCTAssertTrue(summary.contains("排除收藏"), "摘要应该包含'排除收藏'")
    }
    
    /// 测试配置摘要生成 - 单一维度
    func testSummaryForSingleDimension() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        
        let summary = config.summary
        
        XCTAssertTrue(summary.contains("仅截图"), "摘要应该包含'仅截图'")
        XCTAssertTrue(summary.contains("且"), "摘要应该使用'且'连接")
    }
    
    /// 测试配置摘要生成 - 多维度组合
    func testSummaryForMultipleDimensions() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        
        let summary = config.summary
        
        XCTAssertTrue(summary.contains("仅截图"), "摘要应该包含内容类型")
        XCTAssertTrue(summary.contains("最近 30 天"), "摘要应该包含日期范围")
        XCTAssertTrue(summary.contains("含位置信息"), "摘要应该包含位置过滤")
        XCTAssertTrue(summary.contains("且"), "摘要应该使用'且'连接多个条件")
    }
    
    // MARK: - 配置验证测试
    
    /// 测试有效配置
    func testValidConfiguration() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        
        let validation = config.validate()
        
        XCTAssertTrue(validation.isValid, "有效配置应该通过验证")
        XCTAssertTrue(validation.warnings.isEmpty, "有效配置不应该有警告")
    }
    
    /// 测试矛盾配置 - 图片类型 + 视频时长
    func testConflictingConfiguration_ImageWithDuration() {
        var config = FilterConfiguration()
        config.contentType = .screenshots  // 图片类型
        config.durationFilter = .shortVideos  // 视频时长
        
        let validation = config.validate()
        
        XCTAssertFalse(validation.isValid, "矛盾配置应该验证失败")
        XCTAssertFalse(validation.warnings.isEmpty, "矛盾配置应该有警告")
        XCTAssertTrue(validation.warnings.first?.contains("图片类型不支持视频时长") ?? false, "应该提示图片不支持时长过滤")
        XCTAssertFalse(validation.suggestions.isEmpty, "应该提供修复建议")
    }
    
    /// 测试矛盾配置 - 各种图片类型 + 视频时长
    func testConflictingConfiguration_AllImageTypesWithDuration() {
        let imageTypes: [ContentType] = [.screenshots, .selfies, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        
        for imageType in imageTypes {
            var config = FilterConfiguration()
            config.contentType = imageType
            config.durationFilter = .longVideos
            
            let validation = config.validate()
            
            XCTAssertFalse(validation.isValid, "\(imageType.rawValue) + 时长过滤应该验证失败")
            XCTAssertTrue(validation.warnings.first?.contains("图片类型不支持视频时长") ?? false)
        }
    }
    
    /// 测试视频类型 + 时长过滤（应该有效）
    func testValidConfiguration_VideoWithDuration() {
        let videoTypes: [ContentType] = [.videos, .slowMotionVideos, .timelapseVideos]
        
        for videoType in videoTypes {
            var config = FilterConfiguration()
            config.contentType = videoType
            config.durationFilter = .shortVideos
            
            let validation = config.validate()
            
            XCTAssertTrue(validation.isValid, "\(videoType.rawValue) + 时长过滤应该有效")
        }
    }
    
    /// 测试自拍配置的建议
    func testSelfieConfigurationSuggestion() {
        var config = FilterConfiguration()
        config.contentType = .selfies
        
        let validation = config.validate()
        
        XCTAssertFalse(validation.suggestions.isEmpty, "自拍配置应该有建议提示")
        XCTAssertTrue(validation.suggestions.first?.contains("启发式规则") ?? false, "应该提示自拍检测的准确度")
        XCTAssertTrue(validation.suggestions.first?.contains("70%") ?? false, "应该提示准确度数值")
    }
    
    /// 测试连拍 + 近期日期的建议
    func testBurstWithRecentDateSuggestion() {
        var config = FilterConfiguration()
        config.contentType = .bursts
        config.dateRange = .recent7Days
        
        let validation = config.validate()
        
        XCTAssertFalse(validation.suggestions.isEmpty, "连拍 + 近期应该有建议")
        XCTAssertTrue(validation.suggestions.first?.contains("连拍照片可能较少") ?? false)
    }
    
    // MARK: - Codable 测试
    
    /// 测试配置序列化和反序列化
    func testConfigurationCodable() throws {
        var originalConfig = FilterConfiguration()
        originalConfig.contentType = .screenshots
        originalConfig.dateRange = .recent30Days
        originalConfig.locationFilter = .withLocation
        originalConfig.durationFilter = .shortVideos
        originalConfig.excludeHidden = false
        originalConfig.excludeFavorite = true
        
        // 编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalConfig)
        
        // 解码
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(FilterConfiguration.self, from: data)
        
        // 验证
        XCTAssertEqual(decodedConfig.contentType, originalConfig.contentType)
        XCTAssertEqual(decodedConfig.dateRange, originalConfig.dateRange)
        XCTAssertEqual(decodedConfig.locationFilter, originalConfig.locationFilter)
        XCTAssertEqual(decodedConfig.durationFilter, originalConfig.durationFilter)
        XCTAssertEqual(decodedConfig.excludeHidden, originalConfig.excludeHidden)
        XCTAssertEqual(decodedConfig.excludeFavorite, originalConfig.excludeFavorite)
    }
    
    /// 测试最小配置的序列化
    func testMinimalConfigurationCodable() throws {
        let config = FilterConfiguration()  // 使用默认值
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(FilterConfiguration.self, from: data)
        
        XCTAssertEqual(decodedConfig, config, "默认配置应该能正确序列化和反序列化")
    }
    
    /// 测试复杂配置的序列化
    func testComplexConfigurationCodable() throws {
        var config = FilterConfiguration()
        config.contentType = .slowMotionVideos
        config.dateRange = .older1Year
        config.locationFilter = .withoutLocation
        config.durationFilter = .longVideos
        config.excludeHidden = true
        config.excludeFavorite = false
        
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(FilterConfiguration.self, from: data)
        
        XCTAssertEqual(decoded, config, "复杂配置应该能正确序列化")
    }
    
    // MARK: - Equatable 测试
    
    /// 测试配置相等性
    func testConfigurationEquality() {
        var config1 = FilterConfiguration()
        config1.contentType = .screenshots
        config1.dateRange = .recent30Days
        
        var config2 = FilterConfiguration()
        config2.contentType = .screenshots
        config2.dateRange = .recent30Days
        
        XCTAssertEqual(config1, config2, "相同配置应该相等")
    }
    
    /// 测试配置不相等
    func testConfigurationInequality() {
        var config1 = FilterConfiguration()
        config1.contentType = .screenshots
        
        var config2 = FilterConfiguration()
        config2.contentType = .videos
        
        XCTAssertNotEqual(config1, config2, "不同配置应该不相等")
    }
    
    // MARK: - 组合配置测试
    
    /// 测试所有内容类型
    func testAllContentTypes() {
        let allTypes = ContentType.allCases
        
        XCTAssertGreaterThan(allTypes.count, 0, "应该有至少一个内容类型")
        
        for type in allTypes {
            var config = FilterConfiguration()
            config.contentType = type
            
            // 验证每个类型都能生成有效的摘要
            XCTAssertFalse(config.summary.isEmpty, "\(type.rawValue) 应该能生成摘要")
            
            // 验证每个类型都有图标
            XCTAssertFalse(type.icon.isEmpty, "\(type.rawValue) 应该有图标")
            
            // 验证每个类型都有描述
            XCTAssertFalse(type.description.isEmpty, "\(type.rawValue) 应该有描述")
        }
    }
    
    /// 测试所有日期范围
    func testAllDateRanges() {
        let allRanges = DateRangeType.allCases
        
        XCTAssertGreaterThan(allRanges.count, 0, "应该有至少一个日期范围")
        
        for range in allRanges {
            var config = FilterConfiguration()
            config.dateRange = range
            
            // 验证每个日期范围都能生成摘要
            XCTAssertTrue(config.summary.contains(range.rawValue), "摘要应该包含日期范围")
            
            // 验证每个日期范围都有图标
            XCTAssertFalse(range.icon.isEmpty, "\(range.rawValue) 应该有图标")
        }
    }
    
    /// 测试所有位置过滤
    func testAllLocationFilters() {
        let allFilters = LocationFilterType.allCases
        
        XCTAssertEqual(allFilters.count, 2, "应该有 2 种位置过滤")
        
        for filter in allFilters {
            var config = FilterConfiguration()
            config.locationFilter = filter
            
            XCTAssertTrue(config.summary.contains(filter.rawValue), "摘要应该包含位置过滤")
        }
    }
    
    /// 测试所有时长过滤
    func testAllDurationFilters() {
        let allFilters = DurationFilterType.allCases
        
        XCTAssertEqual(allFilters.count, 2, "应该有 2 种时长过滤")
        
        for filter in allFilters {
            var config = FilterConfiguration()
            config.contentType = .videos  // 使用视频类型避免警告
            config.durationFilter = filter
            
            XCTAssertTrue(config.summary.contains(filter.rawValue), "摘要应该包含时长过滤")
            XCTAssertFalse(filter.icon.isEmpty, "\(filter.rawValue) 应该有图标")
        }
    }
    
    /// 测试完整组合（所有维度）
    func testFullCombination() {
        var config = FilterConfiguration()
        config.contentType = .slowMotionVideos
        config.dateRange = .older1Year
        config.locationFilter = .withLocation
        config.durationFilter = .longVideos
        config.excludeHidden = true
        config.excludeFavorite = true
        
        let summary = config.summary
        
        XCTAssertTrue(summary.contains("仅慢动作视频"), "应该包含内容类型")
        XCTAssertTrue(summary.contains("1 年前"), "应该包含日期范围")
        XCTAssertTrue(summary.contains("含位置信息"), "应该包含位置过滤")
        XCTAssertTrue(summary.contains("长视频"), "应该包含时长过滤")
        XCTAssertTrue(summary.contains("排除隐藏"), "应该包含排除隐藏")
        XCTAssertTrue(summary.contains("排除收藏"), "应该包含排除收藏")
        
        // 验证使用 AND 逻辑（"且"连接）
        let components = summary.components(separatedBy: " 且 ")
        XCTAssertGreaterThan(components.count, 1, "应该使用'且'分隔多个条件")
    }
    
    // MARK: - 边界情况测试
    
    /// 测试只排除隐藏
    func testOnlyExcludeHidden() {
        var config = FilterConfiguration()
        config.excludeHidden = true
        config.excludeFavorite = false
        
        let summary = config.summary
        
        XCTAssertTrue(summary.contains("排除隐藏"), "应该包含排除隐藏")
        XCTAssertFalse(summary.contains("排除收藏"), "不应该包含排除收藏")
    }
    
    /// 测试只排除收藏
    func testOnlyExcludeFavorite() {
        var config = FilterConfiguration()
        config.excludeHidden = false
        config.excludeFavorite = true
        
        let summary = config.summary
        
        XCTAssertFalse(summary.contains("排除隐藏"), "不应该包含排除隐藏")
        XCTAssertTrue(summary.contains("排除收藏"), "应该包含排除收藏")
    }
    
    /// 测试都不排除
    func testNoExclusions() {
        var config = FilterConfiguration()
        config.excludeHidden = false
        config.excludeFavorite = false
        
        let summary = config.summary
        
        XCTAssertFalse(summary.contains("排除隐藏"), "不应该包含排除隐藏")
        XCTAssertFalse(summary.contains("排除收藏"), "不应该包含排除收藏")
    }
    
    /// 测试空配置（所有默认值）
    func testEmptyConfiguration() {
        var config = FilterConfiguration()
        config.excludeHidden = false
        config.excludeFavorite = false
        
        let summary = config.summary
        
        XCTAssertEqual(summary, "所有媒体", "空配置应该显示'所有媒体'")
    }
    
    // MARK: - 矛盾配置测试集
    
    /// 测试所有图片类型与短视频的矛盾
    func testImageTypesConflictWithShortVideos() {
        let imageTypes: [ContentType] = [.screenshots, .selfies, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        
        for imageType in imageTypes {
            var config = FilterConfiguration()
            config.contentType = imageType
            config.durationFilter = .shortVideos
            
            let validation = config.validate()
            
            XCTAssertFalse(validation.isValid, "\(imageType.rawValue) + 短视频应该冲突")
        }
    }
    
    /// 测试所有图片类型与长视频的矛盾
    func testImageTypesConflictWithLongVideos() {
        let imageTypes: [ContentType] = [.screenshots, .selfies, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        
        for imageType in imageTypes {
            var config = FilterConfiguration()
            config.contentType = imageType
            config.durationFilter = .longVideos
            
            let validation = config.validate()
            
            XCTAssertFalse(validation.isValid, "\(imageType.rawValue) + 长视频应该冲突")
        }
    }
    
    /// 测试视频类型与位置过滤的建议
    func testVideoTypesWithLocationSuggestion() {
        let videoTypes: [ContentType] = [.videos, .slowMotionVideos, .timelapseVideos]
        
        for videoType in videoTypes {
            var config = FilterConfiguration()
            config.contentType = videoType
            config.locationFilter = .withLocation
            
            let validation = config.validate()
            
            // 这不是错误，但应该有建议
            XCTAssertFalse(validation.suggestions.isEmpty, "\(videoType.rawValue) + 位置应该有建议")
            XCTAssertTrue(validation.suggestions.first?.contains("视频的位置信息") ?? false)
        }
    }
    
    // MARK: - 各种组合测试
    
    /// 测试典型场景 1：清理旧截图
    func testScenario_CleanOldScreenshots() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .older1Year
        config.excludeFavorite = true
        
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "清理旧截图的配置应该有效")
        
        let summary = config.summary
        XCTAssertTrue(summary.contains("仅截图"))
        XCTAssertTrue(summary.contains("1 年前"))
        XCTAssertTrue(summary.contains("排除收藏"))
    }
    
    /// 测试典型场景 2：清理带GPS的旧慢动作视频
    func testScenario_CleanOldSlowMotionWithGPS() {
        var config = FilterConfiguration()
        config.contentType = .slowMotionVideos
        config.dateRange = .older1Year
        config.locationFilter = .withLocation
        config.excludeFavorite = true
        
        let validation = config.validate()
        // 应该有位置信息的建议，但仍然有效
        XCTAssertTrue(validation.isValid, "配置应该有效")
        XCTAssertFalse(validation.suggestions.isEmpty, "应该有位置信息建议")
        
        let summary = config.summary
        XCTAssertTrue(summary.contains("仅慢动作视频"))
        XCTAssertTrue(summary.contains("1 年前"))
        XCTAssertTrue(summary.contains("含位置信息"))
    }
    
    /// 测试典型场景 3：清理最近的短视频
    func testScenario_CleanRecentShortVideos() {
        var config = FilterConfiguration()
        config.contentType = .videos
        config.dateRange = .recent7Days
        config.durationFilter = .shortVideos
        config.excludeFavorite = true
        
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "清理短视频的配置应该有效")
        
        let summary = config.summary
        XCTAssertTrue(summary.contains("仅视频"))
        XCTAssertTrue(summary.contains("最近 7 天"))
        XCTAssertTrue(summary.contains("短视频"))
    }
    
    /// 测试典型场景 4：清理无GPS的自拍
    func testScenario_CleanSelfiesWithoutLocation() {
        var config = FilterConfiguration()
        config.contentType = .selfies
        config.dateRange = .older1Year
        config.locationFilter = .withoutLocation
        
        let validation = config.validate()
        // 应该有自拍准确度建议
        XCTAssertFalse(validation.suggestions.isEmpty)
        
        let summary = config.summary
        XCTAssertTrue(summary.contains("仅自拍"))
        XCTAssertTrue(summary.contains("1 年前"))
        XCTAssertTrue(summary.contains("无位置信息"))
    }
    
    // MARK: - 枚举完整性测试
    
    /// 测试 ContentType 枚举的完整性
    func testContentTypeEnumCompleteness() {
        let expectedTypes: [ContentType] = [
            .all, .screenshots, .selfies, .panoramas, .livePhotos,
            .portraits, .bursts, .videos, .hdrPhotos,
            .slowMotionVideos, .timelapseVideos
        ]
        
        XCTAssertEqual(ContentType.allCases.count, expectedTypes.count, "ContentType 应该有 \(expectedTypes.count) 个选项")
        
        for type in expectedTypes {
            XCTAssertTrue(ContentType.allCases.contains(type), "应该包含 \(type.rawValue)")
        }
    }
    
    /// 测试 DateRangeType 枚举的完整性
    func testDateRangeTypeEnumCompleteness() {
        let expectedRanges: [DateRangeType] = [
            .recent7Days, .recent30Days, .thisYear,
            .lastYear, .older1Year, .older2Years
        ]
        
        XCTAssertEqual(DateRangeType.allCases.count, expectedRanges.count, "DateRangeType 应该有 \(expectedRanges.count) 个选项")
        
        for range in expectedRanges {
            XCTAssertTrue(DateRangeType.allCases.contains(range), "应该包含 \(range.rawValue)")
        }
    }
    
    /// 测试 LocationFilterType 枚举的完整性
    func testLocationFilterTypeEnumCompleteness() {
        XCTAssertEqual(LocationFilterType.allCases.count, 2, "LocationFilterType 应该有 2 个选项")
        XCTAssertTrue(LocationFilterType.allCases.contains(.withLocation))
        XCTAssertTrue(LocationFilterType.allCases.contains(.withoutLocation))
    }
    
    /// 测试 DurationFilterType 枚举的完整性
    func testDurationFilterTypeEnumCompleteness() {
        XCTAssertEqual(DurationFilterType.allCases.count, 2, "DurationFilterType 应该有 2 个选项")
        XCTAssertTrue(DurationFilterType.allCases.contains(.shortVideos))
        XCTAssertTrue(DurationFilterType.allCases.contains(.longVideos))
    }
    
    // MARK: - 摘要格式测试
    
    /// 测试摘要不包含"所有媒体"当设置了具体类型
    func testSummaryExcludesAllWhenSpecificTypeSet() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        
        let summary = config.summary
        
        XCTAssertFalse(summary.contains("所有媒体"), "设置具体类型后不应该显示'所有媒体'")
        XCTAssertTrue(summary.contains("仅截图"), "应该显示具体的类型")
    }
    
    /// 测试摘要分隔符一致性
    func testSummarySeparatorConsistency() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        
        let summary = config.summary
        
        // 验证使用 "且" 分隔
        let parts = summary.components(separatedBy: " 且 ")
        XCTAssertGreaterThan(parts.count, 1, "多个条件应该使用'且'分隔")
    }
    
    // MARK: - 压力测试
    
    /// 测试极端配置 - 所有可选维度都设置
    func testExtremeConfiguration_AllDimensionsSet() {
        var config = FilterConfiguration()
        config.contentType = .slowMotionVideos
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        config.durationFilter = .longVideos
        config.excludeHidden = true
        config.excludeFavorite = true
        
        // 应该能正常工作
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "所有维度都设置的配置应该有效")
        
        let summary = config.summary
        XCTAssertFalse(summary.isEmpty, "应该生成有效的摘要")
        
        // 应该能序列化
        XCTAssertNoThrow(try JSONEncoder().encode(config), "应该能序列化")
    }
    
    /// 测试极端配置 - 最小配置
    func testExtremeConfiguration_MinimalConfig() {
        var config = FilterConfiguration()
        config.excludeHidden = false
        config.excludeFavorite = false
        // 只有 contentType = .all
        
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "最小配置应该有效")
        
        let summary = config.summary
        XCTAssertEqual(summary, "所有媒体", "最小配置应该显示'所有媒体'")
    }
    
    // MARK: - 逻辑一致性测试
    
    /// 测试多次设置相同值的幂等性
    func testIdempotency() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.contentType = .screenshots  // 设置两次
        
        XCTAssertEqual(config.contentType, .screenshots, "多次设置相同值应该幂等")
    }
    
    /// 测试配置重置
    func testConfigurationReset() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        
        // 重置为默认值
        config = FilterConfiguration()
        
        XCTAssertEqual(config.contentType, .all)
        XCTAssertNil(config.dateRange)
        XCTAssertNil(config.locationFilter)
    }
    
    // MARK: - 特殊场景测试
    
    /// 测试连拍 + 各种日期组合
    func testBurstsWithVariousDateRanges() {
        let dateRanges: [DateRangeType?] = [nil, .recent7Days, .recent30Days, .thisYear, .lastYear, .older1Year, .older2Years]
        
        for dateRange in dateRanges {
            var config = FilterConfiguration()
            config.contentType = .bursts
            config.dateRange = dateRange
            
            let validation = config.validate()
            
            if dateRange == .recent7Days {
                XCTAssertFalse(validation.suggestions.isEmpty, "连拍 + 最近7天应该有建议")
            } else {
                XCTAssertTrue(validation.isValid, "连拍 + \(dateRange?.rawValue ?? "无日期") 应该有效")
            }
        }
    }
    
    /// 测试自拍 + 各种组合
    func testSelfiesWithVariousCombinations() {
        let combinations: [(DateRangeType?, LocationFilterType?)] = [
            (nil, nil),
            (.recent30Days, nil),
            (nil, .withLocation),
            (.older1Year, .withoutLocation)
        ]
        
        for (dateRange, locationFilter) in combinations {
            var config = FilterConfiguration()
            config.contentType = .selfies
            config.dateRange = dateRange
            config.locationFilter = locationFilter
            
            let validation = config.validate()
            
            // 自拍总是应该有准确度提示
            XCTAssertFalse(validation.suggestions.isEmpty, "自拍应该有准确度建议")
            XCTAssertTrue(validation.suggestions.first?.contains("70%") ?? false)
        }
    }
    
    /// 测试视频 + 时长的有效组合
    func testValidVideoWithDurationCombinations() {
        let videoTypes: [ContentType] = [.videos, .slowMotionVideos, .timelapseVideos]
        let durations: [DurationFilterType] = [.shortVideos, .longVideos]
        
        for videoType in videoTypes {
            for duration in durations {
                var config = FilterConfiguration()
                config.contentType = videoType
                config.durationFilter = duration
                
                let validation = config.validate()
                
                XCTAssertTrue(validation.isValid, "\(videoType.rawValue) + \(duration.rawValue) 应该有效")
            }
        }
    }
    
    // MARK: - 性能测试
    
    /// 测试配置验证性能
    func testValidationPerformance() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        config.durationFilter = .shortVideos  // 故意设置矛盾配置
        
        measure {
            for _ in 0..<1000 {
                _ = config.validate()
            }
        }
    }
    
    /// 测试摘要生成性能
    func testSummaryGenerationPerformance() {
        var config = FilterConfiguration()
        config.contentType = .slowMotionVideos
        config.dateRange = .older1Year
        config.locationFilter = .withLocation
        config.durationFilter = .longVideos
        
        measure {
            for _ in 0..<1000 {
                _ = config.summary
            }
        }
    }
    
    /// 测试序列化性能
    func testSerializationPerformance() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        
        measure {
            for _ in 0..<1000 {
                _ = try? JSONEncoder().encode(config)
            }
        }
    }
    
    // MARK: - 回归测试
    
    /// 测试修复后的优先级问题
    func testNoPriorityLoss() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        config.durationFilter = nil  // 不应该影响其他维度
        
        let summary = config.summary
        
        // 所有设置的维度都应该出现在摘要中
        XCTAssertTrue(summary.contains("仅截图"), "内容类型不应该丢失")
        XCTAssertTrue(summary.contains("最近 30 天"), "日期范围不应该丢失")
        XCTAssertTrue(summary.contains("含位置信息"), "位置过滤不应该丢失")
    }
    
    /// 测试修复后的连拍识别
    func testBurstIdentifierFix() {
        var config = FilterConfiguration()
        config.contentType = .bursts
        
        // 验证配置包含连拍
        let summary = config.summary
        XCTAssertTrue(summary.contains("仅连拍照片"))
        
        // 验证不会与其他维度冲突
        config.dateRange = .recent30Days
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "连拍 + 日期应该有效")
    }
}

