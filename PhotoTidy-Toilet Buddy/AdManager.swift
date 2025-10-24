//
//  AdManager.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//

import Foundation
import GoogleMobileAds

/// AdManager handles all AdMob related functionality
/// Note: Replace placeholder Ad Unit IDs with real IDs before releasing to production
class AdManager: NSObject {
    
    static let shared = AdManager()
    
    // MARK: - Properties
    
    // Real Interstitial Ad Unit ID (Production)
    private let interstitialAdUnitID = "ca-app-pub-2034595640300550/4965494634"
    
    // Real Rewarded Ad Unit ID (Production)
    private let rewardedAdUnitID = "ca-app-pub-2034595640300550/4366728831"
    
    private var interstitialAd: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Initialize AdMob SDK
    /// Call this method during app launch
    func initializeAdMob() {
        GADMobileAds.sharedInstance().start { status in
            AppLogger.shared.info("AdMob SDK 初始化完成", category: .network)
            // 记录适配器状态
            for adapter in status.adapterStatusesByClassName {
                AppLogger.shared.debug("AdMob 适配器: \(adapter.key) - 状态: \(adapter.value.state.rawValue)", category: .network)
            }
            
            // 优化预加载策略：只预加载插页式广告，激励广告按需加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AppLogger.shared.info("开始预加载插页式广告", category: .network)
                self.loadInterstitialAd()
                // 激励广告将在需要时再加载，减少启动时的网络请求
            }
        }
    }
    
    /// Load an interstitial ad
    /// Call this method to preload an ad before showing it
    func loadInterstitialAd() {
        AppLogger.shared.debug("开始加载插页式广告...", category: .network)
        let request = GADRequest()
        
        GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                AppLogger.shared.error("插页式广告加载失败", error: error, category: .network)
                self?.interstitialAd = nil
                return
            }
            
            AppLogger.shared.debug("插页式广告加载成功", category: .network)
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
        }
    }
    
    /// Show the interstitial ad if available
    /// - Parameter completion: Callback executed after the ad is dismissed
    func showInterstitialAd(completion: @escaping () -> Void) {
        // 获取当前活跃的 window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            AppLogger.shared.error("无法获取 root view controller", category: .ui)
            completion()
            return
        }
        
        if let interstitialAd = interstitialAd {
            AppLogger.shared.info("准备展示插页式广告...", category: .network)
            // 保存完成回调
            self.adDismissalCompletion = completion
            // 展示广告
            interstitialAd.present(fromRootViewController: rootViewController)
        } else {
            AppLogger.shared.warning("插页式广告未准备好，跳过广告展示", category: .network)
            completion()
            // 尝试重新加载广告以备下次使用
            loadInterstitialAd()
        }
    }
    
    // MARK: - Rewarded Ad Methods
    
    /// Load a rewarded ad
    /// Call this method to preload a rewarded ad before showing it
    /// - Parameter completion: Optional completion callback with success status
    func loadRewardedAd(completion: ((Bool) -> Void)? = nil) {
        AppLogger.shared.debug("开始加载激励广告...", category: .network)
        let request = GADRequest()
        
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                AppLogger.shared.error("激励广告加载失败", error: error, category: .network)
                self?.rewardedAd = nil
                completion?(false)
                return
            }
            
            AppLogger.shared.debug("激励广告加载成功", category: .network)
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            completion?(true)
        }
    }
    
    /// Show the rewarded ad if available
    /// - Parameters:
    ///   - completion: Callback executed after the ad is dismissed
    ///   - rewardGranted: Callback with true if user earned the reward, false otherwise
    func showRewardedAd(completion: @escaping (_ rewardGranted: Bool) -> Void) {
        // 获取当前活跃的 window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            AppLogger.shared.error("无法获取 root view controller", category: .ui)
            completion(false)
            return
        }
        
        if let rewardedAd = rewardedAd {
            AppLogger.shared.info("准备展示激励广告...", category: .network)
            // 保存奖励回调
            self.rewardedAdCompletion = completion
            
            // 展示广告
            rewardedAd.present(fromRootViewController: rootViewController) {
                // 用户观看完广告，获得奖励
                let reward = rewardedAd.adReward
                AppLogger.shared.info("用户获得奖励: \(reward.amount) \(reward.type)", category: .network)
                self.userEarnedReward = true
            }
        } else {
            AppLogger.shared.warning("激励广告未准备好，按需加载...", category: .network)
            // 按需加载激励广告
            loadRewardedAd { [weak self] success in
                if success, let rewardedAd = self?.rewardedAd {
                    AppLogger.shared.info("激励广告加载成功，准备展示...", category: .network)
                    self?.rewardedAdCompletion = completion
                    
                    rewardedAd.present(fromRootViewController: rootViewController) {
                        let reward = rewardedAd.adReward
                        AppLogger.shared.info("用户获得奖励: \(reward.amount) \(reward.type)", category: .network)
                        self?.userEarnedReward = true
                    }
                } else {
                    AppLogger.shared.error("激励广告加载失败", category: .network)
                    completion(false)
                }
            }
        }
    }
    
    /// Check if rewarded ad is ready to show
    /// - Returns: true if ad is loaded and ready
    func isRewardedAdReady() -> Bool {
        return rewardedAd != nil
    }
    
    // MARK: - Private Properties
    
    private var adDismissalCompletion: (() -> Void)?
    private var rewardedAdCompletion: ((Bool) -> Void)?
    private var userEarnedReward: Bool = false
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        // 判断是插页式广告还是激励广告
        if ad is GADInterstitialAd {
            AppLogger.shared.info("插页式广告已关闭", category: .network)
            interstitialAd = nil
            
            // 调用完成回调
            if let completion = adDismissalCompletion {
                AppLogger.shared.debug("执行广告关闭回调", category: .network)
                completion()
                adDismissalCompletion = nil
            }
            
            // 预加载下一个广告
            AppLogger.shared.debug("预加载下一个插页式广告...", category: .network)
            loadInterstitialAd()
        } else if ad is GADRewardedAd {
            AppLogger.shared.info("激励广告已关闭", category: .network)
            
            // 调用奖励回调
            if let completion = rewardedAdCompletion {
                AppLogger.shared.debug("执行激励广告回调，是否获得奖励: \(userEarnedReward)", category: .network)
                completion(userEarnedReward)
                rewardedAdCompletion = nil
                userEarnedReward = false
            }
            
            rewardedAd = nil
            
            // 预加载下一个激励广告
            AppLogger.shared.debug("预加载下一个激励广告...", category: .network)
            loadRewardedAd()
        }
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if ad is GADInterstitialAd {
            AppLogger.shared.error("插页式广告展示失败", error: error, category: .network)
            interstitialAd = nil
            
            // 即使失败也调用完成回调
            if let completion = adDismissalCompletion {
                AppLogger.shared.debug("广告展示失败，执行回调", category: .network)
                completion()
                adDismissalCompletion = nil
            }
            
            // 尝试重新加载
            AppLogger.shared.debug("尝试重新加载插页式广告...", category: .network)
            loadInterstitialAd()
        } else if ad is GADRewardedAd {
            AppLogger.shared.error("激励广告展示失败", error: error, category: .network)
            rewardedAd = nil
            
            // 即使失败也调用回调
            if let completion = rewardedAdCompletion {
                AppLogger.shared.debug("激励广告展示失败，执行回调", category: .network)
                completion(false)
                rewardedAdCompletion = nil
                userEarnedReward = false
            }
            
            // 尝试重新加载
            AppLogger.shared.debug("尝试重新加载激励广告...", category: .network)
            loadRewardedAd()
        }
    }
    
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            AppLogger.shared.debug("插页式广告即将展示", category: .network)
        } else if ad is GADRewardedAd {
            AppLogger.shared.debug("激励广告即将展示", category: .network)
        }
    }
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            AppLogger.shared.debug("插页式广告已记录展示", category: .network)
        } else if ad is GADRewardedAd {
            AppLogger.shared.debug("激励广告已记录展示", category: .network)
        }
    }
    
    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            AppLogger.shared.debug("插页式广告已记录点击", category: .network)
        } else if ad is GADRewardedAd {
            AppLogger.shared.debug("激励广告已记录点击", category: .network)
        }
    }
}

