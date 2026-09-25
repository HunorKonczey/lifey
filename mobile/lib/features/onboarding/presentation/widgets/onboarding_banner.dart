import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/notice_card.dart';
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

    if (!_prefsLoaded || _dismissed) return const SizedBox.shrink();
    final notOnboarded = hasDetails.value == false;
    if (!notOnboarded) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: NoticeCard(
        icon: Icons.eco_rounded,
        title: l10n.onboardingBannerTitle,
        body: l10n.onboardingBannerBody,
        actionLabel: l10n.onboardingBannerCta,
        onAction: () => context.push('/onboarding'),
        onDismiss: _dismiss,
        dismissTooltip: l10n.onboardingBannerDismissTooltip,
      ),
    );
  }
}
