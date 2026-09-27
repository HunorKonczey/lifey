import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
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
    final state = ref.watch(chatSearchControllerProvider(widget.conversationId));
    final conversation = ref.watch(chatConversationProvider(widget.conversationId)).value;
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      // Back, the search field and — with a query — a clear button: the field
      // is the title, so this is the subpage header's row with a field in it.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.screen, AppSpacing.s8),
            child: Row(
              children: [
                HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _search.search,
                    decoration: InputDecoration(
                      hintText: l10n.chatSearchPlaceholder,
                      suffixIcon: state.query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 22),
                              tooltip: l10n.chatSearchClearAction,
                              onPressed: () {
                                _controller.clear();
                                _search.search('');
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s12, AppSpacing.screen, AppSpacing.s24),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
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
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final when = DateFormat.yMMMd(locale).add_Hm().format(message.createdAt);

    return LifeyCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(senderName, style: t.labelLarge!.copyWith(fontWeight: FontWeight.w800, color: p.text)),
              const SizedBox(width: AppSpacing.s8),
              Expanded(child: Text(when, style: t.bodySmall!.copyWith(color: p.text3))),
              if (message.hasAttachment) Text(l10n.chatImagePreview, style: t.bodySmall!.copyWith(color: p.text3)),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text.rich(
            TextSpan(
              children: [
                for (final segment in highlightSegments(message.body ?? '', term))
                  TextSpan(
                    text: segment.text,
                    style: segment.match
                        ? TextStyle(
                            color: p.text,
                            fontWeight: FontWeight.w800,
                            backgroundColor: scheme.primary.withValues(alpha: 0.28),
                          )
                        : null,
                  ),
              ],
            ),
            style: t.bodyMedium!.copyWith(color: p.text2),
          ),
        ],
      ),
    );
  }
}
