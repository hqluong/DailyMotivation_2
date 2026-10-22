// MARK: - AdsManager.swift

import AppTrackingTransparency
import FirebaseAnalytics
import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

/// Owns the ad lifecycle: consent (UMP), App Tracking Transparency, SDK start,
/// and interstitial pacing. Ads are never requested before consent allows it.
@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    /// True once consent allows ads and the SDK has started.
    @Published private(set) var canShowAds = false
    /// True when the user's region requires a "Privacy choices" entry in Settings.
    @Published private(set) var privacyOptionsRequired = false

    private var isStarting = false
    private var interstitial: InterstitialAd?
    private var isLoadingInterstitial = false
    private var nextTapsSinceInterstitial = 0
    private var lastInterstitialDate: Date?

    private static let lastInterstitialKey = "ads.lastInterstitialDate"

    /// Debug-only launch argument (-DMHideAds) for clean App Store screenshots.
    static var adsSuppressedForScreenshots: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-DMHideAds")
        #else
        return false
        #endif
    }

    static var bannerAdUnitID: String { infoValue("DMBannerAdUnitID") }
    static var interstitialAdUnitID: String { infoValue("DMInterstitialAdUnitID") }

    private override init() {
        super.init()
        lastInterstitialDate = UserDefaults.standard.object(forKey: Self.lastInterstitialKey) as? Date
    }

    // MARK: Startup

    /// Runs the consent flow, then the tracking prompt, then starts the Mobile Ads SDK.
    /// Call after onboarding so prompts never stack on top of the welcome screen.
    func startIfNeeded() {
        guard !isStarting, !canShowAds, RemoteSettings.adsEnabled, !Self.adsSuppressedForScreenshots else { return }
        isStarting = true

        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    #if DEBUG
                    print("Consent info update failed: \(error.localizedDescription)")
                    #endif
                }
                guard let presenter = UIApplication.shared.topViewController else {
                    self.finishConsent()
                    return
                }
                ConsentForm.loadAndPresentIfRequired(from: presenter) { [weak self] _ in
                    Task { @MainActor in self?.finishConsent() }
                }
            }
        }
    }

    private func finishConsent() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        updateAnalyticsConsent()
        guard ConsentInformation.shared.canRequestAds else {
            isStarting = false
            return
        }
        requestTrackingAuthorization { [weak self] in
            self?.startSDK()
        }
    }

    private func requestTrackingAuthorization(then completion: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            completion()
            return
        }
        // The system ignores the request unless the app is active, so wait a beat after any form.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async { completion() }
            }
        }
    }

    private func startSDK() {
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isStarting = false
                self.canShowAds = true
                self.loadInterstitialIfNeeded()
            }
        }
    }

    /// Mirrors the UMP decision into Firebase consent mode.
    private func updateAnalyticsConsent() {
        guard AppServices.isFirebaseConfigured else { return }
        let granted: FirebaseAnalytics.ConsentStatus = ConsentInformation.shared.canRequestAds ? .granted : .denied
        Analytics.setConsent([
            .analyticsStorage: AnalyticsLogger.isCollectionEnabled ? .granted : .denied,
            .adStorage: granted,
            .adUserData: granted,
            .adPersonalization: granted
        ])
    }

    /// Lets users in regions that require it change their consent (shown in Settings).
    func presentPrivacyOptions() {
        guard let presenter = UIApplication.shared.topViewController else { return }
        ConsentForm.presentPrivacyOptionsForm(from: presenter) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnalyticsConsent()
                if ConsentInformation.shared.canRequestAds {
                    self?.startIfNeeded()
                } else {
                    self?.canShowAds = false
                }
            }
        }
    }

    // MARK: Interstitials

    /// Counts a "Next quote" tap and shows an interstitial when the pacing rules allow:
    /// every N taps (Remote Config), never sooner than the minimum interval.
    func registerNextTap() {
        guard canShowAds, RemoteSettings.interstitialEnabled else { return }
        nextTapsSinceInterstitial += 1
        guard nextTapsSinceInterstitial >= RemoteSettings.interstitialEveryNextTaps else { return }
        if let last = lastInterstitialDate,
           Date().timeIntervalSince(last) < RemoteSettings.interstitialMinInterval {
            return
        }
        guard let ad = interstitial, let presenter = UIApplication.shared.topViewController else {
            loadInterstitialIfNeeded()
            return
        }
        ad.present(from: presenter)
        interstitial = nil
        nextTapsSinceInterstitial = 0
        lastInterstitialDate = Date()
        UserDefaults.standard.set(lastInterstitialDate, forKey: Self.lastInterstitialKey)
    }

    private func loadInterstitialIfNeeded() {
        guard canShowAds, RemoteSettings.interstitialEnabled, interstitial == nil, !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        InterstitialAd.load(with: Self.interstitialAdUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingInterstitial = false
                if let error {
                    #if DEBUG
                    print("Interstitial failed to load: \(error.localizedDescription)")
                    #endif
                    return
                }
                ad?.fullScreenContentDelegate = self
                self.interstitial = ad
            }
        }
    }

    private static func infoValue(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.loadInterstitialIfNeeded() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.loadInterstitialIfNeeded() }
    }
}

// MARK: - Banner

/// Inline adaptive banner, capped at 60pt so it never crowds the quote card.
struct AdBannerView: View {
    @ObservedObject private var ads = AdsManager.shared
    /// Height of the loaded ad; stays 0 (no empty gap) until an ad actually arrives.
    @State private var loadedHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            if ads.canShowAds, RemoteSettings.bannerEnabled {
                BannerContainer(width: geometry.size.width, loadedHeight: $loadedHeight)
                    .frame(width: geometry.size.width, height: max(loadedHeight, 1))
            }
        }
        .frame(height: ads.canShowAds && RemoteSettings.bannerEnabled ? loadedHeight : 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Advertisement")
    }
}

private struct BannerContainer: UIViewRepresentable {
    let width: CGFloat
    @Binding var loadedHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(loadedHeight: $loadedHeight) }

    /// Google's anchored size can reach ~130pt on large phones; a capped inline size keeps Home calm.
    static func adSize(for width: CGFloat) -> AdSize {
        inlineAdaptiveBanner(width: width, maxHeight: 60)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: BannerContainer.adSize(for: width))
        banner.adUnitID = AdsManager.bannerAdUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.topViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        let size = BannerContainer.adSize(for: width)
        if !CGSizeEqualToSize(banner.adSize.size, size.size) {
            banner.adSize = size
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var loadedHeight: CGFloat
        init(loadedHeight: Binding<CGFloat>) { _loadedHeight = loadedHeight }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            loadedHeight = bannerView.adSize.size.height
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            loadedHeight = 0
        }
    }
}

// MARK: - Presenter lookup

extension UIApplication {
    /// The frontmost view controller, used to present consent forms and full-screen ads.
    var topViewController: UIViewController? {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
