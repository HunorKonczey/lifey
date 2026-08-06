import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/current_roles_provider.dart';
import '../../../core/network/error_message.dart';
import '../../../core/sync/connectivity_status_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/empty_view.dart';
import '../application/chat_thread_controller.dart';
import '../domain/chat_conversation.dart';
import '../domain/chat_message.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_composer.dart';
import 'widgets/day_divider.dart';
import 'widgets/message_bubble.dart';

/// One conversation. Identical for both roles — nothing on this screen knows
/// whether the person on the other side is a trainer or a client.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId});

  final int conversationId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _send(String body) async {
    await ref.read(_controllerProvider.notifier).send(body);
    // The new bubble is at offset 0 in a reversed list.
    if (_scrollController.hasClients) {
      unawaited(_scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ));
    }
  }

  Future<void> _delete(String clientId) async {
    try {
      await ref.read(_controllerProvider.notifier).delete(clientId);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final conversation = ref.watch(chatConversationProvider(widget.conversationId)).value;
    final messages = ref.watch(_controllerProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: conversation == null
            ? const SizedBox.shrink()
            : Row(
                children: [
                  ChatAvatar(monogram: conversation.peer.monogram, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      conversation.peer.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
        // No presence subtitle: there is no live-presence signal until the
        // SSE stream lands (I4), and a fabricated "online" would be a lie.
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
                : ChatComposer(onSend: _send),
          ),
        ],
      ),
      backgroundColor: scheme.surface,
    );
  }

  Widget _buildStream(
    List<ChatMessage> messages,
    ChatConversation? conversation,
    int? currentUserId,
  ) {
    // Reversed so the thread sits at the bottom and the keyboard pushes it up
    // without any manual scroll maths — index 0 is the newest message.
    final ordered = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
          isOwn: isOwn,
          senderName: isOwn
              ? ''
              : (conversation?.peer.displayName ?? ''),
          showTail: endsRun,
          showAvatar: endsRun,
          peerMonogram: conversation?.peer.monogram ?? '',
          onRetry: () => ref.read(_controllerProvider.notifier).retry(message.clientId),
          onDelete: () => message.isUnsent
              ? ref.read(_controllerProvider.notifier).discard(message.clientId)
              : _delete(message.clientId),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.error.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Alternating sides and widths, so the placeholder reads as a
    // conversation rather than a loading list.
    const shapes = [(false, 180.0), (true, 140.0), (false, 220.0), (true, 90.0)];
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      children: [
        for (final (isOwn, width) in shapes)
          Align(
            alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: width,
              height: 40,
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 44, color: scheme.error),
          const SizedBox(height: 14),
          Text(l10n.chatLoadErrorTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l10n.chatLoadErrorBody,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.chatRetryAction),
          ),
        ],
      ),
    );
  }
}
