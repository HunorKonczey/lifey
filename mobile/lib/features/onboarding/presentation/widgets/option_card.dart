import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Large selection card used for gender/activity/goal pickers in the
/// onboarding wizard — mirrors the web wizard's OptionCard.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.description,
  });

  final IconData icon;
  final String label;
  final String? description;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        curve: AppCurve.standard,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.16), scheme.surfaceContainer)
              : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: active ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 2),
              Text(
                description!,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
