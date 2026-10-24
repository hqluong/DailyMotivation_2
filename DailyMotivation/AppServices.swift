// MARK: - AppServices.swift

import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import FirebaseRemoteConfig
import Foundation
import UIKit

/// Starts Firebase at launch. Everything Firebase-related is skipped when
/// GoogleService-Info.plist is not bundled, so the app still runs without it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppServices.configure()
        return true
    }
}

enum AppServices {
    private(set) static var isFirebaseConfigured = false

    static func configure() {
        guard !isFirebaseConfigured,
              Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        else {
            #if DEBUG
            print("GoogleService-Info.plist not found; Firebase is disabled.")
            #endif
            return
        }
        FirebaseApp.configure()
        isFirebaseConfigured = true
        Analytics.setAnalyticsCollectionEnabled(AnalyticsLogger.isCollectionEnabled)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(AnalyticsLogger.isCollectionEnabled)
        RemoteSettings.activate()
    }
}

// MARK: - Analytics

/// Thin wrapper so call sites stay simple and nothing breaks without Firebase.
enum AnalyticsLogger {
    enum Event: String {
        case onboardingCompleted = "onboarding_completed"
        case quoteNext = "quote_next"
        case quoteViewed = "daily_quote_viewed"
        case quoteFavorited = "quote_favorited"
        case shareTapped = "share_tapped"
        case shareCompleted = "share_completed"
        case dailyResetCompleted = "daily_reset_completed"
        case searchResultOpened = "search_result_opened"
        case noteSaved = "note_saved"
    }

    static let collectionEnabledKey = "analyticsCollectionEnabled"

    /// The user's choice from Settings; on by default.
    static var isCollectionEnabled: Bool {
        UserDefaults.standard.object(forKey: collectionEnabledKey) as? Bool ?? true
    }

    static func setCollectionEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: collectionEnabledKey)
        guard AppServices.isFirebaseConfigured else { return }
        Analytics.setAnalyticsCollectionEnabled(enabled)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    }

    static func log(_ event: Event, _ parameters: [String: Any]? = nil) {
        guard AppServices.isFirebaseConfigured else { return }
        Analytics.logEvent(event.rawValue, parameters: parameters)
    }

    /// Clears the analytics identifier, used by "Reset all local data".
    static func resetData() {
        guard AppServices.isFirebaseConfigured else { return }
        Analytics.resetAnalyticsData()
    }
}

// MARK: - Remote Config

/// Ad pacing values that can be tuned from the Firebase console without an app update.
/// The defaults here apply until a fetch succeeds (or when Firebase is not configured).
enum RemoteSettings {
    private enum Key: String {
        case adsEnabled = "ads_enabled"
        case bannerEnabled = "banner_enabled"
        case interstitialEnabled = "interstitial_enabled"
        case interstitialEveryNextTaps = "interstitial_every_next_taps"
        case interstitialMinIntervalSeconds = "interstitial_min_interval_seconds"
    }

    private static let defaults: [String: NSObject] = [
        Key.adsEnabled.rawValue: true as NSObject,
        Key.bannerEnabled.rawValue: true as NSObject,
        Key.interstitialEnabled.rawValue: true as NSObject,
        Key.interstitialEveryNextTaps.rawValue: 6 as NSObject,
        Key.interstitialMinIntervalSeconds.rawValue: 180 as NSObject
    ]

    static func activate() {
        guard AppServices.isFirebaseConfigured else { return }
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 12 * 60 * 60
        #endif
        config.configSettings = settings
        config.setDefaults(defaults)
        config.fetchAndActivate { _, error in
            #if DEBUG
            if let error { print("Remote Config fetch failed: \(error.localizedDescription)") }
            #endif
        }
    }

    static var adsEnabled: Bool { bool(.adsEnabled) }
    static var bannerEnabled: Bool { adsEnabled && bool(.bannerEnabled) }
    static var interstitialEnabled: Bool { adsEnabled && bool(.interstitialEnabled) }
    static var interstitialEveryNextTaps: Int { max(2, int(.interstitialEveryNextTaps)) }
    static var interstitialMinInterval: TimeInterval { TimeInterval(max(30, int(.interstitialMinIntervalSeconds))) }

    private static func bool(_ key: Key) -> Bool {
        guard AppServices.isFirebaseConfigured else { return (defaults[key.rawValue] as? Bool) ?? false }
        return RemoteConfig.remoteConfig()[key.rawValue].boolValue
    }

    private static func int(_ key: Key) -> Int {
        guard AppServices.isFirebaseConfigured else { return (defaults[key.rawValue] as? Int) ?? 0 }
        return RemoteConfig.remoteConfig()[key.rawValue].numberValue.intValue
    }
}
