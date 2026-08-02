# Handoff: Quote Sharing and Engagement Loop

Updated: 2026-08-03

## Summary

Daily Motivation has a lightweight, privacy-preserving sharing loop built on the
main quote screen. A share includes a rendered quote card, honest streak context,
and the app's direct App Store URL. Share intent and system-reported completion
are counted locally, and a short success toast appears only after a completed
share action.

## Product Context

The app's engagement loop is now:

1. Read a relevant quote from the personalized feed.
2. Complete a Daily Reset by choosing a need, reflecting, and taking an action.
3. Build a meaningful streak from completed resets rather than passive app opens.
4. Save useful quotes or share one with another person.

Sharing remains optional and does not claim that a challenge, referral program,
or social community exists.

## Share Behavior

Entry point:

- The Share button on the main quote screen is the only sharing entry point.

Share payload:

- A 1080 x 1350 quote card is rendered using the user's current theme,
  background style, and font selection.
- The text begins with `A quote from Daily Motivation:`.
- A positive streak adds an accurate `I'm on a N-day streak` line.
- A zero streak uses the neutral line `I found this quote in Daily Motivation.`.
- The current quote and author are included.
- The payload links directly to `https://apps.apple.com/app/id6756123822`.

Completion state:

- Tapping Share records a local share-intent event.
- If `UIActivityViewController` reports `completed == true`, the app records a
  completed share and displays an `Invite shared` toast.
- Cancelling the share sheet records no completed share and shows no toast.

## Measurement Hooks

Events are stored locally in `UserDefaults` through `EngagementTracker`:

- `share_clicked`: `EngagementTracker.logShareClicked()`
- `share_completed`: `EngagementTracker.logShareCompleted()`

Storage keys:

- `engagement.shareClickedCount`
- `engagement.shareCompletedCount`

The reflection library displays the lifetime completed-share count. These local
counters measure interaction with the share sheet; they do not prove that a
recipient viewed the message or installed the app.

## Main Files

- `DailyMotivation/ContentView.swift`
  - Opens the share sheet, logs events, and presents the completion toast.
- `DailyMotivation/QuoteShareCard.swift`
  - Renders the visual quote card.
- `DailyMotivation/ShareInviteMessageBuilder.swift`
  - Builds the truthful text payload and direct App Store call to action.
- `DailyMotivation/EngagementTracker.swift`
  - Persists share counters and meaningful Daily Reset streaks.
- `DailyMotivation/FavoritesView.swift`
  - Displays the completed-share count in the user's library summary.
- `DailyMotivationTests/ShareInviteLoopTests.swift`
  - Verifies the direct URL, honest copy, streak handling, and local counters.

## Verification Checklist

1. Launch the app and tap Share on the main quote screen.
2. Confirm that the share sheet contains a quote image and text payload.
3. Confirm that the text uses the direct App Store product URL.
4. Confirm that the streak statement matches the user's actual streak.
5. Cancel and verify that no success toast or completed-share increment appears.
6. Complete an action such as Copy, Messages, or Mail.
7. Confirm that the success toast appears and the library share count increments.

## Future Analytics

If a consent-aware analytics provider is introduced, the existing share-intent
and share-completion events can be forwarded without changing the user flow. Any
install or referral attribution should be implemented separately and described
accurately in the product copy and privacy policy.
