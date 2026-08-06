import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../application/new_conversation_controller.dart';
import '../domain/trainer_client_option.dart';
import 'widgets/chat_avatar.dart';

/// Opens the trainer's client picker. Resolves to the id of the thread to
/// navigate into, or null if the sheet was dismissed.
Future<int?> showNewConversationSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
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

  List<TrainerClientOption> _filter(List<TrainerClientOption> clients) {
    if (_query.trim().isEmpty) return clients;
    final needle = _query.toLowerCase();
    return clients
        .where((c) =>
            c.displayName.toLowerCase().contains(needle) ||
            c.email.toLowerCase().contains(needle))
        .toList();
  }

  Future<void> _start(TrainerClientOption client) async {
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
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(newConversationControllerProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chatNewConversationTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.chatNewConversationSubtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: l10n.chatNewConversationSearchHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            Expanded(
              child: state.when(
                data: (clients) {
                  if (clients.isEmpty) {
                    return _SheetEmpty(
                      icon: Icons.check_circle_outline,
                      message: l10n.chatNewConversationEmpty,
                    );
                  }
                  final visible = _filter(clients);
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final client = visible[index];
                      return ListTile(
                        leading: ChatAvatar(monogram: client.monogram, size: 40),
                        title: Text(client.displayName),
                        subtitle: Text(client.email),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _starting ? null : () => _start(client),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _SheetEmpty(
                  icon: Icons.cloud_off,
                  message: friendlyError(error),
                ),
              ),
            ),
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.outline),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
