import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Riverpod swallows stream/notifier errors by default — they only surface
/// as `AsyncValue.error` UI states, with nothing printed to the console.
/// This observer logs them in debug builds so failures are diagnosable.
base class _DebugProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    debugPrint('[ProviderObserver] ${context.provider.name ?? context.provider.runtimeType} failed: $error\n$stackTrace');
  }
}

void main() {
  runApp(
    ProviderScope(
      observers: [if (kDebugMode) _DebugProviderObserver()],
      child: const LifeyApp(),
    ),
  );
}
