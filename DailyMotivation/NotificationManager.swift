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

    let notificationIdentifier = "dailyQuoteNotification"

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
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
#if DEBUG
                print("Cannot schedule notification: Not authorized.")
#endif
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Daily Motivation"
            content.body = "\"\(quote.quote)\" - \(quote.author)"
            content.sound = UNNotificationSound.default
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: self.notificationIdentifier, content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: [self.notificationIdentifier])
            center.add(request) { error in
                if let error = error {
#if DEBUG
                    print("Error scheduling notification: \(error.localizedDescription)")
#endif
                } else {
#if DEBUG
                    print("Daily notification scheduled successfully for \(hour):\(String(format: "%02d", minute)) with quote ID: \(quote.id)")
#endif
                }
            }
        }
    }

    /// Cancels all pending and delivered daily quote notifications.
    func cancelNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        center.removeAllDeliveredNotifications()
#if DEBUG
        print("Cancelled pending daily notifications.")
#endif
    }
}
