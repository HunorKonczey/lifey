import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'push_token_source.dart';

/// APNs-backed [PushTokenSource] for iOS via the native `lifey/push` platform
/// channel (see `PushChannel.swift`, docs/30-push-notifications-plan.md, M1).
/// Android registers through `firebase_messaging` instead
/// ([AndroidPushTokenSource], M1b) — this class no-ops on every other platform.
class IosPushTokenSource implements PushTokenSource {
  IosPushTokenSource() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _channel = MethodChannel('lifey/push');

  final _rotationController = StreamController<String>.broadcast();

  @override
  String get platform => 'IOS';

  @override
  Future<String?> getToken() async {
    if (!Platform.isIOS) return null;
    // PushChannel.swift resolves with the hex token, or nil on permission
    // denial / registration failure — it never rejects the platform call.
    return _channel.invokeMethod<String>('requestToken');
  }

  @override
  Stream<String> get onTokenRefreshed => _rotationController.stream;

  // PushChannel.swift invokes `onToken` when APNs re-delivers a token with
  // no pending requestToken call in flight (e.g. the OS rotated it while
  // the app was already registered).
  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onToken') return;
    final token = call.arguments as String?;
    if (token != null) _rotationController.add(token);
  }
}
