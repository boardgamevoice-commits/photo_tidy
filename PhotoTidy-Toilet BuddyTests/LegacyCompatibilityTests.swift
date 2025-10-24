//
//  LegacyCompatibilityTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//

import XCTest
import Photos
@testable import PhotoTidy_Toilet_Buddy

/// 旧版 ContentFilterType 的兼容性测试
class LegacyCompatibilityTests: XCTestCase {
    
    // MARK: - ContentFilterType 基础测试
    
    func testContentFilterType_AllCasesCount() {
        let allCases = ContentFilterType.allCases
        XCTAssertEqual(allCases.count, 22, "ContentFilterType 应该有 22 个选项")
    }
    
    func testContentFilterType_AllHaveIcons() {
        for filter in ContentFilterType.allCases {
            XCTAssertFalse(filter.icon.isEmpty, "\(filter.displayName) 应该有图标")
        }
    }
    
    func testContentFilterType_AllHaveDescriptions() {
        for filter in ContentFilterType.allCases {
            XCTAssertFalse(filter.description.isEmpty, "\(filter.displayName) 应该有描述")
        }
    }
    
    // MARK: - getSubtypes() 测试
    
    func testGetSubtypes_Screenshots() {
        let filter = ContentFilterType.screenshots
        let subtypes = filter.getSubtypes()
        
        XCTAssertEqual(subtypes.count, 1)
        XCTAssertTrue(subtypes.contains(.photoScreenshot))
    }
    
    func testGetSubtypes_Panoramas() {
        let filter = ContentFilterType.panoramas
        let subtypes = filter.getSubtypes()
        
        XCTAssertEqual(subtypes.count, 1)
        XCTAssertTrue(subtypes.contains(.photoPanorama))
    }
    
    func testGetSubtypes_LivePhotos() {
        let filter = ContentFilterType.livePhotos
        let subtypes = filter.getSubtypes()
        
        XCTAssertEqual(subtypes.count, 1)
        XCTAssertTrue(subtypes.contains(.photoLive))
    }
    
    func testGetSubtypes_Portraits() {
        let filter = ContentFilterType.portraits
        let subtypes = filter.getSubtypes()
        
        XCTAssertEqual(subtypes.count, 1)
        XCTAssertTrue(subtypes.contains(.photoDepthEffect))
    }
    
    func testGetSubtypes_HDR() {
        let filter = ContentFilterType.hdrPhotos
        let subtypes = filter.getSubtypes()
        
        XCTAssertEqual(subtypes.count, 1)
        XCTAssertTrue(subtypes.contains(.photoHDR))
    }
    
    func testGetSubtypes_SlowMotion() {
        let filter = ContentFilterType.slowMotionVideos
        let subtypes = filter.getSubtypes()
        
        XCTAssertEqual(subtypes.count, 1)
        XCTAssertTrue(subtypes.contains(.videoHighFrameRate))
    }
    
    func testGetSubtypes_Timelapse() {
        let filter = ContentFilterType.timelapseVideos
        let subtypes = filter.getSubtypes()
        
        XCTAssertEqual(subtypes.count, 1)
        XCTAssertTrue(subtypes.contains(.videoTimelapse))
    }
    
    func testGetSubtypes_ReturnsEmptyForSpecialTypes() {
        // 需要特殊处理的类型应该返回空数组
        let specialTypes: [ContentFilterType] = [.all, .bursts, .videos]
        
        for type in specialTypes {
            let subtypes = type.getSubtypes()
            XCTAssertTrue(subtypes.isEmpty, "\(type.displayName) 应该返回空数组（使用特殊逻辑）")
        }
    }
    
    // MARK: - requiresMediaTypeFilter() 测试
    
    func testRequiresMediaTypeFilter_Videos() {
        let videoTypes: [ContentFilterType] = [.videos, .slowMotionVideos, .timelapseVideos, .shortVideos, .longVideos]
        
        for type in videoTypes {
            let mediaType = type.requiresMediaTypeFilter()
            XCTAssertEqual(mediaType, .video, "\(type.displayName) 应该要求视频类型")
        }
    }
    
    func testRequiresMediaTypeFilter_NonVideos() {
        let nonVideoTypes: [ContentFilterType] = [.all, .screenshots, .panoramas, .livePhotos, .portraits, .hdrPhotos, .bursts]
        
        for type in nonVideoTypes {
            let mediaType = type.requiresMediaTypeFilter()
            XCTAssertNil(mediaType, "\(type.displayName) 不应该要求特定媒体类型")
        }
    }
    
    // MARK: - 特殊标志测试
    
    func testIsSelfieFilter() {
    }
    
    func testIsBurstFilter() {
        XCTAssertTrue(ContentFilterType.bursts.isBurstFilter)
        
        for type in ContentFilterType.allCases where type != .bursts {
            XCTAssertFalse(type.isBurstFilter, "\(type.displayName) 不应该标记为连拍过滤")
        }
    }
    
    // MARK: - getDateFilter() 测试
    
    func testGetDateFilter_RecentDays() {
        let filter = ContentFilterType.recent7Days
        let dateFilter = filter.getDateFilter()
        
        XCTAssertNotNil(dateFilter)
        XCTAssertNotNil(dateFilter?.startDate)
        XCTAssertNotNil(dateFilter?.endDate)
    }
    
    func testGetDateFilter_OlderYears() {
        let filter = ContentFilterType.older1Year
        let dateFilter = filter.getDateFilter()
        
        XCTAssertNotNil(dateFilter)
        XCTAssertNil(dateFilter?.startDate, "旧照片不应该有开始日期限制")
        XCTAssertNotNil(dateFilter?.endDate, "旧照片应该有结束日期")
    }
    
    func testGetDateFilter_ReturnsNilForNonDateTypes() {
        let nonDateTypes: [ContentFilterType] = [.all, .screenshots, .videos]
        
        for type in nonDateTypes {
            let dateFilter = type.getDateFilter()
            XCTAssertNil(dateFilter, "\(type.displayName) 不应该有日期过滤")
        }
    }
    
    // MARK: - locationFilterType 测试
    
    func testLocationFilterType_WithLocation() {
        let filter = ContentFilterType.photosWithLocation
        XCTAssertEqual(filter.locationFilterType, .withLocation)
    }
    
    func testLocationFilterType_WithoutLocation() {
        let filter = ContentFilterType.photosWithoutLocation
        XCTAssertEqual(filter.locationFilterType, .withoutLocation)
    }
    
    func testLocationFilterType_ReturnsNilForNonLocationTypes() {
        let nonLocationTypes: [ContentFilterType] = [.all, .screenshots, .videos]
        
        for type in nonLocationTypes {
            XCTAssertNil(type.locationFilterType, "\(type.displayName) 不应该有位置过滤")
        }
    }
    
    // MARK: - getDurationFilter() 测试
    
    func testGetDurationFilter_ShortVideos() {
        let filter = ContentFilterType.shortVideos
        let durationFilter = filter.getDurationFilter()
        
        XCTAssertNotNil(durationFilter)
        XCTAssertNil(durationFilter?.minDuration)
        XCTAssertEqual(durationFilter?.maxDuration, 30.0)
    }
    
    func testGetDurationFilter_LongVideos() {
        let filter = ContentFilterType.longVideos
        let durationFilter = filter.getDurationFilter()
        
        XCTAssertNotNil(durationFilter)
        XCTAssertEqual(durationFilter?.minDuration, 300.0)
        XCTAssertNil(durationFilter?.maxDuration)
    }
    
    func testGetDurationFilter_ReturnsNilForNonDurationTypes() {
        let nonDurationTypes: [ContentFilterType] = [.all, .screenshots, .videos]
        
        for type in nonDurationTypes {
            let durationFilter = type.getDurationFilter()
            XCTAssertNil(durationFilter, "\(type.displayName) 不应该有时长过滤")
        }
    }
    
    // MARK: - 布尔标志测试
    
    func testNeedsDateFilter() {
        let dateTypes: [ContentFilterType] = [.recent7Days, .recent30Days, .thisYear, .lastYear, .older1Year, .older2Years]
        
        for type in dateTypes {
            XCTAssertTrue(type.needsDateFilter, "\(type.displayName) 应该需要日期过滤")
        }
        
        let nonDateTypes: [ContentFilterType] = [.all, .screenshots, .videos]
        for type in nonDateTypes {
            XCTAssertFalse(type.needsDateFilter, "\(type.displayName) 不应该需要日期过滤")
        }
    }
    
    func testNeedsLocationFilter() {
        let locationTypes: [ContentFilterType] = [.photosWithLocation, .photosWithoutLocation]
        
        for type in locationTypes {
            XCTAssertTrue(type.needsLocationFilter, "\(type.displayName) 应该需要位置过滤")
        }
    }
    
    func testNeedsDurationFilter() {
        let durationTypes: [ContentFilterType] = [.shortVideos, .longVideos]
        
        for type in durationTypes {
            XCTAssertTrue(type.needsDurationFilter, "\(type.displayName) 应该需要时长过滤")
        }
    }
    
    // MARK: - Identifiable 测试
    
    func testContentFilterType_Identifiable() {
        for filter in ContentFilterType.allCases {
            XCTAssertEqual(filter.id, filter.rawValue, "ID 应该等于 rawValue")
        }
    }
    
    func testContentFilterType_UniqueIDs() {
        let ids = ContentFilterType.allCases.map { $0.id }
        let uniqueIDs = Set(ids)
        
        XCTAssertEqual(ids.count, uniqueIDs.count, "所有 ID 应该唯一")
    }
    
    // MARK: - 完整性检查
    
    func testContentFilterType_CoversAllContentTypes() {
        // 验证新的 ContentType 都有对应的 ContentFilterType
        let contentTypes: [ContentType] = [.all, .screenshots, .panoramas, .livePhotos, .portraits, .bursts, .videos, .hdrPhotos, .slowMotionVideos, .timelapseVideos]
        
        for contentType in contentTypes {
            // 应该能找到对应的 ContentFilterType
            let found = ContentFilterType.allCases.contains { filter in
                filter.displayName == contentType.rawValue
            }
            
            XCTAssertTrue(found || contentType == .all, "\(contentType.rawValue) 应该有对应的 ContentFilterType")
        }
    }
    
    func testContentFilterType_CoversAllDateRanges() {
        let dateRanges: [DateRangeType] = [.recent7Days, .recent30Days, .thisYear, .lastYear, .older1Year, .older2Years]
        
        for dateRange in dateRanges {
            let found = ContentFilterType.allCases.contains { filter in
                filter.displayName == dateRange.rawValue
            }
            
            XCTAssertTrue(found, "\(dateRange.rawValue) 应该有对应的 ContentFilterType")
        }
    }
}

