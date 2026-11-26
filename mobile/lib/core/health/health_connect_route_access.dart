import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Health Connect *Exercise routes* permission, which the `health` plugin
/// can neither request nor report (docs/integrations/89 G1.8, LIF-223).
/// Without it, an imported Garmin run arrives without its route. The user
/// has to grant it in Health Connect, so the cardio-import settings hint
/// asks this whether that has happened and opens Health Connect so it can.
///
/// Android only (`HealthConnectBridge.kt`). iOS asks for routes in the
/// ordinary HealthKit request, so [isAvailable] is false there.
class HealthConnectRouteAccess {
  HealthConnectRouteAccess({MethodChannel? channel, bool? isAvailable})
      : _channel = channel ?? const MethodChannel('lifey/health_connect'),
        isAvailable = isAvailable ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool isAvailable;

  /// True or false from Android 14, where Health Connect permissions are
  /// runtime permissions. Null when that can't be known: below Android 14,
  /// off Android, or on a channel error.
  Future<bool?> routePermissionGranted() async {
    if (!isAvailable) return null;
    try {
      return await _channel.invokeMethod<bool>('routePermissionGranted');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens Health Connect, where Lifey is one tap away. From Android 14 an app
  /// may not open its own Health Connect permission page (that needs a
  /// system permission), so this is as deep as it gets. False when nothing
  /// opened.
  Future<bool> openHealthConnect() async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('openHealthConnect') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final healthConnectRouteAccessProvider = Provider<HealthConnectRouteAccess>((ref) => HealthConnectRouteAccess());

/// Whether the *Exercise routes* permission is granted ([HealthConnectRouteAccess.routePermissionGranted]).
/// The hint row invalidates it on every app resume, since the user grants it
/// in another app.
final exerciseRoutesGrantedProvider = FutureProvider.autoDispose<bool?>(
  (ref) => ref.watch(healthConnectRouteAccessProvider).routePermissionGranted(),
);
