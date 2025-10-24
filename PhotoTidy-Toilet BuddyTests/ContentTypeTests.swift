//
//  ContentTypeTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//

import XCTest
import Photos
@testable import PhotoTidy_Toilet_Buddy

/// 内容类型和枚举的单元测试
class ContentTypeTests: XCTestCase {
    
    // MARK: - ContentType 基础测试
    
    func testContentType_AllCasesCount() {
        let allTypes = ContentType.allCases
        XCTAssertEqual(allTypes.count, 11, "应该有 11 种内容类型")
    }
    
    func testContentType_AllHaveIcons() {
        for type in ContentType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type.rawValue) 应该有图标")
        }
    }
    
    func testContentType_AllHaveDescriptions() {
        for type in ContentType.allCases {
            XCTAssertFalse(type.description.isEmpty, "\(type.rawValue) 应该有描述")
        }
    }
    
    func testContentType_AllHaveUniqueRawValues() {
        let rawValues = ContentType.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)
        
        XCTAssertEqual(rawValues.count, uniqueValues.count, "所有内容类型应该有唯一的原始值")
    }
    
    // MARK: - ContentType 分类测试
    
    func testContentType_ImageTypes() {
        let imageTypes: [ContentType] = [.screenshots, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        
        XCTAssertEqual(imageTypes.count, 7, "应该有 7 种图片类型")
        
        // 验证这些类型不应该与视频时长组合
        for imageType in imageTypes {
            var config = FilterConfiguration()
            config.contentType = imageType
            config.durationFilter = .shortVideos
            
            let validation = config.validate()
            XCTAssertFalse(validation.isValid, "\(imageType.rawValue) 不应该与时长过滤组合")
        }
    }
    
    func testContentType_VideoTypes() {
        let videoTypes: [ContentType] = [.videos, .slowMotionVideos, .timelapseVideos]
        
        XCTAssertEqual(videoTypes.count, 3, "应该有 3 种视频类型")
        
        // 验证这些类型可以与视频时长组合
        for videoType in videoTypes {
            var config = FilterConfiguration()
            config.contentType = videoType
            config.durationFilter = .shortVideos
            
            let validation = config.validate()
            XCTAssertTrue(validation.isValid, "\(videoType.rawValue) 应该能与时长过滤组合")
        }
    }
    
    // MARK: - DateRangeType 测试
    
    func testDateRangeType_AllCasesCount() {
        let allRanges = DateRangeType.allCases
        XCTAssertEqual(allRanges.count, 6, "应该有 6 种日期范围")
    }
    
    func testDateRangeType_AllHaveIcons() {
        for range in DateRangeType.allCases {
            XCTAssertFalse(range.icon.isEmpty, "\(range.rawValue) 应该有图标")
        }
    }
    
    func testDateRangeType_Codable() throws {
        for range in DateRangeType.allCases {
            let data = try JSONEncoder().encode(range)
            let decoded = try JSONDecoder().decode(DateRangeType.self, from: data)
            XCTAssertEqual(decoded, range, "\(range.rawValue) 应该能正确序列化")
        }
    }
    
    // MARK: - LocationFilterType 测试
    
    func testLocationFilterType_AllCasesCount() {
        let allFilters = LocationFilterType.allCases
        XCTAssertEqual(allFilters.count, 2, "应该有 2 种位置过滤")
    }
    
    func testLocationFilterType_WithAndWithout() {
        XCTAssertTrue(LocationFilterType.allCases.contains(.withLocation))
        XCTAssertTrue(LocationFilterType.allCases.contains(.withoutLocation))
    }
    
    func testLocationFilterType_Codable() throws {
        for filter in LocationFilterType.allCases {
            let data = try JSONEncoder().encode(filter)
            let decoded = try JSONDecoder().decode(LocationFilterType.self, from: data)
            XCTAssertEqual(decoded, filter, "\(filter.rawValue) 应该能正确序列化")
        }
    }
    
    // MARK: - DurationFilterType 测试
    
    func testDurationFilterType_AllCasesCount() {
        let allFilters = DurationFilterType.allCases
        XCTAssertEqual(allFilters.count, 2, "应该有 2 种时长过滤")
    }
    
    func testDurationFilterType_ShortAndLong() {
        XCTAssertTrue(DurationFilterType.allCases.contains(.shortVideos))
        XCTAssertTrue(DurationFilterType.allCases.contains(.longVideos))
    }
    
    func testDurationFilterType_AllHaveIcons() {
        for filter in DurationFilterType.allCases {
            XCTAssertFalse(filter.icon.isEmpty, "\(filter.rawValue) 应该有图标")
        }
    }
    
    func testDurationFilterType_Codable() throws {
        for filter in DurationFilterType.allCases {
            let data = try JSONEncoder().encode(filter)
            let decoded = try JSONDecoder().decode(DurationFilterType.self, from: data)
            XCTAssertEqual(decoded, filter, "\(filter.rawValue) 应该能正确序列化")
        }
    }
    
    // MARK: - 组合逻辑测试
    
    func testContentTypeWithLocation_AllCombinations() {
        for contentType in ContentType.allCases {
            for locationFilter in LocationFilterType.allCases {
                var config = FilterConfiguration()
                config.contentType = contentType
                config.locationFilter = locationFilter
                
                // 应该都能生成有效配置
                XCTAssertNotNil(config.summary, "\(contentType.rawValue) + \(locationFilter.rawValue) 应该有效")
            }
        }
    }
    
    func testContentTypeWithDateRange_AllCombinations() {
        for contentType in ContentType.allCases {
            for dateRange in DateRangeType.allCases {
                var config = FilterConfiguration()
                config.contentType = contentType
                config.dateRange = dateRange
                
                let validation = config.validate()
                // 图片类型 + 日期范围应该都有效
                if !contentType.rawValue.contains("视频") {
                    XCTAssertTrue(validation.isValid, "\(contentType.rawValue) + \(dateRange.rawValue) 应该有效")
                }
            }
        }
    }
    
    // MARK: - 特殊类型测试
    
    
    func testBurstsType_WithRecentDate() {
        var config = FilterConfiguration()
        config.contentType = .bursts
        config.dateRange = .recent7Days
        
        let validation = config.validate()
        
        XCTAssertFalse(validation.suggestions.isEmpty, "连拍 + 近期应该有建议")
        XCTAssertTrue(validation.suggestions.joined().contains("连拍照片可能较少"))
    }
    
    func testVideoTypes_WithLocationHasSuggestion() {
        let videoTypes: [ContentType] = [.videos, .slowMotionVideos, .timelapseVideos]
        
        for videoType in videoTypes {
            var config = FilterConfiguration()
            config.contentType = videoType
            config.locationFilter = .withLocation
            
            let validation = config.validate()
            
            XCTAssertFalse(validation.suggestions.isEmpty, "\(videoType.rawValue) + 位置应该有建议")
            XCTAssertTrue(validation.suggestions.joined().contains("视频的位置信息"))
        }
    }
    
    // MARK: - 枚举 Identifiable 测试
    
    func testContentType_Identifiable() {
        for type in ContentType.allCases {
            XCTAssertEqual(type.id, type.rawValue, "ID 应该等于 rawValue")
        }
    }
    
    func testDateRangeType_Identifiable() {
        for range in DateRangeType.allCases {
            XCTAssertEqual(range.id, range.rawValue, "ID 应该等于 rawValue")
        }
    }
    
    func testLocationFilterType_Identifiable() {
        for filter in LocationFilterType.allCases {
            XCTAssertEqual(filter.id, filter.rawValue, "ID 应该等于 rawValue")
        }
    }
    
    func testDurationFilterType_Identifiable() {
        for filter in DurationFilterType.allCases {
            XCTAssertEqual(filter.id, filter.rawValue, "ID 应该等于 rawValue")
        }
    }
}

