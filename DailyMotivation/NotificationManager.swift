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
        static let quoteSequenceLength = 7
        static let managedQuoteSequenceSlotCount = 14
        static let maximumFlexibleReminderCount = 6

        static func quoteSequenceRequestIdentifier(base: String, index: Int) -> String {
            "\(base).scheduled.\(index)"
        }

        static func quoteSequenceRequestIdentifiers(base: String) -> [String] {
            (0..<managedQuoteSequenceSlotCount).map {
                quoteSequenceRequestIdentifier(base: base, index: $0)
            }
        }

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

    /// Schedules a seven-quote weekly rotation that continues without reopening the app.
    func scheduleDailyQuoteNotifications(quotes: [Quote], hour: Int, minute: Int) {
        scheduleQuoteNotificationSequence(
            identifier: Identifier.daily,
            title: "Daily Motivation",
            quotes: quotes,
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

    /// Schedules rotating morning and evening quote sequences.
    func scheduleSmartNotifications(
        morningQuotes: [Quote],
        morningEnabled: Bool,
        morningHour: Int,
        morningMinute: Int,
        eveningQuotes: [Quote],
        eveningEnabled: Bool,
        eveningHour: Int,
        eveningMinute: Int
    ) {
        if morningEnabled {
            scheduleQuoteNotificationSequence(
                identifier: Identifier.morningBoost,
                title: "Morning Boost",
                quotes: morningQuotes,
                hour: morningHour,
                minute: morningMinute
            )
        } else {
            cancelNotifications(identifiers: [Identifier.morningBoost])
        }

        if eveningEnabled {
            scheduleQuoteNotificationSequence(
                identifier: Identifier.windDown,
                title: "Wind Down",
                quotes: eveningQuotes,
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
            ] + Identifier.quoteSequenceRequestIdentifiers(base: Identifier.daily)
                + Identifier.quoteSequenceRequestIdentifiers(base: Identifier.morningBoost)
                + Identifier.quoteSequenceRequestIdentifiers(base: Identifier.windDown)
                + managedFlexibleIDs)

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
        let fireDate: Date?
        let repeats: Bool
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
            playsSound: true,
            fireDate: nil,
            repeats: true
        )

        replaceScheduledRequests(
            with: [plan],
            removing: [identifier] + Identifier.quoteSequenceRequestIdentifiers(base: identifier)
        )
    }

    private func scheduleQuoteNotificationSequence(
        identifier: String,
        title: String,
        quotes: [Quote],
        hour: Int,
        minute: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let sequenceIDs = Identifier.quoteSequenceRequestIdentifiers(base: identifier)
        let identifiersToRemove = [identifier] + sequenceIDs
        let limitedQuotes = Array(quotes.prefix(Identifier.quoteSequenceLength))
        let weekdays = Self.upcomingDeliveryWeekdays(
            count: limitedQuotes.count,
            hour: hour,
            minute: minute,
            now: now,
            calendar: calendar
        )

        let plans = zip(limitedQuotes, weekdays).enumerated().map { index, pair in
            let (quote, weekday) = pair
            return ScheduledRequestPlan(
                identifier: Identifier.quoteSequenceRequestIdentifier(base: identifier, index: index),
                title: title,
                body: "\"\(quote.quote)\" - \(quote.author)",
                hour: min(max(hour, 0), 23),
                minute: min(max(minute, 0), 59),
                weekday: weekday,
                playsSound: true,
                fireDate: nil,
                repeats: true
            )
        }

        replaceScheduledRequests(with: plans, removing: identifiersToRemove)
    }

    private func prepareReminderBatch(_ reminders: [ReminderNotification]) -> PreparedReminderBatch {
        var logicalReminderIDs: [String] = []
        var requestPlans: [ScheduledRequestPlan] = []
        var failures: [String: String] = [:]

        for reminder in reminders.prefix(Identifier.maximumFlexibleReminderCount) {
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
                        playsSound: reminder.playsSound,
                        fireDate: nil,
                        repeats: true
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
        let dateComponents: DateComponents
        if let fireDate = requestPlan.fireDate {
            dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
        } else {
            var repeatingComponents = DateComponents()
            repeatingComponents.hour = requestPlan.hour
            repeatingComponents.minute = requestPlan.minute
            repeatingComponents.weekday = requestPlan.weekday?.rawValue
            dateComponents = repeatingComponents
        }

        let content = UNMutableNotificationContent()
        content.title = requestPlan.title
        content.body = requestPlan.body
        content.sound = requestPlan.playsSound ? .default : nil

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: requestPlan.repeats
        )
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

            if [Identifier.daily, Identifier.morningBoost, Identifier.windDown].contains(trimmedIdentifier) {
                requestIdentifiers.append(contentsOf: Identifier.quoteSequenceRequestIdentifiers(base: trimmedIdentifier))
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

    static func upcomingDeliveryDates(
        count: Int,
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        guard count > 0 else { return [] }
        let safeHour = min(max(hour, 0), 23)
        let safeMinute = min(max(minute, 0), 59)
        var firstDay = calendar.startOfDay(for: now)

        guard let firstDate = calendar.date(
            bySettingHour: safeHour,
            minute: safeMinute,
            second: 0,
            of: firstDay
        ) else {
            return []
        }

        if firstDate <= now,
           let nextDay = calendar.date(byAdding: .day, value: 1, to: firstDay) {
            firstDay = nextDay
        }

        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            return calendar.date(
                bySettingHour: safeHour,
                minute: safeMinute,
                second: 0,
                of: day
            )
        }
    }

    static func upcomingDeliveryWeekdays(
        count: Int,
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar
    ) -> [ReminderWeekday] {
        upcomingDeliveryDates(
            count: count,
            hour: hour,
            minute: minute,
            now: now,
            calendar: calendar
        ).compactMap { date in
            ReminderWeekday(rawValue: calendar.component(.weekday, from: date))
        }
    }

    private static func orderedUnique(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        return identifiers.filter { seen.insert($0).inserted }
    }
}
