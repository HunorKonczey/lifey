import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../domain/workout_session.dart';

/// The name shown on an imported session's source chip and its session-row
/// line (docs/integrations/89 G1.7): the source app the health store
/// reported, e.g. "Garmin Connect". It falls back to the platform's own
/// store name when that is missing. Like the existing "Heart rate from
/// {source}" line, it is a product name and never translated.
String importSourceName(WorkoutSession session) {
  final app = session.importAppName;
  if (app != null && app.trim().isNotEmpty) return app;
  if (kIsWeb) return 'Health Connect';
  return Platform.isIOS ? 'Apple Health' : 'Health Connect';
}
