# Daily Motivation 1.2 (build 3) — release checklist

Archive: `~/Library/Developer/Xcode/Archives/2026-10-21/DailyMotivation 1.2 (2).xcarchive`
(open Xcode → Window → Organizer → Archives). Rebuilt 2026-10-21 from commit `962e3c2` on `codex-ui-search-category-polish`. Min iOS 16.6. A local App Store export signed cleanly (Cloud Managed Apple Distribution, team 7X6A72UQS3).

## Build 3: Firebase + AdMob (added 2026-10-21, uncommitted)
Build 2 was uploaded but should **not** be submitted: build 3 replaces it.
- [x] Firebase 12.19 (Analytics, Crashlytics, Remote Config) and Google Mobile Ads 13.11 + UMP 3.1 via Swift Package Manager.
- [x] Consent flow after onboarding: Google consent form (EEA/UK/CH) → Apple tracking prompt → ads. Settings has "Share usage and crash data" and, where required, "Ad privacy choices".
- [x] Ads: 60pt banner under the Home actions; interstitial at most every 6 Next taps and 3 minutes apart (tunable in Remote Config: `ads_enabled`, `banner_enabled`, `interstitial_enabled`, `interstitial_every_next_taps`, `interstitial_min_interval_seconds`).
- [x] `privacy-policy/index.html` rewritten for AdMob/Firebase. **Publish it** to the URL set in App Store Connect before submitting.
- [x] Added `DailyMotivation/GoogleService-Info.plist` (gitignored, since this repo is public; re-download it from Firebase → Project settings on a new Mac).
- [x] Real AdMob IDs set for **Release** (`GAD_APPLICATION_ID`, `DM_BANNER_AD_UNIT_ID`, `DM_INTERSTITIAL_AD_UNIT_ID`). Debug keeps Google's test IDs; Release fails to build if test/placeholder IDs return.
- [ ] In AdMob: create the consent messages (GDPR, and optionally the IDFA explainer) under Privacy & messaging; add `app-ads.txt` to your developer website.
- [ ] Archive 1.2 (3), validate, upload.

### App Store Connect → App Privacy (must change from "Data Not Collected")
Based on Google's disclosure guidance for AdMob + Firebase Analytics/Crashlytics. Confirm against your AdMob/Firebase settings:
- **Identifiers → Device ID**: used for Third-Party Advertising and Analytics; **used for tracking** (IDFA when allowed).
- **Usage Data → Product Interaction**: Analytics. **Advertising Data**: Third-Party Advertising.
- **Location → Coarse Location** (IP-derived): Third-Party Advertising.
- **Diagnostics → Crash Data, Performance Data**: App Functionality.
- None linked to the user's identity (no accounts).

## Changed for release (already done)
- [x] `MARKETING_VERSION` 1.1 → **1.2** and `CURRENT_PROJECT_VERSION` 1.1 → **2**, app and widget. 1.1 is already live on the App Store, so a 1.1 upload would be rejected.
- [x] Added `DailyMotivation/PrivacyInfo.xcprivacy`: no tracking, no collected data, UserDefaults reason `CA92.1`. Without this, App Store Connect flags the upload with ITMS-91053 (missing API declaration).
- [x] `ITSAppUsesNonExemptEncryption = NO` for the app. Uploads no longer ask about export compliance.
- [x] Checked the archive: bundle IDs `com.hungluong.Daily-Motivation` / `.widget`, versions 1.2 (2), the widget is embedded, the privacy manifest is present and valid, and it's signed by team 7X6A72UQS3.

## Before you upload
- [x] Committed (`f85c7b9`, `962e3c2`). Optional: tag `v1.2` after upload.
- [x] Removed the leftover `build/` folder.
- [ ] Quick test on a real iPhone (Release build): onboarding, search, Daily Reset, Library undo, notifications on/off, Contact support (opens Mail, or copies the address if no mail app is set up), and the widget.

## Upload (Xcode Organizer)
1. Select the 1.2 (2) archive → **Validate App** → fix anything it reports.
2. **Distribute App** → **App Store Connect** → **Upload** (automatic signing will create the distribution profile).
3. Wait for the build to finish processing in App Store Connect (TestFlight tab), then optionally test via TestFlight.

## App Store Connect — version 1.2
- [ ] Create version **1.2** and attach build 2.
- [ ] "What's New" text (draft below).
- [x] **Screenshots** captured in `AppStoreScreenshots/1.2/`: 6 for 6.9" iPhone (1320×2868) and 4 for 13" iPad (2064×2752). Drag them into App Store Connect in the order you like (02-home is the best first shot).
- [ ] **App Privacy** answers: still "Data Not Collected" (everything stays on device, no analytics). Matches the new privacy manifest.
- [ ] **Privacy Policy URL**: confirm the URL already set in App Store Connect is live and shows the updated support email from ac3d7d3. (`hqluong.github.io/DailyMotivation_2/privacy-policy/` returns 404, so it's hosted elsewhere or not yet published.)
- [ ] Support URL / contact email current.
- [ ] Submit for review.

## Draft "What's New" (unchanged; ads don't need a mention)
> • Search now shows every matching quote. Tap one to open it.
> • Your daily quote stays put when you browse categories.
> • New Next button, plus a streak counter you can tap anytime.
> • Daily Reset: change your need, clearer completion, and your streak at a glance.
> • Library: tap a favorite to open it, and undo removals.
> • Themes now carry through Settings, Library and Daily Reset.
> • Better Dynamic Type, VoiceOver and contrast support, and a heads-up when notifications are off.

## Found while capturing screenshots (fixed in 962e3c2)
- The Library button could stop responding after closing search, until the app was relaunched.
- The first day's "read" count stayed at 0 right after onboarding.
- Xcode silently changed the deployment target to "recommended" when it opened the project. Reverted to 16.6; if Xcode offers "Update to recommended settings", decline it, or iOS 16–17 users get dropped.

## Known, not blocking
- No in-app privacy policy link (Apple only requires the URL in App Store Connect).
- The widget shows its own quote list; it doesn't share favorites/streak with the app (no App Group). Unchanged from 1.1.
- Onboarding keeps its own dark style.
