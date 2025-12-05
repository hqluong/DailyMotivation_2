//
//  NotificationManager.swift
//  DailyMotivation
//
//  Created by Hung Luong on 4/8/25.
//

// MARK: - NotificationManager.swift

import UserNotifications
import Foundation

/// Manages scheduling and authorization for daily motivational quote notifications.
class NotificationManager {
    /// Singleton for easy access
    static let shared = NotificationManager()
    private init() {}

    enum Identifier {
        static let daily = "dailyQuoteNotification"
        static let morningBoost = "smartMorningNotification"
        static let windDown = "smartWindDownNotification"
    }

    /// Requests notification authorization from the user.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
#if DEBUG
                print("Error requesting notification authorization: \(error.localizedDescription)")
#endif
            }
#if DEBUG
            print("Notification permission granted: \(granted)")
#endif
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Schedules a daily notification with the given quote at the specified time.
    func scheduleDailyQuoteNotification(quote: Quote, hour: Int, minute: Int) {
        scheduleQuoteNotification(
            identifier: Identifier.daily,
            title: "Daily Motivation",
            body: "\"\(quote.quote)\" - \(quote.author)",
            hour: hour,
            minute: minute
        )
    }

    /// Schedules optional "Smart" notifications (e.g., morning boost and wind down).
    func scheduleSmartNotifications(
        quote: Quote,
        morningEnabled: Bool,
        morningHour: Int,
        morningMinute: Int,
        eveningEnabled: Bool,
        eveningHour: Int,
        eveningMinute: Int
    ) {
        if morningEnabled {
            scheduleQuoteNotification(
                identifier: Identifier.morningBoost,
                title: "Morning Boost",
                body: "\"\(quote.quote)\" — \(quote.author)",
                hour: morningHour,
                minute: morningMinute
            )
        } else {
            cancelNotifications(identifiers: [Identifier.morningBoost])
        }

        if eveningEnabled {
            scheduleQuoteNotification(
                identifier: Identifier.windDown,
                title: "Wind Down",
                body: "\"\(quote.quote)\" — \(quote.author)",
                hour: eveningHour,
                minute: eveningMinute
            )
        } else {
            cancelNotifications(identifiers: [Identifier.windDown])
        }
    }

    /// Cancels all pending and delivered quote notifications.
    func cancelNotifications(identifiers: [String]? = nil) {
        let center = UNUserNotificationCenter.current()
        let ids = identifiers ?? [Identifier.daily, Identifier.morningBoost, Identifier.windDown]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeAllDeliveredNotifications()
#if DEBUG
        print("Cancelled pending quote notifications: \(ids)")
#endif
    }

    // MARK: - Private helpers

    private func scheduleQuoteNotification(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
#if DEBUG
                print("Cannot schedule notification (\(identifier)): Not authorized.")
#endif
                return
            }

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.add(request) { error in
                if let error {
#if DEBUG
                    print("Error scheduling notification (\(identifier)): \(error.localizedDescription)")
#endif
                } else {
#if DEBUG
                    print("Scheduled notification (\(identifier)) for \(hour):\(String(format: "%02d", minute))")
#endif
                }
            }
        }
    }
}
