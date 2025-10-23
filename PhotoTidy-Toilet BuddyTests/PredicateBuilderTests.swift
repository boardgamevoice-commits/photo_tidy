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
        XCTAssertEqual(predicates.count, 1, "应该有1个predicate用于所有媒体")
        
        // 验证predicate包含图片和视频类型
        let predicate = predicates.first!
        XCTAssertTrue(predicate.predicateFormat.contains("mediaType"))
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
        XCTAssertEqual(predicates.count, 1, "应该有1个predicate用于视频类型")
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
    
    // MARK: - Location Tests
    
    func testBuildLocationPredicate_WithLocation() {
        // Given
        let locationFilter = LocationFilterType.withLocation
        
        // When
        let predicate = PredicateBuilder.buildLocationPredicate(locationFilter)
        
        // Then
        XCTAssertNotNil(predicate)
        XCTAssertTrue(predicate?.predicateFormat.contains("location") ?? false)
    }
    
    func testBuildLocationPredicate_WithoutLocation() {
        // Given
        let locationFilter = LocationFilterType.withoutLocation
        
        // When
        let predicate = PredicateBuilder.buildLocationPredicate(locationFilter)
        
        // Then
        XCTAssertNotNil(predicate)
        XCTAssertTrue(predicate?.predicateFormat.contains("location") ?? false)
    }
    
    func testBuildLocationPredicate_Nil() {
        // Given
        let locationFilter: LocationFilterType? = nil
        
        // When
        let predicate = PredicateBuilder.buildLocationPredicate(locationFilter)
        
        // Then
        XCTAssertNil(predicate, "nil输入应该返回nil")
    }
    
    // MARK: - Duration Tests
    
    func testBuildDurationPredicates_ShortVideos() {
        // Given
        let durationFilter = DurationFilterType.shortVideos
        
        // When
        let predicates = PredicateBuilder.buildDurationPredicates(durationFilter)
        
        // Then
        XCTAssertNotNil(predicates)
        XCTAssertEqual(predicates?.count, 1)
        XCTAssertTrue(predicates?.first?.predicateFormat.contains("duration") ?? false)
    }
    
    func testBuildDurationPredicates_LongVideos() {
        // Given
        let durationFilter = DurationFilterType.longVideos
        
        // When
        let predicates = PredicateBuilder.buildDurationPredicates(durationFilter)
        
        // Then
        XCTAssertNotNil(predicates)
        XCTAssertEqual(predicates?.count, 1)
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
        config.locationFilter = .withLocation
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
        config.locationFilter = .withoutLocation
        config.durationFilter = .shortVideos // 虽然逻辑上矛盾，但应该能构建
        config.excludeHidden = true
        config.excludeFavorite = true
        
        // When
        let predicate = PredicateBuilder.buildCombinedPredicate(from: config)
        
        // Then
        XCTAssertNotNil(predicate)
    }
}

