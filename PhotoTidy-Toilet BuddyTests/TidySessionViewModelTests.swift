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
        XCTAssertFalse(viewModel.canUndo)
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
    
    // MARK: - Delete/Keep Tests
    
    func testKeepCurrentPhoto() {
        // Given
        viewModel.photosToReview = (0..<3).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 0
        let initialKeptCount = viewModel.keptCount
        
        // When
        viewModel.keepCurrentPhoto()
        
        // Then
        XCTAssertEqual(viewModel.keptCount, initialKeptCount + 1)
        XCTAssertEqual(viewModel.currentIndex, 1, "应该移动到下一张")
    }
    
    func testDeleteCurrentPhoto() {
        // Given
        viewModel.photosToReview = (0..<3).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 0
        let initialDeletedCount = viewModel.deletedCount
        
        // When
        viewModel.deleteCurrentPhoto()
        
        // Then
        XCTAssertEqual(viewModel.deletedCount, initialDeletedCount + 1)
        XCTAssertEqual(viewModel.currentIndex, 1, "应该移动到下一张")
        XCTAssertTrue(viewModel.canUndo, "删除后应该可以撤销")
    }
    
    // MARK: - Undo Tests
    
    func testUndoLastDeletion() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 2
        viewModel.deleteCurrentPhoto() // 删除索引2的照片，移到索引3
        
        let deletedCountAfterDelete = viewModel.deletedCount
        let currentIndexAfterDelete = viewModel.currentIndex
        
        // When
        viewModel.undoLastDeletion()
        
        // Then
        XCTAssertEqual(viewModel.deletedCount, deletedCountAfterDelete - 1)
        XCTAssertEqual(viewModel.currentIndex, 2, "应该跳回到被删除照片的位置")
    }
    
    func testUndoCount() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        
        // When
        viewModel.deleteCurrentPhoto()
        viewModel.deleteCurrentPhoto()
        
        // Then
        XCTAssertEqual(viewModel.undoCount, 2)
    }
    
    func testMaxUndoSteps() {
        // Given
        viewModel.photosToReview = (0..<15).map { _ in TidyPhoto(asset: MockPHAsset()) }
        
        // When: 删除超过最大撤销步数
        for _ in 0..<12 {
            viewModel.deleteCurrentPhoto()
        }
        
        // Then: 撤销次数应该被限制在10次
        XCTAssertLessThanOrEqual(viewModel.undoCount, 10)
    }
    
    // MARK: - Session Completion Tests
    
    func testSessionCompletion_KeepAll() {
        // Given
        viewModel.photosToReview = (0..<3).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.isSessionActive = true
        
        // When: 保留所有照片
        viewModel.keepCurrentPhoto()
        viewModel.keepCurrentPhoto()
        viewModel.keepCurrentPhoto()
        
        // Then
        XCTAssertTrue(viewModel.isSessionCompleted)
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.keptCount, 3)
        XCTAssertEqual(viewModel.deletedCount, 0)
    }
    
    func testSessionCompletion_DeleteAll() {
        // Given
        viewModel.photosToReview = (0..<3).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.isSessionActive = true
        
        // When: 删除所有照片
        viewModel.deleteCurrentPhoto()
        viewModel.deleteCurrentPhoto()
        viewModel.deleteCurrentPhoto()
        
        // Then
        XCTAssertTrue(viewModel.isSessionCompleted)
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.deletedCount, 3)
        XCTAssertEqual(viewModel.keptCount, 0)
    }
    
    // MARK: - Reset Tests
    
    func testResetSession() {
        // Given
        viewModel.photosToReview = (0..<5).map { _ in TidyPhoto(asset: MockPHAsset()) }
        viewModel.currentIndex = 2
        viewModel.deletedCount = 1
        viewModel.keptCount = 1
        viewModel.isSessionActive = true
        
        // When
        viewModel.resetSession()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 0)
        XCTAssertEqual(viewModel.deletedCount, 0)
        XCTAssertEqual(viewModel.keptCount, 0)
        XCTAssertEqual(viewModel.photosToReview.count, 0)
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(viewModel.canUndo)
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

