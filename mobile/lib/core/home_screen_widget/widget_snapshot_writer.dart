import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart' show Locale;
import 'package:home_widget/home_widget.dart' as home_widget;

import '../../features/dashboard/domain/daily_stats.dart';
import '../../features/settings/domain/user_settings.dart';
import '../../l10n/app_localizations.dart';

/// App Group shared with the LifeyWidgets extension (see
/// Runner.entitlements and docs/24-ios-widget-live-activity-plan.md). Must
/// match the App Group registered on the Apple Developer portal and ticked
/// on both Xcode targets.
const widgetAppGroupId = 'group.com.khunor.lifey';

const _snapshotKey = 'today_snapshot';
const _iOSWidgetName = 'TodaySummaryWidget';

/// Builds the widget snapshot JSON (see the "Widget snapshot" data contract
/// in docs/24-ios-widget-live-activity-plan.md) and pushes it to the App
/// Group + triggers a WidgetKit timeline reload.
///
/// No-ops on non-iOS, same pattern as [HealthService]/[NotificationService].
/// The `home_widget` calls are injectable so tests can assert on what was
/// written without touching platform channels.
class WidgetSnapshotWriter {
  WidgetSnapshotWriter({
    Future<bool?> Function(String key, String value)? saveWidgetData,
    Future<bool?> Function()? updateWidget,
    bool? isAvailable,
  })  : _saveWidgetData = saveWidgetData ?? _defaultSaveWidgetData,
        _updateWidget = updateWidget ?? _defaultUpdateWidget,
        isAvailable = isAvailable ?? Platform.isIOS;

  final Future<bool?> Function(String key, String value) _saveWidgetData;
  final Future<bool?> Function() _updateWidget;

  static Future<bool?> _defaultSaveWidgetData(String key, String value) =>
      home_widget.HomeWidget.saveWidgetData<String>(key, value, appGroupId: widgetAppGroupId);

  static Future<bool?> _defaultUpdateWidget() =>
      home_widget.HomeWidget.updateWidget(iOSName: _iOSWidgetName);

  /// Defaults to [Platform.isIOS]; overridable in the constructor so tests
  /// can exercise [write] on non-iOS test hosts.
  final bool isAvailable;

  /// Writes the current snapshot. Callers pass already-loaded state
  /// ([WidgetSnapshotController] derives these from the dashboard/steps/
  /// settings providers) rather than this class reaching into Riverpod
  /// itself, so it stays a plain, easily-testable class.
  Future<void> write({
    required DailyStats stats,
    required int? steps,
    required UserSettings settings,
  }) async {
    if (!isAvailable) return;

    final now = DateTime.now();
    final locale = _localeFor(settings.language);
    final l10n = lookupAppLocalizations(locale);

    final snapshot = <String, dynamic>{
      'date': _dayString(now),
      'updatedAtEpochMs': now.millisecondsSinceEpoch,
      'calories': stats.calories.round(),
      'calorieGoal': settings.dailyCalorieGoal,
      'steps': steps,
      'stepGoal': settings.dailyStepGoal,
      'locale': locale.languageCode,
      'labels': {
        'calories': l10n.caloriesLabel,
        'steps': l10n.stepsLabel,
        'noData': l10n.widgetNoDataLabel,
      },
    };

    await _saveWidgetData(_snapshotKey, jsonEncode(snapshot));
    await _updateWidget();
  }

  // Matches the fallback in step_goal_notifier.dart: hungarian -> hu,
  // everything else (including "system") -> en. We don't read the OS
  // locale here, only the in-app LanguagePreference.
  Locale _localeFor(LanguagePreference preference) {
    return preference == LanguagePreference.hungarian ? const Locale('hu') : const Locale('en');
  }

  String _dayString(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
