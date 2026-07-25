import Flutter
import Foundation
import MediaPlayer
import UIKit

/// Handles the `lifey/music` MethodChannel + `lifey/music/events` EventChannel
/// for the Apple Music branch of `MusicService`
/// (mobile/lib/core/music/music_service_ios.dart) —
/// docs/music/46-workout-music-controls-plan.md §2.2, M3. Registered in
/// AppDelegate, mirroring WatchBridge/LiveActivityChannel/PushChannel. Reuses
/// the same channel names `MediaSessionBridge.kt` uses on Android (a build
/// only ever registers one native side or the other) and emits the same
/// payload shape (`MusicSessionState.fromJson`/`MusicPlaybackState.fromJson`
/// in music_service.dart).
///
/// `music_service_ios.dart` only ever forwards calls here while the
/// device-local choice is `MusicProviderId.appleMusic` — Spotify (M4) isn't
/// wired to a bridge yet and never reaches this class.
final class AppleMusicBridge: NSObject {
  static let channelName = "lifey/music"
  static let eventChannelName = "lifey/music/events"

  private let player = MPMusicPlayerController.systemMusicPlayer
  private var eventSink: FlutterEventSink?
  private var isActive = false
  private var isObserving = false

  @discardableResult
  static func register(with registrar: FlutterPluginRegistrar) -> AppleMusicBridge {
    let instance = AppleMusicBridge()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
    let eventChannel = FlutterEventChannel(
      name: eventChannelName, binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
    return instance
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "activate", "selectProvider":
      activate(call)
      result(nil)
    case "deactivate":
      deactivate()
      result(nil)
    case "play":
      player.play()
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "next":
      player.skipToNextItem()
      result(nil)
    case "previous":
      player.skipToPreviousItem()
      result(nil)
    case "openProviderApp":
      openMusicApp()
      result(nil)
    case "requestPermission":
      requestPermission()
      result(nil)
    case "refresh":
      emitCurrentState()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Lifecycle (docs/music/46-workout-music-controls-plan.md §3.3)

  /// Handles both `activate` (session start/resume) and `selectProvider` (a
  /// live switch mid-session) — Dart only ever sends `providerId:
  /// "appleMusic"` here, but the guard is defensive in case that ever
  /// changes.
  private func activate(_ call: FlutterMethodCall) {
    guard let args = call.arguments as? [String: Any],
      args["providerId"] as? String == MusicProviderId.appleMusic.rawValue
    else { return }
    isActive = true
    startObservingIfNeeded()
    emitCurrentState()
  }

  private func deactivate() {
    isActive = false
    stopObserving()
  }

  private func startObservingIfNeeded() {
    guard !isObserving else { return }
    isObserving = true
    player.beginGeneratingPlaybackNotifications()
    NotificationCenter.default.addObserver(
      self, selector: #selector(playbackStateChanged),
      name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
    NotificationCenter.default.addObserver(
      self, selector: #selector(nowPlayingItemChanged),
      name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
  }

  private func stopObserving() {
    guard isObserving else { return }
    isObserving = false
    NotificationCenter.default.removeObserver(
      self, name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
    NotificationCenter.default.removeObserver(
      self, name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
    player.endGeneratingPlaybackNotifications()
  }

  @objc private func playbackStateChanged() { emitCurrentState() }
  @objc private func nowPlayingItemChanged() { emitCurrentState() }

  // MARK: - Permission (docs/music/46-workout-music-controls-plan.md §2.2) —
  // the iOS analogue of Android's notification-access grant: reading
  // `nowPlayingItem` metadata requires `MPMediaLibrary` authorization.

  private func requestPermission() {
    MPMediaLibrary.requestAuthorization { [weak self] _ in
      DispatchQueue.main.async {
        self?.emitCurrentState()
      }
    }
  }

  /// The empty state's "Open {provider}" CTA (§3.5) — `music://` requires
  /// declaring the `music` scheme in `LSApplicationQueriesSchemes`
  /// (Info.plist), same as `canOpenURL` would.
  private func openMusicApp() {
    guard let url = URL(string: "music://") else { return }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }

  // MARK: - State

  private func emitCurrentState() {
    guard isActive else { return }
    eventSink?(currentStatePayload())
  }

  private func currentStatePayload() -> [String: Any] {
    guard MPMediaLibrary.authorizationStatus() == .authorized else {
      return [
        "status": "permissionNeeded", "provider": MusicProviderId.appleMusic.rawValue,
        "playback": NSNull(),
      ]
    }
    guard let item = player.nowPlayingItem else {
      return [
        "status": "noActiveSession", "provider": MusicProviderId.appleMusic.rawValue,
        "playback": NSNull(),
      ]
    }
    let playback: [String: Any] = [
      "title": orNull(item.title),
      "artist": orNull(item.artist),
      "artworkPng": orNull(artworkPng(for: item)),
      "isPlaying": player.playbackState == .playing,
    ]
    return [
      "status": "connected", "provider": MusicProviderId.appleMusic.rawValue,
      "playback": playback,
    ]
  }

  /// Downscaled to match `MediaSessionBridge.kt`'s artwork handling (max
  /// 300 px) — the sheet only ever renders this at 64x64.
  private func artworkPng(for item: MPMediaItem) -> FlutterStandardTypedData? {
    guard let artwork = item.artwork,
      let image = artwork.image(at: CGSize(width: 300, height: 300)),
      let data = image.pngData()
    else { return nil }
    return FlutterStandardTypedData(bytes: data)
  }

  private func orNull(_ value: Any?) -> Any {
    value ?? NSNull()
  }
}

/// Mirrors the Dart `MusicProviderId` enum's member names
/// (mobile/lib/core/music/music_provider_id.dart) — only `appleMusic` is ever
/// used natively here, but kept as an enum (not a bare string literal) so a
/// typo doesn't silently desync from the Dart side.
private enum MusicProviderId: String {
  case appleMusic
}

// MARK: - FlutterStreamHandler

extension AppleMusicBridge: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    if isActive { emitCurrentState() }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
