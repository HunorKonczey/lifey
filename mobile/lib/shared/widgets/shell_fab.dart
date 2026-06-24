import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ShellFabConfig = ({
  int tabIndex,
  IconData icon,
  String label,
  VoidCallback onPressed,
  bool extended,
});

// ---------------------------------------------------------------------------
// shellFabProvider — FAB config for the current shell tab.
// Set by each screen in build; read by MainShell to render the FAB above
// the floating nav bar.
// ---------------------------------------------------------------------------

class _ShellFabNotifier extends Notifier<ShellFabConfig?> {
  @override
  ShellFabConfig? build() => null;

  void set(ShellFabConfig? config) => state = config;
}

final shellFabProvider =
    NotifierProvider<_ShellFabNotifier, ShellFabConfig?>(
      _ShellFabNotifier.new,
    );

// ---------------------------------------------------------------------------
// activeShellTabProvider — which shell tab index is currently active.
// Set by MainShell on tap; read by screens that need to know their tab.
// ---------------------------------------------------------------------------

class _ActiveShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final activeShellTabProvider =
    NotifierProvider<_ActiveShellTabNotifier, int>(
      _ActiveShellTabNotifier.new,
    );
