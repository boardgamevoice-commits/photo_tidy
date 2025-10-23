//
//  Localization.swift
//  PhotoTidy-Toilet Buddy
//
//  Created on 2025-10-22.
//  本地化辅助工具
//

import Foundation

/// 本地化辅助扩展
extension String {
    /// 获取本地化字符串
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    /// 获取带参数的本地化字符串
    func localized(_ args: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: args)
    }
}

/// 本地化字符串集中管理
struct L10n {
    
    // MARK: - App
    
    struct App {
        static let name = "app.name".localized
        static let subtitle = "app.subtitle".localized
        static let tagline = "app.tagline".localized
    }
    
    // MARK: - Buttons
    
    struct Button {
        static let cancel = "button.cancel".localized
        static let done = "button.done".localized
        static let confirm = "button.confirm".localized
        static let start = "button.start".localized
        static let startNew = "button.start_new".localized
        static let startNewSession = "button.start_new_session".localized
        static let retry = "button.retry".localized
        static let skip = "button.skip".localized
        static let delete = "button.delete".localized
        static let keep = "button.keep".localized
        static let undo = "button.undo".localized
        static let reset = "button.reset".localized
        static let goToSettings = "button.go_to_settings".localized
        static let continueTrying = "button.continue_trying".localized
        static let skipAllFailed = "button.skip_all_failed".localized
        static let confirmDeleteAndStart = "button.confirm_delete_and_start".localized
        static let clear = "button.clear".localized
    }
    
    // MARK: - Loading
    
    struct Loading {
        static let general = "loading.general".localized
        static let photo = "loading.photo".localized
        static let deleting = "loading.deleting".localized
        static let pleaseWait = "loading.please_wait".localized
    }
    
    // MARK: - Session Setup
    
    struct SessionSetup {
        static let title = "session.setup.title".localized
        static let photoCount = "session.setup.photo_count".localized
        static let unitPhoto = "session.setup.unit.photo".localized
        static let quickFilters = "session.setup.quick_filters".localized
        static let advancedFilters = "session.setup.advanced_filters".localized
        static let lastCompleted = "session.setup.last_completed".localized
        
        struct Preset {
            static let quick = "session.setup.preset.quick".localized
            static let standard = "session.setup.preset.standard".localized
            static let deep = "session.setup.preset.deep".localized
        }
    }
    
    // MARK: - Filter
    
    struct Filter {
        static let advanced = "filter.advanced".localized
        static let contentType = "filter.content_type".localized
        static let dateRange = "filter.date_range".localized
        static let location = "filter.location".localized
        static let duration = "filter.duration".localized
        static let otherOptions = "filter.other_options".localized
        static let excludeHidden = "filter.exclude_hidden".localized
        static let excludeHiddenDesc = "filter.exclude_hidden_desc".localized
        static let excludeFavorite = "filter.exclude_favorite".localized
        static let excludeFavoriteDesc = "filter.exclude_favorite_desc".localized
        static let excludeHiddenPhotos = "filter.exclude_hidden_photos".localized
        static let excludeFavoritePhotos = "filter.exclude_favorite_photos".localized
        static let logic = "filter.logic".localized
        static let logicAnd = "filter.logic_and".localized
        static let unlimited = "filter.unlimited".localized
        static let unlimitedTime = "filter.unlimited_time".localized
        static let unlimitedLocation = "filter.unlimited_location".localized
        static let unlimitedDuration = "filter.unlimited_duration".localized
        static let selectContentType = "filter.select_content_type".localized
        static let selectDateRange = "filter.select_date_range".localized
        static let selectLocation = "filter.select_location".localized
        static let selectDuration = "filter.select_duration".localized
    }
    
    // MARK: - Review
    
    struct Review {
        static let previous = "review.previous".localized
        static let next = "review.next".localized
        static let screenshot = "review.screenshot".localized
        static let live = "review.live".localized
        static let panorama = "review.panorama".localized
        static let playing = "review.playing".localized
        static let longPressToPlay = "review.long_press_to_play".localized
        static let doubleTapToExit = "review.double_tap_to_exit".localized
        static let unknownDate = "review.unknown_date".localized
        
        static func progress(_ current: Int, _ total: Int) -> String {
            "review.progress".localized(current, total)
        }
        
        static func zoomLevel(_ level: CGFloat) -> String {
            "review.zoom_level".localized(level)
        }
    }
    
    // MARK: - Session Complete
    
    struct SessionComplete {
        static let title = "session.complete.title".localized
        static let subtitle = "session.complete.subtitle".localized
        static let deleted = "session.complete.deleted".localized
        static let kept = "session.complete.kept".localized
        static let total = "session.complete.total".localized
        static let details = "session.complete.details".localized
        static let deletionRate = "session.complete.deletion_rate".localized
        static let keepRate = "session.complete.keep_rate".localized
        static let pendingDeletion = "session.complete.pending_deletion".localized
        static let estimatedSpace = "session.complete.estimated_space".localized
        static let sessionCount = "session.complete.session_count".localized
        
        static func pendingDeletionCount(_ count: Int) -> String {
            "session.complete.pending_deletion_count".localized(count)
        }
        
        static func willDeleteCount(_ count: Int) -> String {
            "session.complete.will_delete_count".localized(count)
        }
    }
    
    // MARK: - Settings
    
    struct Settings {
        static let title = "settings.title".localized
        static let appearance = "settings.appearance".localized
        static let language = "settings.language".localized
        static let dataAndStats = "settings.data_and_stats".localized
        static let totalReviewed = "settings.total_reviewed".localized
        static let totalDeleted = "settings.total_deleted".localized
        static let totalFreedSpace = "settings.total_freed_space".localized
        static let totalSessions = "settings.total_sessions".localized
        static let clearStats = "settings.clear_stats".localized
        static let resetSettings = "settings.reset_settings".localized
        static let photoPermission = "settings.photo_permission".localized
        static let about = "settings.about".localized
        static let appVersion = "settings.app_version".localized
        static let developer = "settings.developer".localized
        static let developerName = "settings.developer_name".localized
        static let feedback = "settings.feedback".localized
        static let privacyPolicy = "settings.privacy_policy".localized
        static let dataLocalOnly = "settings.data_local_only".localized
        static let statsHelp = "settings.stats_help".localized
        static let themeDescription = "settings.theme_description".localized
        static let languageDescription = "settings.language_description".localized
        static let restartRequired = "settings.restart_required".localized
    }
    
    // MARK: - Error
    
    struct Error {
        static let title = "error.title".localized
        static let general = "error.general".localized
        static let photoLoad = "error.photo_load".localized
        static let photoDeletedOrCorrupted = "error.photo_deleted_or_corrupted".localized
        static let permission = "error.permission".localized
        static let permissionRequired = "error.permission_required".localized
        static let consecutiveFailures = "error.consecutive_failures".localized
        static let cannotLoadMore = "error.cannot_load_more".localized
        
        static func consecutiveFailuresMessage(_ count: Int) -> String {
            "error.consecutive_failures_message".localized(count)
        }
    }
    
    // MARK: - Empty
    
    struct Empty {
        static let title = "empty.title".localized
        static let message = "empty.message".localized
        static let action = "empty.action".localized
        static let errorTitle = "empty.error_title".localized
    }
    
    // MARK: - Permission
    
    struct Permission {
        static let title = "permission.title".localized
        static let description = "permission.description".localized
        
        struct Reason {
            static let view = "permission.reason.view".localized
            static let delete = "permission.reason.delete".localized
            static let privacy = "permission.reason.privacy".localized
        }
    }
    
    // MARK: - Alert
    
    struct Alert {
        static let hint = "alert.hint".localized
        
        struct ResetSettings {
            static let title = "alert.reset_settings.title".localized
            static let message = "alert.reset_settings.message".localized
        }
        
        struct ClearStats {
            static let title = "alert.clear_stats.title".localized
            static let message = "alert.clear_stats.message".localized
        }
    }
    
    // MARK: - Toast
    
    struct Toast {
        static let settingsReset = "toast.settings_reset".localized
        static let statsCleared = "toast.stats_cleared".localized
    }
    
    // MARK: - Rewarded Ad
    
    struct RewardedAd {
        static let title = "rewarded_ad.title".localized
        static let description = "rewarded_ad.description".localized
        static let buttonWatch = "rewarded_ad.button_watch".localized
        static let statusActive = "rewarded_ad.status_active".localized
        static let statusRemaining = "rewarded_ad.status_remaining".localized
        static func statusRemainingTime(_ time: String) -> String {
            "rewarded_ad.status_remaining_time".localized(time)
        }
        static let rewardReceived = "rewarded_ad.reward_received".localized
        static let rewardFailed = "rewarded_ad.reward_failed".localized
        static let adLoadFailed = "rewarded_ad.ad_load_failed".localized
        static let adNotReady = "rewarded_ad.ad_not_ready".localized
        static let loading = "rewarded_ad.loading".localized
    }
    
    // MARK: - Validation
    
    struct Validation {
        struct Warning {
            static let imageWithDuration = "validation.warning.image_with_duration".localized
        }
        
        struct Suggestion {
            static let removeDuration = "validation.suggestion.remove_duration".localized
            static let videoLocation = "validation.suggestion.video_location".localized
            static let selfieAccuracy = "validation.suggestion.selfie_accuracy".localized
            static let burstDateRange = "validation.suggestion.burst_date_range".localized
        }
    }
}

