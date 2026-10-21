# Daily Motivation 1.2 (build 2) — release checklist

Archive: `~/Library/Developer/Xcode/Archives/2026-10-21/DailyMotivation 1.2 (2).xcarchive`
(open Xcode → Window → Organizer → Archives). Built 2026-10-21 from the **uncommitted** working tree on `codex-ui-search-category-polish`.

## Changed for release (already done)
- [x] `MARKETING_VERSION` 1.1 → **1.2** and `CURRENT_PROJECT_VERSION` 1.1 → **2**, app and widget. 1.1 is already live on the App Store, so a 1.1 upload would be rejected.
- [x] Added `DailyMotivation/PrivacyInfo.xcprivacy`: no tracking, no collected data, UserDefaults reason `CA92.1`. Without this, App Store Connect flags the upload with ITMS-91053 (missing API declaration).
- [x] `ITSAppUsesNonExemptEncryption = NO` for the app. Uploads no longer ask about export compliance.
- [x] Checked the archive: bundle IDs `com.hungluong.Daily-Motivation` / `.widget`, versions 1.2 (2), the widget is embedded, the privacy manifest is present and valid, and it's signed by team 7X6A72UQS3.

## Before you upload
- [ ] Review the diff and **commit** (UX/UI work + release changes), ideally tag `v1.2`. The archive was built from these uncommitted changes.
- [ ] Delete the leftover `build/` folder in the repo (only an `archive.log`).
- [ ] Quick test on a real iPhone (Release build): onboarding, search, Daily Reset, Library undo, notifications on/off, Contact support (opens Mail, or copies the address if no mail app is set up), and the widget.

## Upload (Xcode Organizer)
1. Select the 1.2 (2) archive → **Validate App** → fix anything it reports.
2. **Distribute App** → **App Store Connect** → **Upload** (automatic signing will create the distribution profile).
3. Wait for the build to finish processing in App Store Connect (TestFlight tab), then optionally test via TestFlight.

## App Store Connect — version 1.2
- [ ] Create version **1.2** and attach build 2.
- [ ] "What's New" text (draft below).
- [ ] **Screenshots**: the Home, Library, Daily Reset and Settings screens changed visibly. Update the 6.9" iPhone set, and the 13" iPad set since the app supports iPad.
- [ ] **App Privacy** answers: still "Data Not Collected" (everything stays on device, no analytics). Matches the new privacy manifest.
- [ ] **Privacy Policy URL**: make sure the hosted policy reflects the updated support email from commit ac3d7d3.
- [ ] Support URL / contact email current.
- [ ] Submit for review.

## Draft "What's New"
> • Search now shows every matching quote. Tap one to open it.
> • Your daily quote stays put when you browse categories.
> • New Next button, plus a streak counter you can tap anytime.
> • Daily Reset: change your need, clearer completion, and your streak at a glance.
> • Library: tap a favorite to open it, and undo removals.
> • Themes now carry through Settings, Library and Daily Reset.
> • Better Dynamic Type, VoiceOver and contrast support, and a heads-up when notifications are off.

## Known, not blocking
- No in-app privacy policy link (Apple only requires the URL in App Store Connect).
- The widget shows its own quote list; it doesn't share favorites/streak with the app (no App Group). Unchanged from 1.1.
- Onboarding keeps its own dark style.
