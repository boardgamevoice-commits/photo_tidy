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
            AppLogger.shared.debug("内容类型：所有媒体", category: .photo)
            
        case .videos, .slowMotionVideos, .timelapseVideos:
            // 视频类型
            let videoPredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            predicates.append(videoPredicate)
            
            // 视频子类型
            if contentType == .slowMotionVideos {
                let slowMoPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.videoHighFrameRate.rawValue)
                predicates.append(slowMoPredicate)
                AppLogger.shared.debug("内容类型：慢动作视频", category: .media)
            } else if contentType == .timelapseVideos {
                let timelapsePredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.videoTimelapse.rawValue)
                predicates.append(timelapsePredicate)
                AppLogger.shared.debug("内容类型：延时摄影", category: .media)
            } else {
                AppLogger.shared.debug("内容类型：所有视频", category: .media)
            }
            
        case .screenshots:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let screenshotPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
            predicates.append(contentsOf: [imagePredicate, screenshotPredicate])
            AppLogger.shared.debug("内容类型：截图", category: .photo)
            
        case .panoramas:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let panoramaPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoPanorama.rawValue)
            predicates.append(contentsOf: [imagePredicate, panoramaPredicate])
            AppLogger.shared.debug("内容类型：全景照片", category: .photo)
            
        case .livePhotos:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let livePredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoLive.rawValue)
            predicates.append(contentsOf: [imagePredicate, livePredicate])
            AppLogger.shared.debug("内容类型：Live Photo", category: .media)
            
        case .portraits:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let portraitPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoDepthEffect.rawValue)
            predicates.append(contentsOf: [imagePredicate, portraitPredicate])
            AppLogger.shared.debug("内容类型：人像模式", category: .photo)
            
        case .hdrPhotos:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            let hdrPredicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoHDR.rawValue)
            predicates.append(contentsOf: [imagePredicate, hdrPredicate])
            AppLogger.shared.debug("内容类型：HDR 照片", category: .photo)
            
        case .bursts:
            let imagePredicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            // 使用 burstIdentifier 而不是 representsBurst，包含所有连拍照片
            let burstPredicate = NSPredicate(format: "burstIdentifier != nil")
            predicates.append(contentsOf: [imagePredicate, burstPredicate])
            AppLogger.shared.debug("内容类型：连拍照片（所有连拍）", category: .photo)
            
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
                AppLogger.shared.debug("日期范围：最近 7 天", category: .photo)
            }
            
        case .recent30Days:
            if let startDate = calendar.date(byAdding: .day, value: -30, to: now) {
                let predicate = NSPredicate(format: "creationDate >= %@", startDate as NSDate)
                predicates.append(predicate)
                AppLogger.shared.debug("日期范围：最近 30 天", category: .photo)
            }
            
        case .thisYear:
            // 明确指定年月日
            if let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) {
                let predicate = NSPredicate(format: "creationDate >= %@", startOfYear as NSDate)
                predicates.append(predicate)
                AppLogger.shared.debug("日期范围：今年", category: .photo)
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
            AppLogger.shared.debug("日期范围：去年", category: .photo)
            
        case .older1Year:
            if let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now) {
                let predicate = NSPredicate(format: "creationDate < %@", oneYearAgo as NSDate)
                predicates.append(predicate)
                AppLogger.shared.debug("日期范围：1 年前", category: .photo)
            }
            
        case .older2Years:
            if let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: now) {
                let predicate = NSPredicate(format: "creationDate < %@", twoYearsAgo as NSDate)
                predicates.append(predicate)
                AppLogger.shared.debug("日期范围：2 年前", category: .photo)
            }
        }
        
        return predicates.isEmpty ? nil : predicates
    }
    
    // MARK: - Location Predicates
    
    /// 构建位置信息过滤 Predicate
    /// 注意：PHAsset 的 location 属性不支持在 NSPredicate 中直接使用
    /// 位置信息过滤需要在获取资产后手动进行
    static func buildLocationPredicate(_ locationFilter: LocationFilterType?) -> NSPredicate? {
        guard let locationFilter = locationFilter else { return nil }
        
        // 由于 PHAsset 的 location 属性不支持在 NSPredicate 中使用，
        // 我们返回 nil，位置过滤将在获取资产后进行
        switch locationFilter {
        case .withLocation:
            AppLogger.shared.debug("位置信息：含位置信息（将在后处理中过滤）", category: .photo)
            return nil
        case .withoutLocation:
            AppLogger.shared.debug("位置信息：无位置信息（将在后处理中过滤）", category: .photo)
            return nil
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
            AppLogger.shared.debug("视频时长：短视频 (<30秒)", category: .media)
            
        case .longVideos:
            let predicate = NSPredicate(format: "duration >= %f", 300.0)
            predicates.append(predicate)
            AppLogger.shared.debug("视频时长：长视频 (>5分钟)", category: .media)
        }
        
        return predicates.isEmpty ? nil : predicates
    }
    
    // MARK: - Combined Predicate Builder
    
    /// 构建完整的组合 Predicate
    /// - Parameter filterConfig: 过滤配置
    /// - Returns: 组合后的 NSPredicate
    static func buildCombinedPredicate(from filterConfig: FilterConfiguration) -> NSPredicate {
        var predicates: [NSPredicate] = []
        
        AppLogger.shared.info("开始构建过滤条件：\(filterConfig.summary)", category: .photo)
        
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
            AppLogger.shared.debug("排除隐藏", category: .photo)
        }
        
        if filterConfig.excludeFavorite {
            let notFavoritePredicate = NSPredicate(format: "isFavorite == NO")
            predicates.append(notFavoritePredicate)
            AppLogger.shared.debug("排除收藏", category: .photo)
        }
        
        AppLogger.shared.info("总共应用了 \(predicates.count) 个过滤条件", category: .photo)
        
        // 使用 AND 连接所有维度
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

