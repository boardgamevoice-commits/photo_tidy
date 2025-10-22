//
//  SettingsManagerTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//

import XCTest
@testable import PhotoTidy_Toilet_Buddy

/// 设置管理器和统计数据的单元测试
class SettingsManagerTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    
    override func setUp() {
        super.setUp()
        // 使用共享实例
        settingsManager = SettingsManager.shared
        
        // 清除所有数据，从干净状态开始
        settingsManager.clearStatistics()
        settingsManager.resetSettings()
    }
    
    override func tearDown() {
        // 测试后清理
        settingsManager.clearStatistics()
        super.tearDown()
    }
    
    // MARK: - 统计数据测试
    
    func testInitialStatistics_ShouldBeZero() {
        // 初始状态应该为 0
        XCTAssertEqual(settingsManager.totalReviewedPhotos, 0, "初始审阅数应为 0")
        XCTAssertEqual(settingsManager.totalDeletedPhotos, 0, "初始删除数应为 0")
        XCTAssertEqual(settingsManager.totalFreedSpace, 0, "初始释放空间应为 0")
        XCTAssertEqual(settingsManager.totalSessions, 0, "初始会话数应为 0")
    }
    
    func testUpdateStatistics_FirstTime() {
        // 第一次更新统计
        settingsManager.updateStatistics(
            reviewedCount: 30,
            deletedCount: 15,
            freedSpace: 125_000_000 // 125 MB
        )
        
        // 验证数据正确累加
        XCTAssertEqual(settingsManager.totalReviewedPhotos, 30)
        XCTAssertEqual(settingsManager.totalDeletedPhotos, 15)
        XCTAssertEqual(settingsManager.totalFreedSpace, 125_000_000)
        XCTAssertEqual(settingsManager.totalSessions, 1)
    }
    
    func testUpdateStatistics_Multiple() {
        // 第一次会话
        settingsManager.updateStatistics(
            reviewedCount: 30,
            deletedCount: 15,
            freedSpace: 125_000_000
        )
        
        // 第二次会话
        settingsManager.updateStatistics(
            reviewedCount: 50,
            deletedCount: 20,
            freedSpace: 200_000_000
        )
        
        // 第三次会话
        settingsManager.updateStatistics(
            reviewedCount: 20,
            deletedCount: 10,
            freedSpace: 80_000_000
        )
        
        // 验证累加结果
        XCTAssertEqual(settingsManager.totalReviewedPhotos, 100, "审阅总数应为 30+50+20=100")
        XCTAssertEqual(settingsManager.totalDeletedPhotos, 45, "删除总数应为 15+20+10=45")
        XCTAssertEqual(settingsManager.totalFreedSpace, 405_000_000, "释放空间应为 125M+200M+80M=405M")
        XCTAssertEqual(settingsManager.totalSessions, 3, "会话次数应为 3")
    }
    
    func testClearStatistics_ShouldResetToZero() {
        // 先添加一些数据
        settingsManager.updateStatistics(
            reviewedCount: 50,
            deletedCount: 25,
            freedSpace: 300_000_000
        )
        
        // 验证数据存在
        XCTAssertEqual(settingsManager.totalReviewedPhotos, 50)
        
        // 清除统计
        settingsManager.clearStatistics()
        
        // 验证已清除
        XCTAssertEqual(settingsManager.totalReviewedPhotos, 0)
        XCTAssertEqual(settingsManager.totalDeletedPhotos, 0)
        XCTAssertEqual(settingsManager.totalFreedSpace, 0)
        XCTAssertEqual(settingsManager.totalSessions, 0)
    }
    
    func testFormattedTotalFreedSpace() {
        // 测试空间格式化
        settingsManager.updateStatistics(
            reviewedCount: 10,
            deletedCount: 5,
            freedSpace: 1_500_000_000 // 1.5 GB
        )
        
        let formatted = settingsManager.formattedTotalFreedSpace()
        
        // 应该包含 GB 或 MB
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("MB"), "格式化空间应包含单位")
        XCTAssertFalse(formatted.isEmpty, "格式化结果不应为空")
    }
    
    func testFormattedTotalFreedSpace_Zero() {
        // 测试 0 字节的格式化
        settingsManager.clearStatistics()
        
        let formatted = settingsManager.formattedTotalFreedSpace()
        
        // 0 字节应该返回 "0 bytes" 或类似值
        XCTAssertFalse(formatted.isEmpty, "格式化结果不应为空")
    }
    
    // MARK: - 触发器测试
    
    func testStatisticsUpdateTrigger_ChangesOnUpdate() {
        let initialTrigger = settingsManager.statisticsUpdateTrigger
        
        settingsManager.updateStatistics(
            reviewedCount: 10,
            deletedCount: 5,
            freedSpace: 50_000_000
        )
        
        // 触发器应该增加
        XCTAssertEqual(settingsManager.statisticsUpdateTrigger, initialTrigger + 1, "更新后触发器应该增加")
    }
    
    func testStatisticsUpdateTrigger_ChangesOnClear() {
        settingsManager.updateStatistics(
            reviewedCount: 10,
            deletedCount: 5,
            freedSpace: 50_000_000
        )
        
        let triggerAfterUpdate = settingsManager.statisticsUpdateTrigger
        
        settingsManager.clearStatistics()
        
        // 清除后触发器应该再次增加
        XCTAssertEqual(settingsManager.statisticsUpdateTrigger, triggerAfterUpdate + 1, "清除后触发器应该增加")
    }
    
    // MARK: - 设置管理测试
    
    func testResetSettings_ShouldUseDefaults() {
        // 修改设置
        settingsManager.settings.maxUndoSteps = 20
        settingsManager.settings.autoPreload = false
        
        // 重置
        settingsManager.resetSettings()
        
        // 验证恢复默认值
        XCTAssertEqual(settingsManager.settings.maxUndoSteps, 10)
        XCTAssertEqual(settingsManager.settings.autoPreload, true)
    }
    
    func testSettings_PersistenceAfterSave() {
        // 修改设置
        settingsManager.settings.maxUndoSteps = 15
        settingsManager.settings.preloadCount = 3
        
        // 等待自动保存
        let expectation = XCTestExpectation(description: "Settings saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // 验证数据已保存到 UserDefaults
        if let data = UserDefaults.standard.data(forKey: "app.settings"),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            XCTAssertEqual(decoded.maxUndoSteps, 15)
            XCTAssertEqual(decoded.preloadCount, 3)
        } else {
            XCTFail("设置应该已保存到 UserDefaults")
        }
    }
}

