//
//  PredicateBuilder.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  Centralized predicate building logic to eliminate code duplication
//

import Foundation
import Photos

/// 统一的 Predicate 构建器
/// 用于消除 PhotoService 和 TidySessionViewModel 中的重复代码
class PredicateBuilder {
    
    // MARK: - Content Type Predicates
    
    /// 构建内容类型过滤 Predicates
    static func buildContentTypePredicates(_ contentType: ContentType) -> [NSPredicate] {
        var predicates: [NSPredicate] = []
        
        switch contentType {
        case .all:
            // 所有媒体：图片和视频
            let mediaTypePredicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                                PHAssetMediaType.image.rawValue,
                                                PHAssetMediaType.video.rawValue)
            predicates.append(mediaTypePredicate)
            print("  ✓ 内容类型：所有媒体")
            
        case .videos, .slowMotionVideos, .timelapseVideos:
            // 视频类型
            let videoPredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            predicates.append(videoPredicate)
            
            // 视频子类型
            if contentType == .slowMotionVideos {
                let slowMoPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.videoHighFrameRate.rawValue)
                predicates.append(slowMoPredicate)
                print("  ✓ 内容类型：慢动作视频")
            } else if contentType == .timelapseVideos {
                let timelapsePredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.videoTimelapse.rawValue)
                predicates.append(timelapsePredicate)
                print("  ✓ 内容类型：延时摄影")
            } else {
                print("  ✓ 内容类型：所有视频")
            }
            
        case .screenshots:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let screenshotPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
            predicates.append(contentsOf: [imagePredicate, screenshotPredicate])
            print("  ✓ 内容类型：截图")
            
        case .panoramas:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let panoramaPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoPanorama.rawValue)
            predicates.append(contentsOf: [imagePredicate, panoramaPredicate])
            print("  ✓ 内容类型：全景照片")
            
        case .livePhotos:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let livePredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoLive.rawValue)
            predicates.append(contentsOf: [imagePredicate, livePredicate])
            print("  ✓ 内容类型：Live Photo")
            
        case .portraits:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let portraitPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoDepthEffect.rawValue)
            predicates.append(contentsOf: [imagePredicate, portraitPredicate])
            print("  ✓ 内容类型：人像模式")
            
        case .hdrPhotos:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let hdrPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoHDR.rawValue)
            predicates.append(contentsOf: [imagePredicate, hdrPredicate])
            print("  ✓ 内容类型：HDR 照片")
            
        case .bursts:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            // 使用 burstIdentifier 而不是 representsBurst，包含所有连拍照片
            let burstPredicate = NSPredicate(format: "burstIdentifier != nil")
            predicates.append(contentsOf: [imagePredicate, burstPredicate])
            print("  ✓ 内容类型：连拍照片（所有连拍）")
            
        case .selfies:
            // 自拍需要图片类型 + 后置过滤
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            predicates.append(imagePredicate)
            print("  ✓ 内容类型：自拍（需后置过滤）")
        }
        
        return predicates
    }
    
    // MARK: - Date Range Predicates
    
    /// 构建日期范围过滤 Predicates
    static func buildDateRangePredicates(_ dateRange: DateRangeType?) -> [NSPredicate]? {
        guard let dateRange = dateRange else { return nil }
        
        var predicates: [NSPredicate] = []
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        
        switch dateRange {
        case .recent7Days:
            if let startDate = calendar.date(byAdding: .day, value: -7, to: now) {
                let predicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：最近 7 天")
            }
            
        case .recent30Days:
            if let startDate = calendar.date(byAdding: .day, value: -30, to: now) {
                let predicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：最近 30 天")
            }
            
        case .thisYear:
            // 明确指定年月日
            if let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) {
                let predicate = NSPredicate(format: "creationDate >= %@", startOfYear as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：今年")
            }
            
        case .lastYear:
            // 使用明确的边界，避免包含今年第一天
            let lastYearStart = calendar.date(from: DateComponents(year: currentYear - 1, month: 1, day: 1))
            let lastYearEnd = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))?.addingTimeInterval(-1)
            
            if let start = lastYearStart {
                predicates.append(NSPredicate(format: "creationDate >= %@", start as NSDate))
            }
            if let end = lastYearEnd {
                predicates.append(NSPredicate(format: "creationDate <= %@", end as NSDate))
            }
            print("  ✓ 日期范围：去年")
            
        case .older1Year:
            if let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now) {
                let predicate = NSPredicate(format: "creationDate < %@", oneYearAgo as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：1 年前")
            }
            
        case .older2Years:
            if let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: now) {
                let predicate = NSPredicate(format: "creationDate < %@", twoYearsAgo as NSDate)
                predicates.append(predicate)
                print("  ✓ 日期范围：2 年前")
            }
        }
        
        return predicates.isEmpty ? nil : predicates
    }
    
    // MARK: - Location Predicates
    
    /// 构建位置信息过滤 Predicate
    static func buildLocationPredicate(_ locationFilter: LocationFilterType?) -> NSPredicate? {
        guard let locationFilter = locationFilter else { return nil }
        
        switch locationFilter {
        case .withLocation:
            print("  ✓ 位置信息：含位置信息")
            return NSPredicate(format: "location != nil")
        case .withoutLocation:
            print("  ✓ 位置信息：无位置信息")
            return NSPredicate(format: "location == nil")
        }
    }
    
    // MARK: - Duration Predicates
    
    /// 构建视频时长过滤 Predicates
    static func buildDurationPredicates(_ durationFilter: DurationFilterType?) -> [NSPredicate]? {
        guard let durationFilter = durationFilter else { return nil }
        
        var predicates: [NSPredicate] = []
        
        switch durationFilter {
        case .shortVideos:
            let predicate = NSPredicate(format: "duration > 0 AND duration <= %f", 30.0)
            predicates.append(predicate)
            print("  ✓ 视频时长：短视频 (<30秒)")
            
        case .longVideos:
            let predicate = NSPredicate(format: "duration >= %f", 300.0)
            predicates.append(predicate)
            print("  ✓ 视频时长：长视频 (>5分钟)")
        }
        
        return predicates.isEmpty ? nil : predicates
    }
    
    // MARK: - Combined Predicate Builder
    
    /// 构建完整的组合 Predicate
    /// - Parameter filterConfig: 过滤配置
    /// - Returns: 组合后的 NSPredicate
    static func buildCombinedPredicate(from filterConfig: FilterConfiguration) -> NSPredicate {
        var predicates: [NSPredicate] = []
        
        print("🔍 开始构建过滤条件：\(filterConfig.summary)")
        
        // 维度 1: 内容类型
        predicates.append(contentsOf: buildContentTypePredicates(filterConfig.contentType))
        
        // 维度 2: 日期范围
        if let datePredicates = buildDateRangePredicates(filterConfig.dateRange) {
            predicates.append(contentsOf: datePredicates)
        }
        
        // 维度 3: 位置信息
        if let locationPredicate = buildLocationPredicate(filterConfig.locationFilter) {
            predicates.append(locationPredicate)
        }
        
        // 维度 4: 视频时长
        if let durationPredicates = buildDurationPredicates(filterConfig.durationFilter) {
            predicates.append(contentsOf: durationPredicates)
        }
        
        // 维度 5: 其他过滤
        if filterConfig.excludeHidden {
            let notHiddenPredicate = NSPredicate(format: "isHidden == NO")
            predicates.append(notHiddenPredicate)
            print("  ✓ 排除隐藏")
        }
        
        if filterConfig.excludeFavorite {
            let notFavoritePredicate = NSPredicate(format: "isFavorite == NO")
            predicates.append(notFavoritePredicate)
            print("  ✓ 排除收藏")
        }
        
        print("📊 总共应用了 \(predicates.count) 个过滤条件")
        
        // 使用 AND 连接所有维度
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

