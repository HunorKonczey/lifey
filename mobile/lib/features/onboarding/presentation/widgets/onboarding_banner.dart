import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/user_details_repository.dart';

const _dismissedKey = 'lifey.onboardingBannerDismissed';

/// Shown on the dashboard when the user hasn't completed (or has skipped)
/// onboarding — `GET /user-details` returning 404 is the signal (see
/// docs/21-onboarding-user-details-plan.md). Dismissal is per-device.
class OnboardingBanner extends ConsumerStatefulWidget {
  const OnboardingBanner({super.key});

  @override
  ConsumerState<OnboardingBanner> createState() => _OnboardingBannerState();
}

class _OnboardingBannerState extends ConsumerState<OnboardingBanner> {
  bool _dismissed = true; // hidden until prefs are read, avoids a first-frame flash
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = prefs.getBool(_dismissedKey) ?? false;
      _prefsLoaded = true;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final hasDetails = ref.watch(hasUserDetailsProvider);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (!_prefsLoaded || _dismissed) return const SizedBox.shrink();
    final notOnboarded = hasDetails.value == false;
    if (!notOnboarded) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(scheme.primary.withValues(alpha: 0.14), scheme.surfaceContainer),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.eco, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.onboardingBannerTitle,
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.onboardingBannerBody,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push('/onboarding'),
            child: Text(l10n.onboardingBannerCta),
          ),
          IconButton(
            onPressed: _dismiss,
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.onboardingBannerDismissTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
