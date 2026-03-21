//
//  NotificationManager.swift
//  DailyMotivation
//
//  Created by Hung Luong on 4/8/25.
//

// MARK: - NotificationManager.swift

import Foundation
import UserNotifications

/// Manages scheduling and authorization for motivational quote notifications.
final class NotificationManager {
    /// Singleton for easy access.
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    enum Identifier {
        static let daily = "dailyQuoteNotification"
        static let morningBoost = "smartMorningNotification"
        static let windDown = "smartWindDownNotification"
        static let flexibleReminderPrefix = "quoteReminder"

        static func reminderRequestIdentifier(for schedule: ReminderSchedule, weekday: ReminderWeekday) -> String {
            reminderRequestIdentifier(forLogicalID: schedule.id, weekday: weekday)
        }

        static func reminderRequestIdentifier(forLogicalID logicalID: String, weekday: ReminderWeekday) -> String {
            "\(flexibleReminderPrefix).\(encodedLogicalID(logicalID)).\(weekday.rawValue)"
        }

        static func reminderRequestIdentifiers(for schedule: ReminderSchedule) -> [String] {
            schedule.normalizedWeekdays.map { reminderRequestIdentifier(for: schedule, weekday: $0) }
        }

        static func allReminderRequestIdentifiers(forLogicalID logicalID: String) -> [String] {
            ReminderWeekday.allCases.map { reminderRequestIdentifier(forLogicalID: logicalID, weekday: $0) }
        }

        private static func encodedLogicalID(_ logicalID: String) -> String {
            let trimmed = logicalID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return "empty"
            }

            return trimmed.utf8.map { String(format: "%02x", $0) }.joined()
        }
    }

    struct ReminderUpdateResult {
        let authorizationStatus: UNAuthorizationStatus
        let scheduledRequestIdentifiers: [String]
        let cancelledRequestIdentifiers: [String]
        let skippedReminderIdentifiers: [String]
        let failedRequestErrors: [String: String]

        var isAuthorized: Bool {
            NotificationManager.isAuthorizationAllowed(authorizationStatus)
        }
    }

    /// Requests notification authorization from the user.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
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

    /// Returns the current notification authorization status.
    func getAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    /// Schedules or replaces the provided reminder IDs without affecting unrelated reminders.
    func scheduleReminders(
        _ reminders: [ReminderNotification],
        completion: ((ReminderUpdateResult) -> Void)? = nil
    ) {
        let prepared = prepareReminderBatch(reminders)
        let requestIDsToRemove = prepared.logicalReminderIDs.flatMap {
            Identifier.allReminderRequestIdentifiers(forLogicalID: $0)
        }

        replaceScheduledRequests(
            with: prepared.requestPlans,
            removing: requestIDsToRemove,
            skippedReminderIdentifiers: prepared.logicalReminderIDs,
            initialFailures: prepared.failures,
            completion: completion
        )
    }

    /// Synchronizes the full flexible reminder set, cancelling any managed reminders not present in the new list.
    func updateReminders(
        _ reminders: [ReminderNotification],
        completion: ((ReminderUpdateResult) -> Void)? = nil
    ) {
        let prepared = prepareReminderBatch(reminders)

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }

            let existingManagedIDs = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("\(Identifier.flexibleReminderPrefix).") }

            let targetManagedIDs = prepared.logicalReminderIDs.flatMap {
                Identifier.allReminderRequestIdentifiers(forLogicalID: $0)
            }

            let requestIDsToRemove = Self.orderedUnique(existingManagedIDs + targetManagedIDs)

            self.replaceScheduledRequests(
                with: prepared.requestPlans,
                removing: requestIDsToRemove,
                skippedReminderIdentifiers: prepared.logicalReminderIDs,
                initialFailures: prepared.failures,
                completion: completion
            )
        }
    }

    /// Cancels flexible reminders by logical reminder ID.
    func cancelReminders(withIDs reminderIDs: [String]) {
        let requestIdentifiers = Self.orderedUnique(
            reminderIDs.flatMap { Identifier.allReminderRequestIdentifiers(forLogicalID: $0) }
        )
        cancelRequestIdentifiers(requestIdentifiers)
    }

    /// Cancels all managed flexible reminder requests.
    func cancelAllManagedReminders() {
        allManagedFlexibleRequestIdentifiers { [weak self] requestIdentifiers in
            self?.cancelRequestIdentifiers(requestIdentifiers)
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
        morningQuote: Quote?,
        morningEnabled: Bool,
        morningHour: Int,
        morningMinute: Int,
        eveningQuote: Quote?,
        eveningEnabled: Bool,
        eveningHour: Int,
        eveningMinute: Int
    ) {
        if morningEnabled, let morningQuote {
            scheduleQuoteNotification(
                identifier: Identifier.morningBoost,
                title: "Morning Boost",
                body: "\"\(morningQuote.quote)\" - \(morningQuote.author)",
                hour: morningHour,
                minute: morningMinute
            )
        } else {
            cancelNotifications(identifiers: [Identifier.morningBoost])
        }

        if eveningEnabled, let eveningQuote {
            scheduleQuoteNotification(
                identifier: Identifier.windDown,
                title: "Wind Down",
                body: "\"\(eveningQuote.quote)\" - \(eveningQuote.author)",
                hour: eveningHour,
                minute: eveningMinute
            )
        } else {
            cancelNotifications(identifiers: [Identifier.windDown])
        }
    }

    /// Cancels legacy notifications and optionally any flexible reminder IDs passed in.
    func cancelNotifications(identifiers: [String]? = nil) {
        if let identifiers {
            cancelRequestIdentifiers(expandedCancellationIdentifiers(from: identifiers))
            return
        }

        allManagedFlexibleRequestIdentifiers { [weak self] managedFlexibleIDs in
            guard let self else { return }

            let requestIdentifiers = Self.orderedUnique([
                Identifier.daily,
                Identifier.morningBoost,
                Identifier.windDown
            ] + managedFlexibleIDs)

            self.center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)
            self.center.removeAllDeliveredNotifications()
#if DEBUG
            print("Cancelled pending quote notifications: \(requestIdentifiers)")
#endif
        }
    }

    // MARK: - Private helpers

    private struct ScheduledRequestPlan {
        let identifier: String
        let title: String
        let body: String
        let hour: Int
        let minute: Int
        let weekday: ReminderWeekday?
        let playsSound: Bool
    }

    private struct PreparedReminderBatch {
        let logicalReminderIDs: [String]
        let requestPlans: [ScheduledRequestPlan]
        let failures: [String: String]
    }

    private func scheduleQuoteNotification(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int
    ) {
        let plan = ScheduledRequestPlan(
            identifier: identifier,
            title: title,
            body: body,
            hour: min(max(hour, 0), 23),
            minute: min(max(minute, 0), 59),
            weekday: nil,
            playsSound: true
        )

        replaceScheduledRequests(with: [plan], removing: [identifier])
    }

    private func prepareReminderBatch(_ reminders: [ReminderNotification]) -> PreparedReminderBatch {
        var logicalReminderIDs: [String] = []
        var requestPlans: [ScheduledRequestPlan] = []
        var failures: [String: String] = [:]

        for reminder in reminders {
            let logicalID = reminder.schedule.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !logicalID.isEmpty else {
                failures["<empty>"] = "Reminder identifier must not be empty."
                continue
            }

            logicalReminderIDs.append(logicalID)

            guard reminder.schedule.isEnabled else {
                continue
            }

            for weekday in reminder.schedule.normalizedWeekdays {
                requestPlans.append(
                    ScheduledRequestPlan(
                        identifier: Identifier.reminderRequestIdentifier(forLogicalID: logicalID, weekday: weekday),
                        title: reminder.title,
                        body: reminder.body,
                        hour: reminder.schedule.hour,
                        minute: reminder.schedule.minute,
                        weekday: weekday,
                        playsSound: reminder.playsSound
                    )
                )
            }
        }

        return PreparedReminderBatch(
            logicalReminderIDs: Self.orderedUnique(logicalReminderIDs),
            requestPlans: requestPlans,
            failures: failures
        )
    }

    private func replaceScheduledRequests(
        with requestPlans: [ScheduledRequestPlan],
        removing requestIdentifiersToRemove: [String],
        skippedReminderIdentifiers: [String] = [],
        initialFailures: [String: String] = [:],
        completion: ((ReminderUpdateResult) -> Void)? = nil
    ) {
        let uniqueRequestIdentifiersToRemove = Self.orderedUnique(requestIdentifiersToRemove)
        let lock = NSLock()

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            self.center.removePendingNotificationRequests(withIdentifiers: uniqueRequestIdentifiersToRemove)
            self.center.removeDeliveredNotifications(withIdentifiers: uniqueRequestIdentifiersToRemove)

            guard Self.isAuthorizationAllowed(settings.authorizationStatus) else {
#if DEBUG
                print("Cannot schedule notifications: authorization status is \(settings.authorizationStatus.rawValue).")
#endif
                let skipped = Self.orderedUnique(skippedReminderIdentifiers)
                self.finishReminderUpdate(
                    authorizationStatus: settings.authorizationStatus,
                    scheduledRequestIdentifiers: [],
                    cancelledRequestIdentifiers: uniqueRequestIdentifiersToRemove,
                    skippedReminderIdentifiers: skipped,
                    failedRequestErrors: initialFailures,
                    completion: completion
                )
                return
            }

            guard !requestPlans.isEmpty else {
                self.finishReminderUpdate(
                    authorizationStatus: settings.authorizationStatus,
                    scheduledRequestIdentifiers: [],
                    cancelledRequestIdentifiers: uniqueRequestIdentifiersToRemove,
                    skippedReminderIdentifiers: skippedReminderIdentifiers,
                    failedRequestErrors: initialFailures,
                    completion: completion
                )
                return
            }

            var scheduledRequestIdentifiers: [String] = []
            var failedRequestErrors = initialFailures
            let group = DispatchGroup()

            for requestPlan in requestPlans {
                group.enter()
                self.center.add(self.makeNotificationRequest(from: requestPlan)) { error in
                    lock.lock()
                    defer { lock.unlock() }

                    if let error {
                        failedRequestErrors[requestPlan.identifier] = error.localizedDescription
                    } else {
                        scheduledRequestIdentifiers.append(requestPlan.identifier)
#if DEBUG
                        if let weekday = requestPlan.weekday {
                            print("Scheduled reminder (\(requestPlan.identifier)) for weekday \(weekday.rawValue) at \(requestPlan.hour):\(String(format: "%02d", requestPlan.minute))")
                        } else {
                            print("Scheduled notification (\(requestPlan.identifier)) for \(requestPlan.hour):\(String(format: "%02d", requestPlan.minute))")
                        }
#endif
                    }

                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.finishReminderUpdate(
                    authorizationStatus: settings.authorizationStatus,
                    scheduledRequestIdentifiers: Self.orderedUnique(scheduledRequestIdentifiers),
                    cancelledRequestIdentifiers: uniqueRequestIdentifiersToRemove,
                    skippedReminderIdentifiers: skippedReminderIdentifiers,
                    failedRequestErrors: failedRequestErrors,
                    completion: completion
                )
            }
        }
    }

    private func makeNotificationRequest(from requestPlan: ScheduledRequestPlan) -> UNNotificationRequest {
        var dateComponents = DateComponents()
        dateComponents.hour = requestPlan.hour
        dateComponents.minute = requestPlan.minute
        dateComponents.weekday = requestPlan.weekday?.rawValue

        let content = UNMutableNotificationContent()
        content.title = requestPlan.title
        content.body = requestPlan.body
        content.sound = requestPlan.playsSound ? .default : nil

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        return UNNotificationRequest(identifier: requestPlan.identifier, content: content, trigger: trigger)
    }

    private func expandedCancellationIdentifiers(from identifiers: [String]) -> [String] {
        var requestIdentifiers = identifiers

        for identifier in identifiers {
            let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedIdentifier.isEmpty else {
                continue
            }

            if trimmedIdentifier.hasPrefix("\(Identifier.flexibleReminderPrefix).") {
                requestIdentifiers.append(trimmedIdentifier)
            } else {
                requestIdentifiers.append(contentsOf: Identifier.allReminderRequestIdentifiers(forLogicalID: trimmedIdentifier))
            }
        }

        return Self.orderedUnique(requestIdentifiers)
    }

    private func cancelRequestIdentifiers(_ requestIdentifiers: [String]) {
        let uniqueRequestIdentifiers = Self.orderedUnique(requestIdentifiers)
        guard !uniqueRequestIdentifiers.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: uniqueRequestIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: uniqueRequestIdentifiers)
#if DEBUG
        print("Cancelled pending quote notifications: \(uniqueRequestIdentifiers)")
#endif
    }

    private func allManagedFlexibleRequestIdentifiers(completion: @escaping ([String]) -> Void) {
        let lock = NSLock()
        let group = DispatchGroup()
        var identifiers: [String] = []

        group.enter()
        center.getPendingNotificationRequests { requests in
            lock.lock()
            identifiers += requests
                .map(\.identifier)
                .filter { $0.hasPrefix("\(Identifier.flexibleReminderPrefix).") }
            lock.unlock()
            group.leave()
        }

        group.enter()
        center.getDeliveredNotifications { notifications in
            lock.lock()
            identifiers += notifications
                .map(\.request.identifier)
                .filter { $0.hasPrefix("\(Identifier.flexibleReminderPrefix).") }
            lock.unlock()
            group.leave()
        }

        group.notify(queue: .main) {
            completion(Self.orderedUnique(identifiers))
        }
    }

    private func finishReminderUpdate(
        authorizationStatus: UNAuthorizationStatus,
        scheduledRequestIdentifiers: [String],
        cancelledRequestIdentifiers: [String],
        skippedReminderIdentifiers: [String],
        failedRequestErrors: [String: String],
        completion: ((ReminderUpdateResult) -> Void)?
    ) {
        guard let completion else { return }

        DispatchQueue.main.async {
            completion(
                ReminderUpdateResult(
                    authorizationStatus: authorizationStatus,
                    scheduledRequestIdentifiers: scheduledRequestIdentifiers,
                    cancelledRequestIdentifiers: cancelledRequestIdentifiers,
                    skippedReminderIdentifiers: skippedReminderIdentifiers,
                    failedRequestErrors: failedRequestErrors
                )
            )
        }
    }

    private static func isAuthorizationAllowed(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    private static func orderedUnique(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        return identifiers.filter { seen.insert($0).inserted }
    }
}
