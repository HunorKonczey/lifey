import 'dart:io' show Platform;

/// The music apps the workout screen can control
/// (docs/music/46-workout-music-controls-plan.md).
enum MusicProviderId { spotify, appleMusic, youtubeMusic }

extension MusicProviderIdX on MusicProviderId {
  /// Brand name — never localized (docs/music/46-workout-music-controls-plan.md §3.6).
  String get displayName => switch (this) {
        MusicProviderId.spotify => 'Spotify',
        MusicProviderId.appleMusic => 'Apple Music',
        MusicProviderId.youtubeMusic => 'YouTube Music',
      };

  /// Single-letter (or two-letter) placeholder glyph shown in the monochrome
  /// monogram circle until real brand icons are sourced
  /// (docs/music/46-workout-music-controls-plan.md §6.7).
  String get monogram => switch (this) {
        MusicProviderId.spotify => 'S',
        MusicProviderId.appleMusic => 'A',
        MusicProviderId.youtubeMusic => 'YT',
      };

  /// Whether this provider can be controlled *at all* on the running
  /// platform — the support matrix from
  /// docs/music/46-workout-music-controls-plan.md §2.3. Only YouTube Music
  /// has a real gap: iOS has no control API or SDK for it, full stop. Every
  /// other combination is at least theoretically controllable (whether the
  /// app is actually installed is a separate, runtime question — see
  /// `MusicService.isProviderInstalled`).
  bool get isSupportedOnThisPlatform {
    if (this == MusicProviderId.youtubeMusic && Platform.isIOS) return false;
    return Platform.isIOS || Platform.isAndroid;
  }
}
