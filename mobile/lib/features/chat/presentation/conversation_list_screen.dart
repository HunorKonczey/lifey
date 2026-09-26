import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/current_roles_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/ds/grouped_list_item.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
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

    final header = LifeyHeader(
      title: isTrainer ? l10n.chatTrainerListTitle : l10n.chatClientListTitle,
      onBack: () => context.pop(),
      actions: [
        if (!_searching && _showSearchAction(state.value))
          HeaderIconButton(
            icon: Icons.search_rounded,
            tooltip: l10n.chatSearchHint,
            onPressed: () => setState(() => _searching = true),
          ),
      ],
    );

    return Scaffold(
      floatingActionButton: isTrainer
          ? FloatingActionButton(
              onPressed: _openNewConversation,
              tooltip: l10n.chatNewConversationTooltip,
              child: const Icon(Icons.add_comment_outlined),
            )
          : null,
      body: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top + 52,
        onRefresh: () => ref.read(conversationListControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            header,
            if (_searching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s4),
                  child: _SearchField(
                    controller: _searchController,
                    hint: l10n.chatSearchHint,
                    onChanged: (value) => setState(() => _query = value),
                    onClose: _closeSearch,
                  ),
                ),
              ),
            ...state.when(
              data: (conversations) => _buildList(
                context,
                l10n,
                conversations,
                isTrainer: isTrainer,
                currentUserId: currentUserId,
              ),
              loading: () => const [SliverToBoxAdapter(child: _ConversationListSkeleton())],
              error: (error, _) => [
                SliverFillRemaining(
                  child: ErrorView(error: error, onRetry: () => ref.invalidate(conversationListControllerProvider)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _showSearchAction(List<ChatConversation>? conversations) {
    return (conversations?.length ?? 0) >= _searchThreshold;
  }

  List<Widget> _buildList(
    BuildContext context,
    AppLocalizations l10n,
    List<ChatConversation> conversations, {
    required bool isTrainer,
    required int? currentUserId,
  }) {
    if (conversations.isEmpty) {
      return [
        SliverFillRemaining(
          child: EmptyView(
            icon: isTrainer ? Icons.group_outlined : Icons.forum_outlined,
            title: isTrainer ? l10n.chatTrainerEmptyTitle : l10n.chatClientEmptyTitle,
            subtitle: isTrainer ? l10n.chatTrainerEmptyBody : l10n.chatClientEmptyBody,
          ),
        ),
      ];
    }

    // Only a dual-role account sees both kinds of peer at once; on a uniform
    // list the label would repeat on every row and say nothing.
    final roles = conversations.map((c) => c.peer.role).toSet();
    final showRoleLabels = roles.length > 1;

    final visible = _filter(conversations);
    final bottom = MediaQuery.paddingOf(context).bottom + 88;

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottom),
        sliver: SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final conversation = visible[index];
            return GroupedListItem(
              first: index == 0,
              last: index == visible.length - 1,
              dividerInset: 80,
              child: ConversationTile(
                conversation: conversation,
                isOwnLastMessage: conversation.lastMessageSenderId != null &&
                    conversation.lastMessageSenderId == currentUserId,
                showRoleLabel: showRoleLabels,
                onTap: () => context.push('/chat/${conversation.id}'),
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// The inline filter of a long list: a pill with the query and a close button.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged, required this.onClose});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        suffixIcon: IconButton(
          icon: Icon(Icons.close_rounded, size: 22, color: p.text2),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: onClose,
        ),
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
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, 0),
      child: Column(
        children: List.generate(
          3,
          (i) => GroupedListItem(
            first: i == 0,
            last: i == 2,
            dividerInset: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
              child: Row(
                children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: p.control, shape: BoxShape.circle)),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bar(width: 120, color: p.control),
                        const SizedBox(height: AppSpacing.s8),
                        _Bar(width: 200, color: p.control),
                      ],
                    ),
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

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: width, height: 10, decoration: BoxDecoration(color: color, borderRadius: AppRadius.pill));
  }
}
