import 'package:material_ui/material_ui.dart';

import 'app_localizations.dart';

/// The localization delegates for every `MaterialApp` in the app and the tests.
///
/// Use this instead of the generated `AppLocalizations.localizationsDelegates`
/// (LIF-192): since Flutter 3.47 `MaterialApp` comes from `material_ui` and looks
/// up `material_ui`'s own Material/Cupertino localizations, but `flutter gen-l10n`
/// (still in 3.50) generates the deprecated `flutter_localizations` delegates,
/// which no longer satisfy that lookup. Hungarian then has no Material
/// localizations at all. `GlobalMaterialLocalizations.delegates` from
/// `material_ui` brings the Cupertino, Material and Widgets delegates.
///
/// Hand-written on purpose; `app_localizations*.dart` is the generated output.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
