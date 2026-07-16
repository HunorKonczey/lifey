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
/// launches LifeyWatch and delivers the workout configuration here — this is
/// the F0 spike's end-to-end proof. F2 replaces the body with a real
/// `WorkoutManager.start(configuration:)` call.
final class AppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        LastLaunchConfiguration.shared.received(workoutConfiguration)
    }
}

/// Minimal observable bridge so `ContentView` can show that `handle(_:)`
/// fired, without any real session/UI logic yet (that's F2's
/// `WorkoutManager`).
final class LastLaunchConfiguration: ObservableObject {
    static let shared = LastLaunchConfiguration()

    @Published private(set) var activityTypeRawValue: UInt?

    func received(_ configuration: HKWorkoutConfiguration) {
        activityTypeRawValue = configuration.activityType.rawValue
    }
}
