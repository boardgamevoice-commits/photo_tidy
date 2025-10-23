//
//  TidySessionViewModelTests.swift
//  PhotoTidy-Toilet BuddyTests
//
//  Created on 2025-10-22.
//  测试 TidySessionViewModel 核心业务逻辑
//

import XCTest
import Photos
@testable import PhotoTidy_Toilet_Buddy

@MainActor
final class TidySessionViewModelTests: XCTestCase {
    
    var viewModel: TidySessionViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        viewModel = TidySessionViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Then
        XCTAssertEqual(viewModel.currentIndex, 0)
        XCTAssertEqual(viewModel.deletedCount, 0)
        XCTAssertEqual(viewModel.keptCount, 0)
        XCTAssertEqual(viewModel.totalPhotos, 0)
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(viewModel.isSessionCompleted)
    }
    
    // MARK: - Progress Tests
    
    func testProgress_EmptySession() {
        // When
        let progress = viewModel.progress
        
        // Then
        XCTAssertEqual(progress, 0.0, "空会话的进度应该是0")
    }
    
    func testProgress_HalfwayThrough() {
        // Given
        // 模拟会话中间状态
        viewModel.currentIndex = 5
        viewModel.photosToReview = (0..<10).map { _ in
            TidyPhoto(asset: MockPHAsset())
        }
        
        // When
        let progress = viewModel.progress
        
        // Then
        XCTAssertEqual(progress, 0.5, accuracy: 0.01, "50%进度应该是0.5")
    }
    
    // MARK: - Navigation Tests
    
    func testCanMovePrevious() {
        // Given
        viewModel.currentIndex = 0
        
        // Then
        XCTAssertFalse(viewModel.canMovePrevious, "第一张照片不能向前")
        
        // When
        viewModel.currentIndex = 1
        
        // Then
        XCTAssertTrue(viewModel.canMovePrevious, "第二张照片可以向前")
    }
    
    func testCanMoveNext() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 4
        
        // Then
        XCTAssertFalse(viewModel.canMoveNext, "最后一张照片不能向后")
        
        // When
        viewModel.currentIndex = 3
        
        // Then
        XCTAssertTrue(viewModel.canMoveNext, "倒数第二张照片可以向后")
    }
    
    func testMoveToNextPhoto() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 0
        
        // When
        viewModel.moveToNextPhoto()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 1)
    }
    
    func testMoveToPreviousPhoto() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 2
        
        // When
        viewModel.moveToPreviousPhoto()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 1)
    }
    
    // MARK: - Toggle Deletion Tests
    
    func testToggleDeletionMark_MarkForDeletion() {
        // Given
        viewModel.photosToReview = (0..<3).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 0
        
        // When
        viewModel.toggleDeletionMark()
        
        // Then
        XCTAssertEqual(viewModel.deletedCount, 1, "应该有1张照片被标记删除")
        XCTAssertEqual(viewModel.keptCount, 2, "应该有2张照片保留")
        XCTAssertEqual(viewModel.currentIndex, 1, "标记删除后应该自动移动到下一张")
        XCTAssertTrue(viewModel.photosToReview[0].isMarkedForDeletion, "第一张照片应该被标记删除")
    }
    
    func testToggleDeletionMark_RestorePhoto() {
        // Given
        viewModel.photosToReview = (0..<3).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 0
        viewModel.toggleDeletionMark() // 先标记删除
        viewModel.moveToPreviousPhoto() // 返回已删除的照片
        
        // When
        viewModel.toggleDeletionMark() // 取消删除
        
        // Then
        XCTAssertEqual(viewModel.deletedCount, 0, "应该没有照片被标记删除")
        XCTAssertEqual(viewModel.keptCount, 3, "应该有3张照片保留")
        XCTAssertEqual(viewModel.currentIndex, 0, "取消删除后应该停留在当前位置")
        XCTAssertFalse(viewModel.photosToReview[0].isMarkedForDeletion, "第一张照片不应该被标记删除")
    }
    
    func testToggleDeletionMark_MultiplePhotos() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 0
        
        // When: 标记删除3张照片
        viewModel.toggleDeletionMark() // 删除索引0，移到索引1
        viewModel.toggleDeletionMark() // 删除索引1，移到索引2
        viewModel.toggleDeletionMark() // 删除索引2，移到索引3
        
        // Then
        XCTAssertEqual(viewModel.deletedCount, 3, "应该有3张照片被标记删除")
        XCTAssertEqual(viewModel.keptCount, 2, "应该有2张照片保留")
        XCTAssertEqual(viewModel.currentIndex, 3, "应该在第4张照片")
    }
    
    func testDeletedCount_Calculation() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        
        // When: 手动标记几张照片为删除
        viewModel.photosToReview[0].isMarkedForDeletion = true
        viewModel.photosToReview[2].isMarkedForDeletion = true
        viewModel.photosToReview[4].isMarkedForDeletion = true
        
        // Then
        XCTAssertEqual(viewModel.deletedCount, 3, "应该基于状态计算删除数量")
        XCTAssertEqual(viewModel.keptCount, 2, "应该基于状态计算保留数量")
    }
    
    // MARK: - Session Completion Tests
    
    func testSessionCompletion_DeleteAll() {
        // Given
        viewModel.photosToReview = (0..<3).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.isSessionActive = true
        
        // When: 标记删除所有照片
        viewModel.toggleDeletionMark() // 删除索引0，移到索引1
        viewModel.toggleDeletionMark() // 删除索引1，移到索引2
        viewModel.toggleDeletionMark() // 删除索引2，到达最后
        
        // Then
        XCTAssertEqual(viewModel.deletedCount, 3, "所有照片都应该被标记删除")
        XCTAssertEqual(viewModel.keptCount, 0, "没有照片保留")
    }
    
    func testPendingDeletions() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        
        // When: 标记部分照片为删除
        viewModel.photosToReview[1].isMarkedForDeletion = true
        viewModel.photosToReview[3].isMarkedForDeletion = true
        
        // Then
        XCTAssertEqual(viewModel.pendingDeletionCount, 2, "应该有2张照片待删除")
        XCTAssertEqual(viewModel.pendingDeletions.count, 2, "待删除列表应该有2个资源")
    }
    
    // MARK: - Reset Tests
    
    func testResetSession() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 2
        viewModel.photosToReview[0].isMarkedForDeletion = true
        viewModel.photosToReview[1].isMarkedForDeletion = true
        viewModel.isSessionActive = true
        
        // When
        viewModel.resetSession()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 0)
        XCTAssertEqual(viewModel.deletedCount, 0, "重置后删除计数应该为0")
        XCTAssertEqual(viewModel.keptCount, 0, "重置后保留计数应该为0")
        XCTAssertEqual(viewModel.photosToReview.count, 0)
        XCTAssertFalse(viewModel.isSessionActive)
    }
    
    // MARK: - Edge Cases
    
    func testCurrentPhoto_EmptyArray() {
        // Given
        viewModel.photosToReview = []
        
        // When
        let photo = viewModel.currentPhoto
        
        // Then
        XCTAssertNil(photo, "空数组应该返回nil")
    }
    
    func testCurrentPhoto_OutOfBounds() {
        // Given
        viewModel.photosToReview = (0..<3).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 10 // 越界
        
        // When
        let photo = viewModel.currentPhoto
        
        // Then
        XCTAssertNil(photo, "越界索引应该返回nil")
    }
    
    func testJumpToIndex_Valid() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        
        // When
        viewModel.jumpToIndex(3)
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 3)
    }
    
    func testJumpToIndex_OutOfBounds() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        let originalIndex = viewModel.currentIndex
        
        // When
        viewModel.jumpToIndex(10)
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, originalIndex, "越界跳转应该被忽略")
    }
}

// MARK: - Mock Objects

/// Mock PHAsset for testing
class MockPHAsset: PHAsset {
    private let mockIdentifier = UUID().uuidString
    
    override var localIdentifier: String {
        return mockIdentifier
    }
}

