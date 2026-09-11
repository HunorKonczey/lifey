import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_message.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../application/trainer_invites_controller.dart';
import '../domain/sent_invite.dart';

/// Invite someone, and see who has not answered yet (frame H, T7).
///
/// The last thing that kept a trainer on the web for a whole task: until now
/// the client list's empty state could only point them at a laptop.
class TrainerInvitesScreen extends ConsumerStatefulWidget {
  const TrainerInvitesScreen({super.key});

  @override
  ConsumerState<TrainerInvitesScreen> createState() =>
      _TrainerInvitesScreenState();
}

class _TrainerInvitesScreenState extends ConsumerState<TrainerInvitesScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _sending = false;
  String? _sendError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(trainerInvitesControllerProvider.notifier)
          .invite(_emailController.text);
      if (!mounted) return;
      _emailController.clear();
      setState(() => _sending = false);
      AppSnackbar.showSuccess(context, title: l10n.trainerInviteSentMessage);
    } catch (error) {
      // The reason matters here — "already your client" is a different
      // problem from a typo — so the server's own message is shown rather
      // than a generic failure.
      if (mounted) {
        setState(() {
          _sending = false;
          _sendError = friendlyError(error);
        });
      }
    }
  }

  Future<void> _cancel(SentInvite invite) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.trainerCancelInviteConfirmTitle,
      message: l10n.trainerCancelInviteConfirmMessage(invite.clientEmail),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(trainerInvitesControllerProvider.notifier).cancel(invite.id);
      if (mounted) {
        AppSnackbar.showSuccess(context, title: l10n.trainerInviteCancelledMessage);
      }
    } catch (error) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final invites = ref.watch(trainerInvitesControllerProvider);

    Future<void> refresh() async {
      await ref.read(trainerInvitesControllerProvider.notifier).refresh();
      // An invite accepted since the last look turns someone into a client,
      // and only the client list shows that.
      await ref.read(refreshAfterInvitesProvider)();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainerInvitesTitle)),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.trainerInviteEmailLabel,
                  helperText: l10n.trainerInviteEmailHelper,
                  helperMaxLines: 2,
                  errorText: _sendError,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  // The backend wants an exact address; a local shape check
                  // keeps an obvious typo from costing a round trip.
                  if (email.isEmpty || !email.contains('@') || email.endsWith('@')) {
                    return l10n.trainerInviteEmailInvalidMessage;
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_sending)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: Text(l10n.trainerSendInviteButton),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.trainerPendingInvitesTitle,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            invites.when(
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l10n.trainerNoPendingInvitesMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (final invite in list)
                          _InviteRow(invite: invite, onCancel: () => _cancel(invite)),
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorView(error: error, onRetry: refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.invite, required this.onCancel});

  final SentInvite invite;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final remaining = invite.remaining();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.clientEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  remaining == Duration.zero
                      ? l10n.trainerInviteExpiredLabel
                      : l10n.trainerInviteExpiresInLabel(remaining.inHours),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: scheme.error,
            tooltip: l10n.trainerCancelInviteTooltip,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
