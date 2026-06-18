import 'package:flutter/material.dart';

/// Centralized application theming.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      );
}
