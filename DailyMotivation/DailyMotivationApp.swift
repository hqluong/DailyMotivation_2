// MARK: - DailyMotivationApp.swift

import SwiftUI

/// The main entry point for the DailyMotivation app.
@main
struct DailyMotivationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
