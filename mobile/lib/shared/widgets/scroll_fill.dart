import 'package:flutter/material.dart';

/// Centers its child and fills the viewport while staying scrollable, so it
/// can sit inside a [RefreshIndicator] (pull-to-refresh still works).
class ScrollFill extends StatelessWidget {
  const ScrollFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(padding: const EdgeInsets.all(24), child: child),
            ),
          ),
        );
      },
    );
  }
}
