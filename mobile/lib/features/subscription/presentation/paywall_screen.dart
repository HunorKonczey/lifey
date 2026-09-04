import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/web_links.dart';
import '../../../core/entitlements/entitlement.dart';
import '../../../core/entitlements/entitlement_providers.dart';
import '../../../core/entitlements/paywall_trigger.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../application/subscription_controller.dart';
import '../domain/purchase_result.dart';
import '../domain/subscription_product.dart';

/// The paywall (`docs/landing_page/67-mobile-free-pro-plan.md` §4.3,
/// `69` §3) — one layout, five [PaywallTrigger] headline variants (D-DM2),
/// plus the sponsored and already-Pro special states (D-P9, `69` §3.3).
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, required this.trigger});

  final PaywallTrigger trigger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementProvider).value;

    // Only ever short-circuit to a special state once the entitlement has
    // actually resolved (D-P4) — `Entitlement.unresolvedOpen()` also reads
    // `tier == pro` (fail-open), and a paywall opened moments after cold
    // start must not flash "you already have Pro" before the real answer
    // arrives.
    final Widget content;
    if (entitlement != null && entitlement.resolved && entitlement.tier == EntitlementTier.pro) {
      content = entitlement.source == EntitlementSource.trainerSponsored
          ? const _SponsoredView()
          : _AlreadyProView(source: entitlement.source);
    } else {
      content = _PurchaseFlowView(trigger: trigger);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _CloseButton(onTap: () => context.pop()),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Close button — first focusable element (69 §3.1), so it's the first child
// in the Column above rather than a Stack overlay that would paint on top
// but traverse last.
// ---------------------------------------------------------------------------

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.paywallCloseTooltip,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.close, size: 22, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase flow — products loading/unavailable/ready
// ---------------------------------------------------------------------------

class _PurchaseFlowView extends ConsumerWidget {
  const _PurchaseFlowView({required this.trigger});

  final PaywallTrigger trigger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final productsAsync = ref.watch(subscriptionProductsProvider);

    ref.listen(subscriptionControllerProvider, (previous, next) {
      final outcome = next.lastOutcome;
      if (outcome == null || outcome == previous?.lastOutcome) return;
      switch (outcome) {
        case PurchaseOutcome.success:
          AppSnackbar.showSuccess(context, title: l10n.paywallSuccessMessage);
          Future.delayed(const Duration(milliseconds: 900), () {
            if (context.mounted) context.pop();
          });
        case PurchaseOutcome.failed:
        case PurchaseOutcome.verificationFailed:
          AppSnackbar.showError(context, title: l10n.paywallPurchaseFailedMessage);
        case PurchaseOutcome.terminalRejection:
          AppSnackbar.showError(context, title: l10n.paywallTerminalRejectionMessage);
        case PurchaseOutcome.canceled:
        case PurchaseOutcome.pending:
          break;
      }
    });

    return productsAsync.when(
      loading: () => _PaywallBody(trigger: trigger, products: const [], loadingProducts: true),
      error: (_, __) => _UnavailableView(onRetry: () => ref.invalidate(subscriptionProductsProvider)),
      data: (products) {
        if (products.isEmpty) {
          return _UnavailableView(onRetry: () => ref.invalidate(subscriptionProductsProvider));
        }
        return _PaywallBody(trigger: trigger, products: products, loadingProducts: false);
      },
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_outlined, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              l10n.paywallUnavailableMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(onPressed: onRetry, child: Text(l10n.paywallRetryButton)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main body: crest, headline, benefits, plan cards, CTA, legal, restore
// ---------------------------------------------------------------------------

String _headline(AppLocalizations l10n, PaywallTrigger trigger) => switch (trigger) {
      PaywallTrigger.historyRange => l10n.paywallHeadlineHistoryRange,
      PaywallTrigger.aiCredits => l10n.paywallHeadlineAiCredits,
      PaywallTrigger.adRemoval => l10n.paywallHeadlineAdRemoval,
      PaywallTrigger.settings => l10n.lifeyProLabel,
      PaywallTrigger.onboarding => l10n.paywallHeadlineOnboarding,
    };

String _sub(AppLocalizations l10n, PaywallTrigger trigger) => switch (trigger) {
      PaywallTrigger.historyRange => l10n.paywallSubHistoryRange,
      PaywallTrigger.aiCredits => l10n.paywallSubAiCredits,
      PaywallTrigger.adRemoval => l10n.paywallSubAdRemoval,
      PaywallTrigger.settings || PaywallTrigger.onboarding => l10n.paywallSubNeutral,
    };

/// Index into the fixed benefit order (no ads · full history · unlimited
/// AI) that gets the highlighted treatment — `null` for the two neutral
/// triggers (69 §3.2).
int? _highlightedBenefitIndex(PaywallTrigger trigger) => switch (trigger) {
      PaywallTrigger.adRemoval => 0,
      PaywallTrigger.historyRange => 1,
      PaywallTrigger.aiCredits => 2,
      PaywallTrigger.settings || PaywallTrigger.onboarding => null,
    };

class _PaywallBody extends ConsumerWidget {
  const _PaywallBody({
    required this.trigger,
    required this.products,
    required this.loadingProducts,
  });

  final PaywallTrigger trigger;
  final List<SubscriptionProduct> products;
  final bool loadingProducts;

  SubscriptionProduct? _byPeriod(SubscriptionPeriod period) {
    for (final p in products) {
      if (p.period == period) return p;
    }
    return null;
  }

  SubscriptionProduct? _byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final selectedId = ref.watch(selectedSubscriptionProductIdProvider);
    final flowState = ref.watch(subscriptionControllerProvider);
    final isPurchasing = flowState.purchasingProductId != null;

    // Two independent squeezes, both from `69` §3.1/§8 and frame P10 — and
    // until `72` Prompt 9 only the first was implemented, so the 200 % case
    // rendered at full size and simply scrolled further:
    //
    //  * **width** — 320 pt is the narrowest device this screen is specified
    //    for: the crest shrinks and each benefit's description line drops;
    //  * **text scale** — at ~1.6× and up the same two things happen for the
    //    same reason (there is no room), and past ~2× the crest goes entirely,
    //    since a decorative 96 dp circle is the first thing a user who needs
    //    double-size text can spare.
    //
    // Measured off `textScaler.scale(15)` — the sub-line's own size — rather
    // than a raw factor, because that is the number that actually decides
    // whether the column fits.
    final textScaler = MediaQuery.textScalerOf(context);
    final scaledBodySize = textScaler.scale(15);
    final compact = MediaQuery.sizeOf(context).width <= 320 || scaledBodySize >= 24;
    final hideCrest = scaledBodySize >= 30;

    final monthly = _byPeriod(SubscriptionPeriod.monthly);
    final yearly = _byPeriod(SubscriptionPeriod.yearly);
    final selectedProduct = _byId(selectedId);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hideCrest) ...[
            Center(child: _Crest(size: compact ? 56 : 72)),
            const SizedBox(height: 16),
          ],
          Text(
            _headline(l10n, trigger),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sub(l10n, trigger),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _BenefitsList(
            highlightedIndex: _highlightedBenefitIndex(trigger),
            showDescriptions: !compact,
          ),
          const SizedBox(height: 24),
          if (loadingProducts) ...[
            const _PlanCardSkeleton(),
            const SizedBox(height: 10),
            const _PlanCardSkeleton(),
          ] else ...[
            if (monthly != null)
              _PlanCard(
                product: monthly,
                label: l10n.paywallPlanMonthlyLabel,
                selected: selectedId == monthly.id,
                onTap: () =>
                    ref.read(selectedSubscriptionProductIdProvider.notifier).select(monthly.id),
              ),
            if (monthly != null && yearly != null) const SizedBox(height: 10),
            if (yearly != null)
              _PlanCard(
                product: yearly,
                label: l10n.paywallPlanYearlyLabel,
                selected: selectedId == yearly.id,
                discountBadge: l10n.paywallYearlyDiscountBadge,
                perMonthLabel: l10n.paywallPerMonthEquivalent(_perMonthAmount(yearly)),
                onTap: () =>
                    ref.read(selectedSubscriptionProductIdProvider.notifier).select(yearly.id),
              ),
          ],
          const SizedBox(height: 20),
          if (flowState.lastOutcome == PurchaseOutcome.pending) ...[
            _PendingCard(message: l10n.paywallPendingMessage),
            const SizedBox(height: 12),
          ],
          _CtaButton(
            label: (loadingProducts || selectedProduct == null)
                ? l10n.paywallCtaLabelLoading
                : l10n.paywallCtaLabel(selectedProduct.formattedPrice),
            loading: isPurchasing,
            onPressed: (loadingProducts || selectedProduct == null || isPurchasing)
                ? null
                : () => ref.read(subscriptionControllerProvider.notifier).buy(selectedProduct.id),
          ),
          const SizedBox(height: 12),
          const _LegalLine(),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => ref.read(subscriptionControllerProvider.notifier).restore(),
              child: Text(l10n.paywallRestoreButton),
            ),
          ),
        ],
      ),
    );
  }

  /// Derived from the store's own yearly price — never a separate constant
  /// (`67` §4.1) — just a different presentation of the one real number the
  /// store returned.
  String _perMonthAmount(SubscriptionProduct yearly) {
    final perMonth = yearly.rawPrice / 12;
    return NumberFormat.simpleCurrency(name: yearly.currencyCode).format(perMonth);
  }
}

class _Crest extends StatelessWidget {
  const _Crest({required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size * (96 / 72),
      height: size * (96 / 72),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, shape: BoxShape.circle),
      child: Center(
        child: Icon(Icons.workspace_premium, size: size, color: color ?? scheme.primary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Benefits list — fixed order: no ads · full history · unlimited AI
// ---------------------------------------------------------------------------

class _Benefit {
  const _Benefit({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;
}

List<_Benefit> _benefits(AppLocalizations l10n) => [
      _Benefit(
        icon: Icons.block,
        title: l10n.paywallBenefitNoAdsTitle,
        description: l10n.paywallBenefitNoAdsDescription,
      ),
      _Benefit(
        icon: Icons.history,
        title: l10n.paywallBenefitFullHistoryTitle,
        description: l10n.paywallBenefitFullHistoryDescription,
      ),
      _Benefit(
        icon: Icons.auto_awesome,
        title: l10n.paywallBenefitUnlimitedAiTitle,
        description: l10n.paywallBenefitUnlimitedAiDescription,
      ),
    ];

class _BenefitsList extends StatelessWidget {
  const _BenefitsList({required this.highlightedIndex, required this.showDescriptions});

  final int? highlightedIndex;
  final bool showDescriptions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final benefits = _benefits(l10n);
    return Column(
      children: [
        for (var i = 0; i < benefits.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _BenefitRow(
            benefit: benefits[i],
            highlighted: i == highlightedIndex,
            showDescription: showDescriptions,
          ),
        ],
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.benefit,
    required this.highlighted,
    required this.showDescription,
    this.active = false,
  });

  final _Benefit benefit;
  final bool highlighted;
  final bool showDescription;

  /// The sponsored state's "already active" variant (69 §3.3) — a
  /// `check_circle` instead of the benefit's own icon, in `tertiary`.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: highlighted ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: highlighted
          ? BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active ? Icons.check_circle : benefit.icon,
            size: 28,
            color: active ? scheme.tertiary : scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showDescription) ...[
                  const SizedBox(height: 2),
                  Text(
                    benefit.description,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan cards
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.label,
    required this.selected,
    required this.onTap,
    this.discountBadge,
    this.perMonthLabel,
  });

  final SubscriptionProduct product;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? discountBadge;
  final String? perMonthLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // "Every plan card is a single semantic radio" (`69` §8). The visual
    // already carries the state twice over (a `radio_button_checked` glyph and
    // a 2 px border, never colour alone), but to a screen reader the card was
    // just a tappable box: nothing said the two cards are alternatives, or
    // which one is currently chosen. `72` Prompt 8.
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: selected ? scheme.tertiaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wrap, not Row: at narrow widths the label + badge
                      // together can be wider than the card, and a Row would
                      // overflow rather than drop the badge to its own line.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (discountBadge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: scheme.secondary,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                discountBadge!,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (perMonthLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          perMonthLabel!,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    product.formattedPrice,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton plan card while store prices are still loading (`69` §12.8) —
/// same shape as [_PlanCard], no price rendered (never a fabricated one).
class _PlanCardSkeleton extends StatelessWidget {
  const _PlanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA, pending card, legal line
// ---------------------------------------------------------------------------

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // `constraints`, not a fixed `height`: at a large text scale the label —
    // which carries the store's own price string — needs more than 56 dp, and
    // `69` §8 is explicit that the CTA never truncates (`72` Prompt 9). The
    // button grows instead, and the label wraps rather than ellipsing.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.7),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
              )
            : Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top, color: scheme.onTertiaryContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLine extends StatelessWidget {
  const _LegalLine();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final style = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    );
    return Column(
      children: [
        Text(l10n.paywallLegalDisclaimer, textAlign: TextAlign.center, style: style),
        const SizedBox(height: 2),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            _LegalLink(
              label: l10n.paywallTermsLinkLabel,
              url: WebLinks.terms(languageCode),
              style: style,
            ),
            Text('  ·  ', style: style),
            _LegalLink(
              label: l10n.paywallPrivacyLinkLabel,
              url: WebLinks.privacy(languageCode),
              style: style,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.url, required this.style});

  final String label;
  final String url;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // System browser, never an in-app webview (69 §12.7).
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(label, style: style.copyWith(decoration: TextDecoration.underline)),
    );
  }
}

// ---------------------------------------------------------------------------
// Special states: sponsored, already Pro (69 §3.3, D-P9)
// ---------------------------------------------------------------------------

class _InfoPaywallView extends StatelessWidget {
  const _InfoPaywallView({
    required this.headline,
    required this.crestColor,
    required this.buttonLabel,
    required this.onButtonPressed,
    required this.benefitsActive,
  });

  final String headline;
  final Color Function(ColorScheme scheme) crestColor;
  final String buttonLabel;
  final VoidCallback onButtonPressed;

  /// `true` for the sponsored state (benefits shown as already active,
  /// `check_circle` in tertiary) — `false` for already-Pro-via-purchase,
  /// where they're shown the normal way.
  final bool benefitsActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _Crest(size: 72, color: crestColor(scheme))),
          const SizedBox(height: 16),
          Text(
            headline,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              for (var i = 0; i < _benefits(l10n).length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                _BenefitRow(
                  benefit: _benefits(l10n)[i],
                  highlighted: false,
                  showDescription: true,
                  active: benefitsActive,
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: onButtonPressed,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsoredView extends StatelessWidget {
  const _SponsoredView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _InfoPaywallView(
      headline: l10n.paywallSponsoredHeadline,
      crestColor: (scheme) => scheme.secondary,
      buttonLabel: l10n.paywallSponsoredOkButton,
      onButtonPressed: () => context.pop(),
      benefitsActive: true,
    );
  }
}

class _AlreadyProView extends StatelessWidget {
  const _AlreadyProView({required this.source});

  final EntitlementSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final managesOnStore =
        source == EntitlementSource.appStore || source == EntitlementSource.playStore;
    return _InfoPaywallView(
      headline: l10n.paywallAlreadyProHeadline,
      crestColor: (scheme) => scheme.primary,
      buttonLabel: managesOnStore ? l10n.paywallManageSubscriptionButton : l10n.paywallSponsoredOkButton,
      onButtonPressed: () {
        if (managesOnStore) {
          final url = source == EntitlementSource.appStore
              ? 'https://apps.apple.com/account/subscriptions'
              : 'https://play.google.com/store/account/subscriptions';
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          context.pop();
        }
      },
      benefitsActive: true,
    );
  }
}
