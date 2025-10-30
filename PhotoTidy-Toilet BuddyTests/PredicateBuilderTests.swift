//
//  PredicateBuilderTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//  测试 PredicateBuilder 工具类
//

import XCTest
import Photos
@testable import PhotoTidy_Toilet_Buddy

final class PredicateBuilderTests: XCTestCase {
    
    // MARK: - Content Type Tests
    
    func testBuildContentTypePredicates_All() {
        // Given
        let contentType = ContentType.all
        
        // When
        let predicates = PredicateBuilder.buildContentTypePredicates(contentType)
        
        // Then
        XCTAssertEqual(predicates.count, 1, "应该有1个predicate用于所有图片（已过滤视频）")
        
        // 验证predicate只包含图片类型
        let predicate = predicates.first!
        XCTAssertTrue(predicate.predicateFormat.contains("mediaType"))
        XCTAssertTrue(predicate.predicateFormat.contains("\(PHAssetMediaType.image.rawValue)"))
    }
    
    func testBuildContentTypePredicates_Screenshots() {
        // Given
        let contentType = ContentType.screenshots
        
        // When
        let predicates = PredicateBuilder.buildContentTypePredicates(contentType)
        
        // Then
        XCTAssertEqual(predicates.count, 2, "应该有2个predicate：图片类型 + 截图子类型")
    }
    
    func testBuildContentTypePredicates_Videos() {
        // Given
        let contentType = ContentType.videos
        
        // When
        let predicates = PredicateBuilder.buildContentTypePredicates(contentType)
        
        // Then
        XCTAssertEqual(predicates.count, 0, "视频类型不再支持，应该返回空数组")
    }
    
    // MARK: - Date Range Tests
    
    func testBuildDateRangePredicates_Recent7Days() {
        // Given
        let dateRange = DateRangeType.recent7Days
        
        // When
        let predicates = PredicateBuilder.buildDateRangePredicates(dateRange)
        
        // Then
        XCTAssertNotNil(predicates, "应该返回predicates")
        XCTAssertEqual(predicates?.count, 1, "应该有1个日期predicate")
        
        // 验证包含creationDate
        let predicate = predicates?.first
        XCTAssertTrue(predicate?.predicateFormat.contains("creationDate") ?? false)
    }
    
    func testBuildDateRangePredicates_Nil() {
        // Given
        let dateRange: DateRangeType? = nil
        
        // When
        let predicates = PredicateBuilder.buildDateRangePredicates(dateRange)
        
        // Then
        XCTAssertNil(predicates, "nil输入应该返回nil")
    }
    
    func testBuildDateRangePredicates_LastYear() {
        // Given
        let dateRange = DateRangeType.lastYear
        
        // When
        let predicates = PredicateBuilder.buildDateRangePredicates(dateRange)
        
        // Then
        XCTAssertNotNil(predicates)
        XCTAssertEqual(predicates?.count, 2, "去年应该有2个predicate：开始日期和结束日期")
    }
    
    // MARK: - Location Tests (已移除)
    
    func testBuildLocationPredicate_WithLocation() {
        // 位置过滤功能已删除，此测试已移除
        // LocationFilterType 和 buildLocationPredicate 方法已删除
    }
    
    func testBuildLocationPredicate_WithoutLocation() {
        // 位置过滤功能已删除，此测试已移除
    }
    
    func testBuildLocationPredicate_Nil() {
        // 位置过滤功能已删除，此测试已移除
    }
    
    // MARK: - Duration Tests (已移除视频支持)
    
    func testBuildDurationPredicates_ShortVideos() {
        // Given
        let durationFilter = DurationFilterType.shortVideos
        
        // When
        let predicates = PredicateBuilder.buildDurationPredicates(durationFilter)
        
        // Then
        XCTAssertNil(predicates, "视频时长过滤不再支持，应该返回nil")
    }
    
    func testBuildDurationPredicates_LongVideos() {
        // Given
        let durationFilter = DurationFilterType.longVideos
        
        // When
        let predicates = PredicateBuilder.buildDurationPredicates(durationFilter)
        
        // Then
        XCTAssertNil(predicates, "视频时长过滤不再支持，应该返回nil")
    }
    
    // MARK: - Combined Predicate Tests
    
    func testBuildCombinedPredicate_DefaultConfig() {
        // Given
        let config = FilterConfiguration()
        
        // When
        let predicate = PredicateBuilder.buildCombinedPredicate(from: config)
        
        // Then
        XCTAssertNotNil(predicate)
        // 默认配置应该包含：内容类型 + excludeHidden + excludeFavorite
        let format = predicate.predicateFormat
        XCTAssertTrue(format.contains("mediaType") || format.contains("AND"))
    }
    
    func testBuildCombinedPredicate_ComplexConfig() {
        // Given
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent7Days
        // config.locationFilter = .withLocation  // 位置过滤已移除
        config.excludeHidden = true
        config.excludeFavorite = true
        
        // When
        let predicate = PredicateBuilder.buildCombinedPredicate(from: config)
        
        // Then
        XCTAssertNotNil(predicate)
        
        // 应该是一个组合predicate
        if let compound = predicate as? NSCompoundPredicate {
            XCTAssertGreaterThan(compound.subpredicates.count, 1, "复杂配置应该有多个子predicate")
        }
    }
    
    // MARK: - Edge Cases
    
    func testBuildCombinedPredicate_OnlyContentType() {
        // Given
        var config = FilterConfiguration()
        config.contentType = .videos
        config.excludeHidden = false
        config.excludeFavorite = false
        
        // When
        let predicate = PredicateBuilder.buildCombinedPredicate(from: config)
        
        // Then
        XCTAssertNotNil(predicate)
    }
    
    func testBuildCombinedPredicate_AllFiltersEnabled() {
        // Given
        var config = FilterConfiguration()
        config.contentType = .livePhotos
        config.dateRange = .thisYear
        // config.locationFilter = .withoutLocation  // 位置过滤已移除
        // durationFilter 已移除（不再支持视频）
        config.excludeHidden = true
        config.excludeFavorite = true
        
        // When
        let predicate = PredicateBuilder.buildCombinedPredicate(from: config)
        
        // Then
        XCTAssertNotNil(predicate)
    }
}

