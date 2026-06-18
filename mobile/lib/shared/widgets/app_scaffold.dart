import 'package:flutter/material.dart';

/// Shared scaffold with the app's bottom navigation
/// (Dashboard, Nutrition, Workouts, Weight).
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}
