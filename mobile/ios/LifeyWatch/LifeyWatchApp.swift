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
    // Reattaches to a standalone session still running after a process
    // death/reboot (docs/watch/44-watch-f6-standalone-plan.md §3.2) — a
    // no-op if none is active, which is the common case.
    Task { @MainActor in
      await WorkoutManager.shared.recoverStandaloneSessionIfNeeded()
    }
  }

  func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
    Task { @MainActor in
      await WorkoutManager.shared.start(configuration: workoutConfiguration)
    }
  }
}
