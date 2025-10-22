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
    
    // Placeholder Interstitial Ad Unit ID (Test ID from Google)
    // TODO: Replace with your real Ad Unit ID before release
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    
    private var interstitialAd: GADInterstitialAd?
    
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
            
            // 初始化完成后预加载第一个广告
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadInterstitialAd()
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
    
    // MARK: - Private Properties
    
    private var adDismissalCompletion: (() -> Void)?
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("插页式广告已关闭")
        interstitialAd = nil
        
        // 调用完成回调
        if let completion = adDismissalCompletion {
            print("执行广告关闭回调")
            completion()
            adDismissalCompletion = nil
        }
        
        // 预加载下一个广告
        print("预加载下一个广告...")
        loadInterstitialAd()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("插页式广告展示失败: \(error.localizedDescription)")
        interstitialAd = nil
        
        // 即使失败也调用完成回调
        if let completion = adDismissalCompletion {
            print("广告展示失败，执行回调")
            completion()
            adDismissalCompletion = nil
        }
        
        // 尝试重新加载
        print("尝试重新加载广告...")
        loadInterstitialAd()
    }
    
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("插页式广告即将展示")
    }
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        print("插页式广告已记录展示")
    }
    
    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        print("插页式广告已记录点击")
    }
}

