import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/error_message.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../../shared/widgets/ds/lifey_header.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/section_label.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../shared/trainer_layout.dart';
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
      appBar: LifeySubpageHeader(title: l10n.trainerInvitesTitle),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: TrainerContentWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s16,
              AppSpacing.screen,
              MediaQuery.paddingOf(context).bottom + AppSpacing.s24,
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
              const SizedBox(height: AppSpacing.s12),
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
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(l10n.trainerSendInviteButton),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s32),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: SectionLabel(l10n.trainerPendingInvitesTitle),
              ),
              invites.when(
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                        child: Text(
                          l10n.trainerNoPendingInvitesMessage,
                          style: theme.textTheme.bodySmall?.copyWith(color: context.palette.text2),
                        ),
                      )
                    : ListGroup(
                        dividerInset: 72,
                        children: [
                          for (final invite in list) _InviteRow(invite: invite, onCancel: () => _cancel(invite)),
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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final remaining = invite.remaining();

    return ListRow(
      leading: ListIconHolder(icon: Icons.mail_outline_rounded, color: scheme.primary),
      title: invite.clientEmail,
      subtitle: remaining == Duration.zero
          ? l10n.trainerInviteExpiredLabel
          : l10n.trainerInviteExpiresInLabel(remaining.inHours),
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded),
        color: scheme.error,
        tooltip: l10n.trainerCancelInviteTooltip,
        onPressed: onCancel,
      ),
    );
  }
}
