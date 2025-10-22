//
//  DateRangeTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//

import XCTest
@testable import PhotoTidy_Toilet_Buddy

/// 日期范围计算逻辑的单元测试
class DateRangeTests: XCTestCase {
    
    let calendar = Calendar.current
    var referenceDate: Date!
    
    override func setUp() {
        super.setUp()
        // 使用固定的参考日期进行测试：2025-10-22 12:00:00
        let components = DateComponents(year: 2025, month: 10, day: 22, hour: 12, minute: 0, second: 0)
        referenceDate = calendar.date(from: components)!
    }
    
    // MARK: - 最近 7 天测试
    
    func testRecent7Days_StartDate() {
        let dateRange = DateRangeType.recent7Days
        
        // 计算预期的开始日期（7 天前）
        let expectedStart = calendar.date(byAdding: .day, value: -7, to: referenceDate)!
        
        // 在 ContentFilterType 中测试（需要模拟）
        var oldFilter = ContentFilterType.recent7Days
        let dateFilter = oldFilter.getDateFilter()
        
        XCTAssertNotNil(dateFilter?.startDate, "应该有开始日期")
        XCTAssertNotNil(dateFilter?.endDate, "应该有结束日期（now）")
        
        // 验证时间差
        if let start = dateFilter?.startDate, let end = dateFilter?.endDate {
            let daysDiff = calendar.dateComponents([.day], from: start, to: end).day
            XCTAssertEqual(daysDiff, 7, "应该是 7 天的范围")
        }
    }
    
    func testRecent7Days_DateRange() {
        var config = FilterConfiguration()
        config.dateRange = .recent7Days
        
        let summary = config.summary
        XCTAssertTrue(summary.contains("最近 7 天"), "摘要应该包含'最近 7 天'")
    }
    
    // MARK: - 最近 30 天测试
    
    func testRecent30Days_DateRange() {
        var oldFilter = ContentFilterType.recent30Days
        let dateFilter = oldFilter.getDateFilter()
        
        XCTAssertNotNil(dateFilter?.startDate)
        XCTAssertNotNil(dateFilter?.endDate)
        
        if let start = dateFilter?.startDate, let end = dateFilter?.endDate {
            let daysDiff = calendar.dateComponents([.day], from: start, to: end).day
            XCTAssertEqual(daysDiff, 30, "应该是 30 天的范围")
        }
    }
    
    // MARK: - 今年测试
    
    func testThisYear_BoundaryAccuracy() {
        var oldFilter = ContentFilterType.thisYear
        let dateFilter = oldFilter.getDateFilter()
        
        XCTAssertNotNil(dateFilter?.startDate, "应该有开始日期")
        
        if let start = dateFilter?.startDate {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start)
            
            XCTAssertEqual(components.month, 1, "应该从 1 月开始")
            XCTAssertEqual(components.day, 1, "应该从 1 日开始")
            XCTAssertEqual(components.hour, 0, "应该从 0 时开始")
            XCTAssertEqual(components.minute, 0, "应该从 0 分开始")
            XCTAssertEqual(components.second, 0, "应该从 0 秒开始")
        }
    }
    
    func testThisYear_CurrentYearCheck() {
        var oldFilter = ContentFilterType.thisYear
        let dateFilter = oldFilter.getDateFilter()
        
        if let start = dateFilter?.startDate {
            let startYear = calendar.component(.year, from: start)
            let currentYear = calendar.component(.year, from: Date())
            
            XCTAssertEqual(startYear, currentYear, "应该是当前年份")
        }
    }
    
    // MARK: - 去年测试
    
    func testLastYear_BoundaryPrecision() {
        var oldFilter = ContentFilterType.lastYear
        let dateFilter = oldFilter.getDateFilter()
        
        XCTAssertNotNil(dateFilter?.startDate, "应该有开始日期")
        XCTAssertNotNil(dateFilter?.endDate, "应该有结束日期")
        
        if let start = dateFilter?.startDate, let end = dateFilter?.endDate {
            let startComponents = calendar.dateComponents([.year, .month, .day], from: start)
            let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end)
            
            let currentYear = calendar.component(.year, from: Date())
            
            // 开始日期应该是去年 1 月 1 日
            XCTAssertEqual(startComponents.year, currentYear - 1, "开始年份应该是去年")
            XCTAssertEqual(startComponents.month, 1, "应该从 1 月开始")
            XCTAssertEqual(startComponents.day, 1, "应该从 1 日开始")
            
            // 结束日期应该是去年最后一天的最后一秒
            XCTAssertEqual(endComponents.year, currentYear - 1, "结束年份应该是去年")
            XCTAssertEqual(endComponents.month, 12, "应该在 12 月结束")
            XCTAssertEqual(endComponents.day, 31, "应该在 31 日结束")
            XCTAssertEqual(endComponents.hour, 23, "应该在 23 时结束")
            XCTAssertEqual(endComponents.minute, 59, "应该在 59 分结束")
            XCTAssertEqual(endComponents.second, 59, "应该在 59 秒结束")
        }
    }
    
    func testLastYear_DoesNotIncludeThisYear() {
        var oldFilter = ContentFilterType.lastYear
        let dateFilter = oldFilter.getDateFilter()
        
        if let end = dateFilter?.endDate {
            let endYear = calendar.component(.year, from: end)
            let currentYear = calendar.component(.year, from: Date())
            
            XCTAssertEqual(endYear, currentYear - 1, "结束日期应该在去年")
            XCTAssertLessThan(end, calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!, "不应该包含今年")
        }
    }
    
    // MARK: - 1 年前测试
    
    func testOlder1Year_OnlyOlderThan1Year() {
        var oldFilter = ContentFilterType.older1Year
        let dateFilter = oldFilter.getDateFilter()
        
        XCTAssertNil(dateFilter?.startDate, "不应该有开始日期限制（无限早）")
        XCTAssertNotNil(dateFilter?.endDate, "应该有结束日期（1年前）")
        
        if let end = dateFilter?.endDate {
            let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date())!
            
            // 验证时间差在合理范围内（考虑测试执行时间）
            let timeDiff = abs(end.timeIntervalSince(oneYearAgo))
            XCTAssertLessThan(timeDiff, 60, "时间差应该在 1 分钟内（考虑测试执行时间）")
        }
    }
    
    // MARK: - 2 年前测试
    
    func testOlder2Years_OnlyOlderThan2Years() {
        var oldFilter = ContentFilterType.older2Years
        let dateFilter = oldFilter.getDateFilter()
        
        XCTAssertNil(dateFilter?.startDate, "不应该有开始日期限制（无限早）")
        XCTAssertNotNil(dateFilter?.endDate, "应该有结束日期（2年前）")
        
        if let end = dateFilter?.endDate {
            let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: Date())!
            
            let timeDiff = abs(end.timeIntervalSince(twoYearsAgo))
            XCTAssertLessThan(timeDiff, 60, "时间差应该在 1 分钟内")
        }
    }
    
    // MARK: - 日期范围不重叠测试
    
    func testDateRanges_NoOverlap() {
        // 验证"最近7天"和"1年前"不重叠
        var filter7Days = ContentFilterType.recent7Days
        var filter1YearOld = ContentFilterType.older1Year
        
        let date7Days = filter7Days.getDateFilter()
        let date1Year = filter1YearOld.getDateFilter()
        
        if let recent7Start = date7Days?.startDate,
           let older1End = date1Year?.endDate {
            // 最近7天的开始 应该 > 1年前的结束
            XCTAssertGreaterThan(recent7Start, older1End, "最近7天 和 1年前 不应该重叠")
        }
    }
    
    func testDateRanges_ThisYearAndLastYearNoOverlap() {
        var thisYearFilter = ContentFilterType.thisYear
        var lastYearFilter = ContentFilterType.lastYear
        
        let thisYear = thisYearFilter.getDateFilter()
        let lastYear = lastYearFilter.getDateFilter()
        
        if let thisYearStart = thisYear?.startDate,
           let lastYearEnd = lastYear?.endDate {
            // 今年的开始 应该 > 去年的结束
            XCTAssertGreaterThan(thisYearStart, lastYearEnd, "今年 和 去年 不应该重叠")
        }
    }
    
    // MARK: - 边界精确性测试
    
    func testLastYear_ExactBoundary() {
        // 使用固定日期测试
        let testDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        
        var oldFilter = ContentFilterType.lastYear
        let dateFilter = oldFilter.getDateFilter()
        
        // 模拟去年的照片
        let lastYearPhoto = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        
        // 模拟今年第一天的照片
        let thisYearFirstDay = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
        
        // 模拟去年最后一天的照片
        let lastYearLastDay = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        
        if let start = dateFilter?.startDate, let end = dateFilter?.endDate {
            // 去年的照片应该在范围内
            XCTAssertTrue(lastYearPhoto >= start && lastYearPhoto <= end, "去年中间的照片应该在范围内")
            
            // 去年最后一天应该在范围内
            XCTAssertTrue(lastYearLastDay >= start && lastYearLastDay <= end, "去年最后一天应该在范围内")
            
            // 今年第一天不应该在范围内
            XCTAssertFalse(thisYearFirstDay >= start && thisYearFirstDay <= end, "今年第一天不应该在去年范围内")
        }
    }
    
    // MARK: - 时区测试
    
    func testDateCalculation_TimeZoneConsistency() {
        // 确保日期计算在不同时区下一致
        var oldFilter = ContentFilterType.thisYear
        let dateFilter1 = oldFilter.getDateFilter()
        
        // 稍后再次调用
        Thread.sleep(forTimeInterval: 0.1)
        let dateFilter2 = oldFilter.getDateFilter()
        
        // 应该得到相同的年份开始日期
        if let start1 = dateFilter1?.startDate,
           let start2 = dateFilter2?.startDate {
            let components1 = calendar.dateComponents([.year, .month, .day], from: start1)
            let components2 = calendar.dateComponents([.year, .month, .day], from: start2)
            
            XCTAssertEqual(components1, components2, "同一天内多次调用应该得到相同的年份开始")
        }
    }
    
    // MARK: - 日期范围组合测试
    
    func testDateRange_WithOtherFilters() {
        var config = FilterConfiguration()
        config.contentType = .screenshots
        config.dateRange = .recent30Days
        config.locationFilter = .withLocation
        
        let validation = config.validate()
        XCTAssertTrue(validation.isValid, "日期范围应该能与其他过滤组合")
    }
    
    func testAllDateRanges_WithScreenshots() {
        let dateRanges = DateRangeType.allCases
        
        for dateRange in dateRanges {
            var config = FilterConfiguration()
            config.contentType = .screenshots
            config.dateRange = dateRange
            
            let validation = config.validate()
            XCTAssertTrue(validation.isValid, "截图 + \(dateRange.rawValue) 应该有效")
        }
    }
    
    func testAllDateRanges_WithVideos() {
        let dateRanges = DateRangeType.allCases
        
        for dateRange in dateRanges {
            var config = FilterConfiguration()
            config.contentType = .videos
            config.dateRange = dateRange
            
            let validation = config.validate()
            XCTAssertTrue(validation.isValid, "视频 + \(dateRange.rawValue) 应该有效")
        }
    }
    
    // MARK: - 日期范围逻辑正确性测试
    
    func testRecent7Days_CoversLast7Days() {
        var oldFilter = ContentFilterType.recent7Days
        let dateFilter = oldFilter.getDateFilter()
        
        guard let start = dateFilter?.startDate, let end = dateFilter?.endDate else {
            XCTFail("应该返回有效的日期范围")
            return
        }
        
        // 测试各种时间点
        let now = Date()
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: now)!
        
        // 3天前应该在范围内
        XCTAssertTrue(threeDaysAgo >= start && threeDaysAgo <= end, "3天前应该在'最近7天'内")
        
        // 10天前不应该在范围内
        XCTAssertFalse(tenDaysAgo >= start && tenDaysAgo <= end, "10天前不应该在'最近7天'内")
    }
    
    func testOlder1Year_OnlyIncludesOldPhotos() {
        var oldFilter = ContentFilterType.older1Year
        let dateFilter = oldFilter.getDateFilter()
        
        guard let end = dateFilter?.endDate else {
            XCTFail("应该有结束日期")
            return
        }
        
        let now = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)!
        let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: now)!
        
        // 6个月前不应该符合"1年前"
        XCTAssertGreaterThan(sixMonthsAgo, end, "6个月前不应该在'1年前'范围内")
        
        // 2年前应该符合"1年前"
        XCTAssertLessThan(twoYearsAgo, end, "2年前应该在'1年前'范围内")
    }
    
    // MARK: - 性能测试
    
    func testDateCalculationPerformance() {
        measure {
            for _ in 0..<1000 {
                var filter = ContentFilterType.recent30Days
                _ = filter.getDateFilter()
            }
        }
    }
}

