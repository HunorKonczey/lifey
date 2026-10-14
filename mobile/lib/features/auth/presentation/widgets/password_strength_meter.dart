import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/password_strength.dart';

/// Four segments and a word under the register form's password field - "Strong password" (LIF-157, docs/design/19-new-features.md
/// E2). Follows [controller] as it is typed into, shows nothing while it is empty, and announces the word as it changes.
///
/// Mirrors the web's `PasswordStrength`: weak in the heart colour, acceptable in the calorie one, strong and very strong in the
/// positive one; the unfilled segments are the control tint.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final level = passwordStrength(value.text);
        if (level == 0) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        final metrics = context.metricColors;
        final color = switch (level) {
          1 => metrics.heart,
          2 => metrics.calories,
          _ => metrics.positive,
        };
        final label = switch (level) {
          1 => l10n.passwordStrengthWeak,
          2 => l10n.passwordStrengthAcceptable,
          3 => l10n.passwordStrengthStrong,
          _ => l10n.passwordStrengthVeryStrong,
        };
        final track = context.palette.control;
        return Padding(
          key: const Key('password-strength'),
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 1; i <= 4; i++) ...[
                      if (i > 1) const SizedBox(width: AppSpacing.s4),
                      Expanded(
                        child: DecoratedBox(
                          key: Key('password-strength-segment-$i'),
                          decoration: BoxDecoration(color: i <= level ? color : track, borderRadius: AppRadius.pill),
                          child: const SizedBox(height: 4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
