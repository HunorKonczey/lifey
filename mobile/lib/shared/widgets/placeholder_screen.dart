import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'ds/lifey_header.dart';

/// Simple scaffold for tabs whose feature isn't built yet, so the bottom
/// navigation feels complete.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: LifeySubpageHeader(title: title),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.comingSoonMessage(title),
                style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
