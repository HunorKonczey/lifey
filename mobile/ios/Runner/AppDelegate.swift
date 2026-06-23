import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Detects Apple Fitness strength-workout completions via HealthKit and
  /// forwards them to Dart (docs/16-apple-health-integration-plan.md, Phase
  /// 1). Held here so it isn't deallocated once this method returns — its
  /// HKObserverQuery must stay alive for the app's lifetime.
  private var healthWorkoutObserver: HealthWorkoutObserver?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HealthWorkoutObserverPlugin") else {
      NSLog("[HealthWorkoutObserver] registrar(forPlugin:) returned nil — observer NOT registered")
      return
    }
    NSLog("[HealthWorkoutObserver] registrar obtained, creating observer")
    healthWorkoutObserver = HealthWorkoutObserver(messenger: registrar.messenger())
  }
}
