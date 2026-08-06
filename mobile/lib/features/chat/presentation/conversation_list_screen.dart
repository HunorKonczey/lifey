import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/current_roles_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/conversation_list_controller.dart';
import '../domain/chat_conversation.dart';
import 'new_conversation_sheet.dart';
import 'widgets/conversation_tile.dart';

/// The chat home.
///
/// One screen for both roles — the endpoint returns "my threads" whoever asks,
/// so a trainer's client list and a client's trainer thread are the same list.
/// Exactly three things branch on the role (docs/chat/40-trainer-chat-plan.md
/// §6.1): the title, the empty-state copy, and the "new conversation" button.
///
/// In v1 this list *is* the trainer's mobile surface; the rest of the trainer
/// screens are the v2 plan's scope.
class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends ConsumerState<ConversationListScreen> {
  /// Below this many rows a search field is more chrome than help — a client
  /// has one or two threads.
  static const _searchThreshold = 10;

  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  List<ChatConversation> _filter(List<ChatConversation> conversations) {
    if (_query.trim().isEmpty) return conversations;
    final needle = _query.toLowerCase();
    return conversations
        .where((c) =>
            c.peer.displayName.toLowerCase().contains(needle) ||
            c.peer.email.toLowerCase().contains(needle))
        .toList();
  }

  Future<void> _openNewConversation() async {
    final conversationId = await showNewConversationSheet(context);
    if (conversationId != null && mounted) {
      context.push('/chat/$conversationId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTrainer = ref.watch(isTrainerProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final state = ref.watch(conversationListControllerProvider);

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;

    return Scaffold(
      floatingActionButton: isTrainer
          ? FloatingActionButton(
              onPressed: _openNewConversation,
              tooltip: l10n.chatNewConversationTooltip,
              child: const Icon(Icons.add_comment_outlined),
            )
          : null,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: contentTop),
            child: state.when(
              data: (conversations) => _buildList(
                context,
                l10n,
                conversations,
                isTrainer: isTrainer,
                currentUserId: currentUserId,
              ),
              loading: () => const _ConversationListSkeleton(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(conversationListControllerProvider),
              ),
            ),
          ),
          Positioned(
            top: barTop,
            left: 12,
            right: 12,
            child: AdaptiveAppBar(
              title: isTrainer ? l10n.chatTrainerListTitle : l10n.chatClientListTitle,
              onBack: () => context.pop(),
              searching: _searching,
              searchController: _searchController,
              searchHint: l10n.chatSearchHint,
              onSearchChanged: (value) => setState(() => _query = value),
              onSearchClose: _closeSearch,
              actions: [
                if (!_searching && _showSearchAction(state.value))
                  AdaptiveAppBarAction(
                    icon: Icons.search,
                    tooltip: l10n.chatSearchHint,
                    onPressed: () => setState(() => _searching = true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _showSearchAction(List<ChatConversation>? conversations) {
    return (conversations?.length ?? 0) >= _searchThreshold;
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<ChatConversation> conversations, {
    required bool isTrainer,
    required int? currentUserId,
  }) {
    if (conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(conversationListControllerProvider.notifier).refresh(),
        child: EmptyView(
          icon: isTrainer ? Icons.group_outlined : Icons.forum_outlined,
          title: isTrainer ? l10n.chatTrainerEmptyTitle : l10n.chatClientEmptyTitle,
          subtitle: isTrainer ? l10n.chatTrainerEmptyBody : l10n.chatClientEmptyBody,
        ),
      );
    }

    // Only a dual-role account sees both kinds of peer at once; on a uniform
    // list the label would repeat on every row and say nothing.
    final roles = conversations.map((c) => c.peer.role).toSet();
    final showRoleLabels = roles.length > 1;

    final visible = _filter(conversations);

    return RefreshIndicator(
      onRefresh: () => ref.read(conversationListControllerProvider.notifier).refresh(),
      child: ListView.builder(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 88,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final conversation = visible[index];
          return ConversationTile(
            conversation: conversation,
            isOwnLastMessage: conversation.lastMessageSenderId != null &&
                conversation.lastMessageSenderId == currentUserId,
            showRoleLabel: showRoleLabels,
            onTap: () => context.push('/chat/${conversation.id}'),
          );
        },
      ),
    );
  }
}

/// Three row skeletons — the design's required loading state, matching the
/// real row's rhythm so the list doesn't jump when data lands.
class _ConversationListSkeleton extends StatelessWidget {
  const _ConversationListSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bar(width: 120, color: scheme.surfaceContainerHigh),
                    const SizedBox(height: 8),
                    _Bar(width: 200, color: scheme.surfaceContainerHigh),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
    );
  }
}
