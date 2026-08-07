import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../core/auth/current_roles_provider.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/chat_search_controller.dart';
import '../application/chat_thread_controller.dart';
import '../domain/chat_message.dart';
import '../domain/message_highlight.dart';

/// Search inside one thread.
///
/// Its own screen rather than a mode on the thread: the thread is a reversed,
/// keyset-paged stream anchored to the bottom, and results are scattered across
/// all of history in the opposite reading order. Sharing one scroll view would
/// mean two incompatible list models in one widget.
class ChatSearchScreen extends ConsumerStatefulWidget {
  const ChatSearchScreen({super.key, required this.conversationId});

  final int conversationId;

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ChatSearchController get _search =>
      ref.read(chatSearchControllerProvider(widget.conversationId).notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(chatSearchControllerProvider(widget.conversationId));
    final conversation = ref.watch(chatConversationProvider(widget.conversationId)).value;
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _search.search,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: l10n.chatSearchPlaceholder,
            hintStyle: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          if (state.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.chatSearchClearAction,
              onPressed: () {
                _controller.clear();
                _search.search('');
              },
            ),
        ],
      ),
      body: _body(state, conversation?.peer.displayName ?? '', currentUserId, l10n),
    );
  }

  Widget _body(
    ChatSearchState state,
    String peerName,
    int? currentUserId,
    AppLocalizations l10n,
  ) {
    if (state.failed) {
      return ErrorView(
        error: l10n.chatSearchFailed,
        onRetry: () => unawaited(_search.retry()),
      );
    }
    if (state.isIdle) {
      return EmptyView(
        icon: Icons.search,
        title: l10n.chatSearchPromptTitle,
        subtitle: l10n.chatSearchPromptBody(chatSearchMinLength),
      );
    }
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.isEmptyResult) {
      return EmptyView(
        icon: Icons.search_off,
        title: l10n.chatSearchNoResultsTitle,
        subtitle: l10n.chatSearchNoResultsBody,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final message = state.results[index];
        return _ResultTile(
          message: message,
          term: state.query,
          senderName: currentUserId != null && message.senderId == currentUserId
              ? l10n.chatOwnMessageSender
              : peerName,
        );
      },
    );
  }

}

/// One hit: who wrote it, when, and the text with the match picked out.
///
/// Not tappable. Jumping to the message in context would mean loading the
/// thread's keyset window down to it, and a half-loaded window renders
/// unrelated messages as neighbours — see the plan §20.3.
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.message,
    required this.term,
    required this.senderName,
  });

  final ChatMessage message;
  final String term;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final when = DateFormat.yMMMd(locale).add_Hm().format(message.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                senderName,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  when,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (message.hasAttachment)
                Text(
                  l10n.chatImagePreview,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text.rich(
            TextSpan(
              children: [
                for (final segment in highlightSegments(message.body ?? '', term))
                  TextSpan(
                    text: segment.text,
                    style: segment.match
                        ? TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            backgroundColor: scheme.primary.withValues(alpha: 0.28),
                          )
                        : null,
                  ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
