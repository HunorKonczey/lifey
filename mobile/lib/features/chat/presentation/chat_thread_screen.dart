import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/current_roles_provider.dart';
import '../../../core/network/error_message.dart';
import '../../../core/sync/connectivity_status_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/trainer_view_menu.dart';
import '../domain/chat_peer.dart';
import '../application/chat_thread_controller.dart';
import '../data/chat_repository.dart';
import '../application/chat_stream_controller.dart';
import '../application/chat_typing_controller.dart';
import '../domain/chat_conversation.dart';
import '../domain/chat_message.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/day_divider.dart';
import 'widgets/message_bubble.dart';

/// One conversation. Identical for both roles — nothing on this screen knows
/// whether the person on the other side is a trainer or a client.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.initialDraft,
  });

  final int conversationId;

  /// Text the composer opens with. Set when the thread is entered with
  /// something already to say — today only the trainer's "message them too"
  /// about a session (docs/chat/41 T3, frame D4). Nothing is sent on the
  /// trainer's behalf: the draft is theirs to edit or discard.
  final String? initialDraft;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  /// Kept in sync by [build] because `ref` is off limits in [dispose] — the
  /// element is already unmounted by then. Watched rather than read once, so
  /// this stays the live controller if `chatStreamControllerProvider` is
  /// rebuilt (see its doc comment) while the thread is open.
  late ChatStreamController _streamController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _streamController = ref.read(chatStreamControllerProvider);
    // Tells the server this thread is on screen, so a message arriving now is
    // read on arrival and no push goes out for it (§5.1). The background case
    // is handled centrally by ChatStreamController, not here.
    unawaited(_streamController.setActiveConversation(widget.conversationId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Leaving the thread must clear presence, or pushes would stay silenced
    // until the server's TTL.
    unawaited(_streamController.setActiveConversation(null));
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app is the moment to fill the gap: while we were
    // away the only channel was push, which carries a badge, not content.
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(_controllerProvider.notifier).catchUp());
    }
  }

  StreamNotifierProvider<ChatThreadController, List<ChatMessage>> get _controllerProvider =>
      chatThreadControllerProvider(widget.conversationId);

  /// The list is reversed, so "scrolled to the end" means the *top* of the
  /// thread — where older messages get pulled in.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(ref.read(_controllerProvider.notifier).loadOlder());
    }
  }

  Future<void> _send(String body, File? image) async {
    await ref.read(_controllerProvider.notifier).send(body, image: image);
    // The new bubble is at offset 0 in a reversed list.
    if (_scrollController.hasClients) {
      unawaited(_scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ));
    }
  }

  /// Fixed durations rather than a free time picker: the question is "leave me
  /// alone for a bit" or "for good", and a picker would make the common case
  /// slower without making it more expressive.
  Future<void> _showMuteOptions(ChatConversation conversation, AppLocalizations l10n) async {
    final choice = await showModalBottomSheet<Duration?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final hours in const [1, 8])
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(l10n.chatMuteForHours(hours)),
                onTap: () => Navigator.of(sheetContext).pop(Duration(hours: hours)),
              ),
            ListTile(
              leading: const Icon(Icons.notifications_off),
              title: Text(l10n.chatMuteUntilFurtherNotice),
              // Far enough out to read as "off" without a separate flag.
              onTap: () => Navigator.of(sheetContext).pop(const Duration(days: 3650)),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _setMuted(DateTime.now().add(choice), l10n);
  }

  Future<void> _setMuted(DateTime? mutedUntil, AppLocalizations l10n) async {
    try {
      await ref.read(chatRepositoryProvider).setMuted(widget.conversationId, mutedUntil);
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          title: mutedUntil == null ? l10n.chatUnmutedMessage : l10n.chatMutedMessage,
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  /// Asks first: a tombstone reaches the other person's screen and cannot be
  /// undone, unlike discarding a message that never left the device.
  Future<void> _delete(String clientId, AppLocalizations l10n) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.chatDeleteMessageQuestionTitle,
      message: l10n.chatDeleteMessageConfirmMessage,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(_controllerProvider.notifier).delete(clientId);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _streamController = ref.watch(chatStreamControllerProvider);
    final conversation = ref.watch(chatConversationProvider(widget.conversationId)).value;
    final messages = ref.watch(_controllerProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;

    return Scaffold(
      appBar: LifeySubpageHeader(
        leading: conversation == null
            ? null
            : ChatAvatar(
                monogram: conversation.peer.monogram,
                userId: conversation.peer.userId,
                size: 44,
              ),
        title: conversation?.peer.displayName ?? '',
        // The person's role, not a presence claim: presence is tracked for the
        // push decision (§5.1) but never reported back, so an "online" would
        // be a lie the design explicitly rules out.
        subtitle: conversation == null
            ? null
            : (conversation.peer.role == ChatPeerRole.trainer ? l10n.chatPeerRoleTrainer : l10n.chatPeerRoleClient),
        actions: [
          // The bridge from the conversation to the numbers behind it
          // (docs/chat/41 T2). Only for a trainer looking at a *client*: the
          // same thread seen from the client's side has no such screen, and
          // /trainer/... would bounce them straight back.
          if (conversation != null &&
              conversation.peer.role == ChatPeerRole.client &&
              ref.watch(isTrainerProvider))
            HeaderIconButton(
              icon: Icons.insights_outlined,
              tooltip: l10n.trainerViewClientDataAction,
              onPressed: () => context.push('$trainerShellLocation/${conversation.peer.userId}'),
            ),
          HeaderIconButton(
            icon: Icons.search_rounded,
            tooltip: l10n.chatSearchInThread,
            onPressed: () => context.push('/chat/${widget.conversationId}/search'),
          ),
          // Mute lives in the menu now: it is a setting, not something to do
          // while reading.
          if (conversation != null)
            PopupMenuButton<void>(
              tooltip: l10n.chatMoreTooltip,
              position: PopupMenuPosition.under,
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () => conversation.isMuted ? _setMuted(null, l10n) : _showMuteOptions(conversation, l10n),
                  child: Row(
                    children: [
                      Icon(conversation.isMuted ? Icons.notifications_off : Icons.notifications_none, size: 20),
                      const SizedBox(width: AppSpacing.s12),
                      Text(conversation.isMuted ? l10n.chatUnmuteAction : l10n.chatMuteAction),
                    ],
                  ),
                ),
              ],
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: context.palette.nested, shape: BoxShape.circle),
                child: Icon(Icons.more_vert_rounded, size: 22, color: context.palette.text),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (isOffline) _OfflineStrip(message: l10n.chatOfflineNotice),
          Expanded(
            child: messages.when(
              data: (items) => items.isEmpty
                  ? EmptyView(
                      icon: Icons.forum_outlined,
                      title: l10n.chatEmptyThreadTitle,
                      subtitle: conversation == null
                          ? null
                          : l10n.chatEmptyThreadBody(conversation.peer.displayName),
                    )
                  : _buildStream(items, conversation, currentUserId),
              loading: () => const _ThreadSkeleton(),
              error: (_, __) => _ThreadError(
                onRetry: () => ref.read(_controllerProvider.notifier).catchUp(),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: conversation?.isArchived ?? false
                ? const ArchivedComposerNotice()
                : ChatComposer(
                    initialText: widget.initialDraft,
                    onSend: _send,
                    onTyping: () =>
                        ref.read(chatTypingReporterProvider).report(widget.conversationId),
                    peerTypingName:
                        ref.watch(chatTypingControllerProvider).contains(widget.conversationId)
                            ? conversation?.peer.displayName
                            : null,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStream(
    List<ChatMessage> messages,
    ChatConversation? conversation,
    int? currentUserId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final uploads = ref.watch(chatUploadProgressProvider).value ?? const <String, double>{};
    // Reversed so the thread sits at the bottom and the keyboard pushes it up
    // without any manual scroll maths — index 0 is the newest message.
    final ordered = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s12, AppSpacing.screen, AppSpacing.s4),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final message = ordered[index];
        final isOwn = currentUserId != null && message.senderId == currentUserId;
        // "Newer" and "older" are index-1 and index+1 in a reversed list.
        final newer = index == 0 ? null : ordered[index - 1];
        final older = index + 1 < ordered.length ? ordered[index + 1] : null;

        // Last of a same-sender run: the bubble that carries the time, the
        // status icon and the flattened corner.
        final endsRun = newer == null || newer.senderId != message.senderId;
        final startsDay = older == null || DayDivider.separates(older.createdAt, message.createdAt);

        final bubble = MessageBubble(
          message: message,
          // Delivered/read aren't stored on the message — they follow from the
          // thread's peer cursors, so they're resolved here where both are in
          // hand rather than baked into the row.
          receiptState: receiptStateFor(message, conversation),
          isOwn: isOwn,
          senderName: isOwn ? '' : (conversation?.peer.displayName ?? ''),
          showTail: endsRun,
          uploadProgress: uploads[message.clientId],
          onRetry: () => ref.read(_controllerProvider.notifier).retry(message.clientId),
          onDelete: () => message.isUnsent
              // Never sent, so nobody else has it and there is nothing to
              // confirm — dropping the row is the whole operation.
              ? ref.read(_controllerProvider.notifier).discard(message.clientId)
              : _delete(message.clientId, l10n),
        );

        if (!startsDay) return bubble;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [DayDivider(day: message.createdAt), bubble],
        );
      },
    );
  }
}

/// Sits between the header and the stream. Informational only — the composer
/// stays live, because a message written offline is not a lost message.
class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      color: context.metricColors.heart.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.s8),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: p.text2),
          const SizedBox(width: AppSpacing.s8),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: p.text2))),
        ],
      ),
    );
  }
}

class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Alternating sides and widths, so the placeholder reads as a
    // conversation rather than a loading list.
    const shapes = [(false, 180.0), (true, 140.0), (false, 220.0), (true, 90.0)];
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s12, AppSpacing.screen, AppSpacing.s4),
      children: [
        for (final (isOwn, width) in shapes)
          Align(
            alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: width,
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(color: p.card, borderRadius: AppRadius.cardAll),
            ),
          ),
      ],
    );
  }
}

class _ThreadError extends StatelessWidget {
  const _ThreadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ErrorView(
      error: Exception('chat thread'),
      title: l10n.chatLoadErrorTitle,
      message: l10n.chatLoadErrorBody,
      onRetry: onRetry,
    );
  }
}
