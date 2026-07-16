import HealthKit
import SwiftUI

@main
struct LifeyWatchApp: App {
  @WKApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

/// `startWatchApp(with:)` on the phone (docs/40-watch-app-plan.md §0, §4.3)
/// launches LifeyWatch and delivers the workout configuration here — the
/// entry point into the real `WorkoutManager.start(configuration:)`.
final class AppDelegate: NSObject, WKApplicationDelegate {
  func applicationDidFinishLaunching() {
    // As early as possible, so a `transferUserInfo`/applicationContext
    // already queued by the phone isn't missed.
    PhoneConnector.shared.activate()
  }

  func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    Task { @MainActor in
      await WorkoutManager.shared.start(configuration: workoutConfiguration)
    }
  }
}
