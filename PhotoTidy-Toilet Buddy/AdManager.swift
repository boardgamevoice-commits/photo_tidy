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
            print("AdMob SDK 初始化完成")
            // 记录适配器状态
            for adapter in status.adapterStatusesByClassName {
                print("AdMob 适配器: \(adapter.key) - 状态: \(adapter.value.state.rawValue)")
            }
            
            // 初始化完成后预加载广告
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadInterstitialAd()
                self.loadRewardedAd()
            }
        }
    }
    
    /// Load an interstitial ad
    /// Call this method to preload an ad before showing it
    func loadInterstitialAd() {
        print("开始加载插页式广告...")
        let request = GADRequest()
        
        GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("插页式广告加载失败: \(error.localizedDescription)")
                self?.interstitialAd = nil
                return
            }
            
            print("插页式广告加载成功 ✓")
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
            print("无法获取 root view controller")
            completion()
            return
        }
        
        if let interstitialAd = interstitialAd {
            print("准备展示插页式广告...")
            // 保存完成回调
            self.adDismissalCompletion = completion
            // 展示广告
            interstitialAd.present(fromRootViewController: rootViewController)
        } else {
            print("插页式广告未准备好，跳过广告展示")
            completion()
            // 尝试重新加载广告以备下次使用
            loadInterstitialAd()
        }
    }
    
    // MARK: - Rewarded Ad Methods
    
    /// Load a rewarded ad
    /// Call this method to preload a rewarded ad before showing it
    func loadRewardedAd() {
        print("开始加载激励广告...")
        let request = GADRequest()
        
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("激励广告加载失败: \(error.localizedDescription)")
                self?.rewardedAd = nil
                return
            }
            
            print("激励广告加载成功 ✓")
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
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
            print("无法获取 root view controller")
            completion(false)
            return
        }
        
        if let rewardedAd = rewardedAd {
            print("准备展示激励广告...")
            // 保存奖励回调
            self.rewardedAdCompletion = completion
            
            // 展示广告
            rewardedAd.present(fromRootViewController: rootViewController) {
                // 用户观看完广告，获得奖励
                let reward = rewardedAd.adReward
                print("🎁 用户获得奖励: \(reward.amount) \(reward.type)")
                self.userEarnedReward = true
            }
        } else {
            print("激励广告未准备好，无法展示")
            completion(false)
            // 尝试重新加载广告以备下次使用
            loadRewardedAd()
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
            print("插页式广告已关闭")
            interstitialAd = nil
            
            // 调用完成回调
            if let completion = adDismissalCompletion {
                print("执行广告关闭回调")
                completion()
                adDismissalCompletion = nil
            }
            
            // 预加载下一个广告
            print("预加载下一个插页式广告...")
            loadInterstitialAd()
        } else if ad is GADRewardedAd {
            print("激励广告已关闭")
            
            // 调用奖励回调
            if let completion = rewardedAdCompletion {
                print("执行激励广告回调，是否获得奖励: \(userEarnedReward)")
                completion(userEarnedReward)
                rewardedAdCompletion = nil
                userEarnedReward = false
            }
            
            rewardedAd = nil
            
            // 预加载下一个激励广告
            print("预加载下一个激励广告...")
            loadRewardedAd()
        }
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if ad is GADInterstitialAd {
            print("插页式广告展示失败: \(error.localizedDescription)")
            interstitialAd = nil
            
            // 即使失败也调用完成回调
            if let completion = adDismissalCompletion {
                print("广告展示失败，执行回调")
                completion()
                adDismissalCompletion = nil
            }
            
            // 尝试重新加载
            print("尝试重新加载插页式广告...")
            loadInterstitialAd()
        } else if ad is GADRewardedAd {
            print("激励广告展示失败: \(error.localizedDescription)")
            rewardedAd = nil
            
            // 即使失败也调用回调
            if let completion = rewardedAdCompletion {
                print("激励广告展示失败，执行回调")
                completion(false)
                rewardedAdCompletion = nil
                userEarnedReward = false
            }
            
            // 尝试重新加载
            print("尝试重新加载激励广告...")
            loadRewardedAd()
        }
    }
    
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            print("插页式广告即将展示")
        } else if ad is GADRewardedAd {
            print("激励广告即将展示")
        }
    }
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            print("插页式广告已记录展示")
        } else if ad is GADRewardedAd {
            print("激励广告已记录展示")
        }
    }
    
    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        if ad is GADInterstitialAd {
            print("插页式广告已记录点击")
        } else if ad is GADRewardedAd {
            print("激励广告已记录点击")
        }
    }
}

