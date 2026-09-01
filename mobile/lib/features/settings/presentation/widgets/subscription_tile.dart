import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/web_links.dart';
import '../../../../core/entitlements/entitlement.dart';
import '../../../../core/entitlements/entitlement_providers.dart';
import '../../../../core/entitlements/paywall_navigation.dart';
import '../../../../core/entitlements/paywall_trigger.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../subscription/application/subscription_controller.dart';

/// Settings subscription tile (`docs/landing_page/67-mobile-free-pro-plan.md`
/// §4.4, `69` frame P14). Renders the *resolved* `source` — never a merge of
/// two (`69` §12.6): each of the four states below reads straight off the
/// current [Entitlement], with no client-side combining of sponsorship with
/// a trial, or of a store purchase with sponsorship.
class SubscriptionSection extends ConsumerWidget {
  const SubscriptionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Not yet resolved (D-P4: fail-open reads as `tier == pro`) — showing
    // the free tile's upsell copy for this brief window is harmless (worst
    // case a Pro user sees it for a frame), where showing "Pro" or
    // "sponsored" prematurely would be a false claim about their billing.
    final entitlement = ref.watch(entitlementProvider).value;
    final resolved = entitlement != null && entitlement.resolved ? entitlement : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 0),
          child: Text(
            l10n.settingsSubscriptionSectionLabel.toUpperCase(),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: SubscriptionTile(entitlement: resolved),
          ),
        ),
      ],
    );
  }
}

/// The tile + restore-purchases row on their own, for tests and for reuse.
class SubscriptionTile extends ConsumerWidget {
  const SubscriptionTile({super.key, required this.entitlement});

  /// `null` means unresolved — treated the same as free (see
  /// [SubscriptionSection]'s doc comment).
  final Entitlement? entitlement;

  int _daysLeft(DateTime trialEndsAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(trialEndsAt.year, trialEndsAt.month, trialEndsAt.day);
    final days = endDay.difference(today).inDays;
    return days < 0 ? 0 : days;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;

    final isPro = entitlement?.tier == EntitlementTier.pro;
    final source = entitlement?.source ?? EntitlementSource.none;

    final String title;
    final String subtitle;
    final VoidCallback? onTap;

    if (!isPro) {
      title = l10n.lifeyProLabel;
      subtitle = l10n.settingsSubscriptionFreeSubtitle;
      onTap = () => openPaywall(context, PaywallTrigger.settings);
    } else if (source == EntitlementSource.trainerSponsored) {
      title = l10n.settingsSubscriptionProTitle;
      subtitle = l10n.settingsSubscriptionSponsoredSubtitle;
      onTap = null; // No CTA (67 §4.4, D-P9) — nothing to buy or manage.
    } else if (source == EntitlementSource.trainerTrial) {
      title = l10n.settingsSubscriptionTrialTitle;
      final trialEndsAt = entitlement?.trainer?.trialEndsAt;
      subtitle =
          trialEndsAt == null ? '' : l10n.settingsSubscriptionTrialDaysLeft(_daysLeft(trialEndsAt));
      // No trainer purchase UI on mobile, and there will not be one
      // (`63` D-M1) — the web billing page is the only place this is
      // actually managed (`69` §12.6).
      onTap = () =>
          launchUrl(Uri.parse(WebLinks.adminBilling), mode: LaunchMode.externalApplication);
    } else {
      // Own purchase: appStore/playStore/stripe, or an admin-granted comp.
      title = l10n.settingsSubscriptionProTitle;
      final expiresAt = entitlement?.expiresAt;
      subtitle = expiresAt == null
          ? ''
          : l10n.settingsSubscriptionRenewsSubtitle(
              DateFormat.yMMMd(languageCode).format(expiresAt));
      onTap = switch (source) {
        EntitlementSource.appStore => () => launchUrl(
              Uri.parse('https://apps.apple.com/account/subscriptions'),
              mode: LaunchMode.externalApplication,
            ),
        EntitlementSource.playStore => () => launchUrl(
              Uri.parse('https://play.google.com/store/account/subscriptions'),
              mode: LaunchMode.externalApplication,
            ),
        EntitlementSource.stripe => () =>
            launchUrl(Uri.parse(WebLinks.adminBilling), mode: LaunchMode.externalApplication),
        // comp (admin-granted) — nothing to manage.
        _ => null,
      };
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.workspace_premium, size: 22, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 22, color: scheme.onSurfaceVariant),
          ],
        ],
      ),
    );

    // Restore purchases (67 §4.4) sits below the tile itself, offered
    // whenever there's a plausible store purchase to look for — not the
    // sponsored or trainer-trial states, where there is none.
    final showRestore = !isPro ||
        source == EntitlementSource.appStore ||
        source == EntitlementSource.playStore ||
        source == EntitlementSource.stripe ||
        source == EntitlementSource.comp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.card - 4),
                child: row,
              )
            : row,
        if (showRestore) ...[
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: scheme.surfaceContainerHighest,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => ref.read(subscriptionControllerProvider.notifier).restore(),
                child: Text(l10n.paywallRestoreButton),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
