import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../application/trainer_invite_controller.dart';
import '../domain/trainer_invite.dart';

/// Floating, dismissible card shown above the bottom nav when the current
/// user has a pending trainer invite (docs/personal_trainer/05-mobil-terv.md
/// §1, design in 06-design.md §4). Not modal — the app stays usable under it.
class TrainerInviteCard extends ConsumerStatefulWidget {
  const TrainerInviteCard({super.key});

  @override
  ConsumerState<TrainerInviteCard> createState() => _TrainerInviteCardState();
}

class _TrainerInviteCardState extends ConsumerState<TrainerInviteCard> {
  // "Later" (button or swipe) just hides the card for this app session —
  // it reappears on the next launch/resume poll, per spec.
  final Set<int> _dismissedIds = {};
  bool _responding = false;

  @override
  Widget build(BuildContext context) {
    final invites = ref.watch(trainerInviteControllerProvider).value ?? const [];
    final visible = invites.where((invite) => !_dismissedIds.contains(invite.id)).toList();
    final current = visible.isEmpty ? null : visible.first;

    return IgnorePointer(
      ignoring: current == null,
      child: AnimatedSlide(
        offset: current == null ? const Offset(0, 0.3) : Offset.zero,
        duration: AppDuration.slow,
        curve: AppCurve.collapse,
        child: AnimatedOpacity(
          opacity: current == null ? 0.0 : 1.0,
          duration: AppDuration.base,
          curve: AppCurve.standard,
          child: current == null
              ? const SizedBox.shrink()
              : _CardContent(
                  key: ValueKey(current.id),
                  invite: current,
                  moreCount: visible.length - 1,
                  responding: _responding,
                  onDismiss: () => setState(() => _dismissedIds.add(current.id)),
                  onRespond: (accept) => _respond(current, accept),
                ),
        ),
      ),
    );
  }

  Future<void> _respond(TrainerInvite invite, bool accept) async {
    setState(() => _responding = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(trainerInviteControllerProvider.notifier)
          .respond(invite.id, accept: accept);
      if (!mounted) return;
      if (accept) {
        AppSnackbar.showSuccess(
          context,
          title: l10n.trainerInviteAcceptedMessage(invite.trainerEmail),
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    super.key,
    required this.invite,
    required this.moreCount,
    required this.responding,
    required this.onDismiss,
    required this.onRespond,
  });

  final TrainerInvite invite;
  final int moreCount;
  final bool responding;
  final VoidCallback onDismiss;
  final ValueChanged<bool> onRespond;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hoursLeft = invite.expiresAt.difference(DateTime.now()).inHours.clamp(0, 24);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Dismissible(
        key: ValueKey('dismiss-${invite.id}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => onDismiss(),
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: scheme.tertiaryContainer,
                        child: Text(
                          invite.trainerEmail.isNotEmpty
                              ? invite.trainerEmail[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.trainerInviteCardTitle(invite.trainerEmail),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              moreCount > 0
                                  ? '${l10n.trainerInviteExpiresIn(hoursLeft)} · ${l10n.trainerInviteMoreCount(moreCount)}'
                                  : l10n.trainerInviteExpiresIn(hoursLeft),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onDismiss,
                        tooltip: l10n.trainerInviteDismissTooltip,
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: responding ? null : () => onRespond(false),
                        child: Text(l10n.trainerInviteDeclineButton),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: responding ? null : () => onRespond(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                        ),
                        child: Text(l10n.trainerInviteAcceptButton),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
