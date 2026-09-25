import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../trainer/clients/domain/trainer_client.dart';
import '../application/new_conversation_controller.dart';
import 'widgets/chat_avatar.dart';

/// Opens the trainer's client picker. Resolves to the id of the thread to
/// navigate into, or null if the sheet was dismissed.
Future<int?> showNewConversationSheet(BuildContext context) {
  return showLifeySheet<int>(
    context: context,
    title: AppLocalizations.of(context)!.chatNewConversationTitle,
    showClose: true,
    useRootNavigator: true,
    builder: (_) => const _NewConversationSheet(),
  );
}

/// The one screen in the chat feature that only exists for trainers: a client
/// has no one to pick from, their thread appears when they accept an invite
/// (docs/chat/40-trainer-chat-plan.md §6.1).
///
/// It lists only clients *without* a thread — anyone already talking to the
/// trainer is one tap away in the list behind this sheet.
class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet();

  @override
  ConsumerState<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends ConsumerState<_NewConversationSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _starting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrainerClient> _filter(List<TrainerClient> clients) {
    if (_query.trim().isEmpty) return clients;
    final needle = _query.toLowerCase();
    return clients
        .where((c) =>
            c.displayName.toLowerCase().contains(needle) ||
            c.email.toLowerCase().contains(needle))
        .toList();
  }

  Future<void> _start(TrainerClient client) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final conversationId =
          await ref.read(newConversationControllerProvider.notifier).startWith(client.userId);
      if (mounted) Navigator.of(context).pop(conversationId);
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        AppSnackbar.showError(context, title: friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final state = ref.watch(newConversationControllerProvider);

    // The title is the sheet's own; the explanation and the picker go here.
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.chatNewConversationSubtitle,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              hintText: l10n.chatNewConversationSearchHint,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Expanded(
            child: state.when(
              data: (clients) {
                if (clients.isEmpty) {
                  return _SheetEmpty(icon: Icons.check_circle_outline, message: l10n.chatNewConversationEmpty);
                }
                final visible = _filter(clients);
                return SingleChildScrollView(
                  child: ListGroup(
                    dividerInset: 72,
                    children: [
                      for (final client in visible)
                        ListRow(
                          leading: ChatAvatar(monogram: client.monogram, userId: client.userId, size: 44),
                          title: client.displayName,
                          subtitle: client.email,
                          trailing: Icon(Icons.chevron_right_rounded, size: 22, color: p.text2),
                          onTap: _starting ? null : () => _start(client),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _SheetEmpty(icon: Icons.cloud_off, message: friendlyError(error)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: p.text3),
            const SizedBox(height: AppSpacing.s16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2)),
          ],
        ),
      ),
    );
  }
}
