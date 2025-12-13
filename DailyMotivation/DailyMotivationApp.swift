// MARK: - DailyMotivationApp.swift

import SwiftUI
import UIKit

/// App delegate used to lock orientation to portrait.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return [.portrait, .portraitUpsideDown]
    }
}

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
