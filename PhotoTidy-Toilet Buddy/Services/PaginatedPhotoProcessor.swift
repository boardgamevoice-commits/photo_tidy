//
//  PaginatedPhotoProcessor.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-23.
//

import Foundation
import Photos

/// 分页照片处理器
/// 用于分批处理大量照片资产，避免一次性遍历全部资产
class PaginatedPhotoProcessor {
    
    // MARK: - Properties
    
    /// 每批处理的照片数量
    private let batchSize: Int
    
    /// 处理进度回调
    private var progressCallback: ((Double) -> Void)?
    
    /// 取消标志
    private var isCancelled = false
    
    // MARK: - Initialization
    
    init(batchSize: Int = 100) {
        self.batchSize = batchSize
        AppLogger.shared.info("PaginatedPhotoProcessor 初始化，批次大小: \(batchSize)", category: .photo)
    }
    
    // MARK: - Public Methods
    
    /// 分页处理照片资产
    /// - Parameters:
    ///   - fetchResult: 照片资产结果
    ///   - processor: 处理每个资产的闭包
    ///   - progressCallback: 进度回调
    /// - Returns: 处理结果
    func processAssets<T>(
        from fetchResult: PHFetchResult<PHAsset>,
        processor: @escaping (PHAsset) -> T?,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> [T] {
        
        self.progressCallback = progressCallback
        self.isCancelled = false
        
        let totalCount = fetchResult.count
        var results: [T] = []
        
        AppLogger.shared.info("开始分页处理 \(totalCount) 个资产，批次大小: \(batchSize)", category: .photo)
        
        // 分批处理
        for batchIndex in 0..<Int(ceil(Double(totalCount) / Double(batchSize))) {
            // 检查是否取消
            if isCancelled {
                AppLogger.shared.info("分页处理被取消", category: .photo)
                throw PhotoCountError.cancelled
            }
            
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, totalCount)
            
            AppLogger.shared.debug("处理批次 \(batchIndex + 1): 索引 \(startIndex) 到 \(endIndex - 1)", category: .photo)
            
            // 处理当前批次
            let batchResults = await processBatch(
                from: fetchResult,
                startIndex: startIndex,
                endIndex: endIndex,
                processor: processor
            )
            
            results.append(contentsOf: batchResults)
            
            // 更新进度
            let progress = Double(endIndex) / Double(totalCount)
            await MainActor.run {
                progressCallback(progress)
            }
            
            // 让出主线程
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        AppLogger.shared.info("分页处理完成，处理了 \(results.count) 个结果", category: .photo)
        return results
    }
    
    /// 分页计算满足条件的照片数量
    /// - Parameters:
    ///   - fetchResult: 照片资产结果
    ///   - condition: 条件检查闭包
    ///   - progressCallback: 进度回调
    /// - Returns: 满足条件的照片数量
    func countAssets(
        from fetchResult: PHFetchResult<PHAsset>,
        condition: @escaping (PHAsset) -> Bool,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> Int {
        
        self.progressCallback = progressCallback
        self.isCancelled = false
        
        let totalCount = fetchResult.count
        var count = 0
        
        AppLogger.shared.info("开始分页计算 \(totalCount) 个资产", category: .photo)
        
        // 分批处理
        for batchIndex in 0..<Int(ceil(Double(totalCount) / Double(batchSize))) {
            // 检查是否取消
            if isCancelled {
                AppLogger.shared.info("分页计算被取消", category: .photo)
                throw PhotoCountError.cancelled
            }
            
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, totalCount)
            
            AppLogger.shared.debug("计算批次 \(batchIndex + 1): 索引 \(startIndex) 到 \(endIndex - 1)", category: .photo)
            
            // 计算当前批次
            let batchCount = await countBatch(
                from: fetchResult,
                startIndex: startIndex,
                endIndex: endIndex,
                condition: condition
            )
            
            count += batchCount
            
            // 更新进度
            let progress = Double(endIndex) / Double(totalCount)
            await MainActor.run {
                progressCallback(progress)
            }
            
            // 让出主线程
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        AppLogger.shared.info("分页计算完成，满足条件的照片数量: \(count)", category: .photo)
        return count
    }
    
    /// 取消处理
    func cancel() {
        isCancelled = true
        AppLogger.shared.info("分页处理器收到取消请求", category: .photo)
    }
    
    // MARK: - Private Methods
    
    /// 处理单个批次
    private func processBatch<T>(
        from fetchResult: PHFetchResult<PHAsset>,
        startIndex: Int,
        endIndex: Int,
        processor: @escaping (PHAsset) -> T?
    ) async -> [T] {
        
        var batchResults: [T] = []
        
        for index in startIndex..<endIndex {
            // 检查是否取消
            if isCancelled {
                break
            }
            
            let asset = fetchResult.object(at: index)
            
            if let result = processor(asset) {
                batchResults.append(result)
            }
        }
        
        return batchResults
    }
    
    /// 计算单个批次
    private func countBatch(
        from fetchResult: PHFetchResult<PHAsset>,
        startIndex: Int,
        endIndex: Int,
        condition: @escaping (PHAsset) -> Bool
    ) async -> Int {
        
        var count = 0
        
        for index in startIndex..<endIndex {
            // 检查是否取消
            if isCancelled {
                break
            }
            
            let asset = fetchResult.object(at: index)
            
            if condition(asset) {
                count += 1
            }
        }
        
        return count
    }
}

// MARK: - Photo Count Error

enum PhotoCountError: LocalizedError {
    case cancelled
    case calculationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "操作被取消"
        case .calculationFailed(let reason):
            return "计算失败: \(reason)"
        }
    }
}

extension PhotoCountError {
    static let calculationError = PhotoCountError.calculationFailed("未知错误")
}
