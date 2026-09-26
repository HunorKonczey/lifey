import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_header.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../../shared/widgets/empty_view.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/nav_collapse_controller.dart';
import '../../../../shared/widgets/trainer_view_menu.dart';
import '../../../chat/application/conversation_list_controller.dart';
import '../../shared/trainer_layout.dart';
import '../../shared/trainer_view_badge.dart';
import '../application/programs_controller.dart';
import '../application/selected_program_controller.dart';
import '../domain/program.dart';
import 'program_detail_screen.dart';
import 'widgets/edit_on_web_notice.dart';

/// The trainer's program library (frame G1).
///
/// Read and assign only — see [EditOnWebNotice] for why authoring is not here.
class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final programs = ref.watch(programsProvider);
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final twoPane = isTrainerTwoPane(context);

    Future<void> refresh() async {
      ref.invalidate(programsProvider);
      await ref.read(programsProvider.future);
    }

    // A program deleted on the web must not linger in the pane beside the list.
    ref.listen(programsProvider, (_, next) {
      next.whenData((list) => ref
          .read(selectedProgramControllerProvider.notifier)
          .keepOnlyIfPresent(list.map((program) => program.id)));
    });

    final header = LifeyHeader(
      title: l10n.trainerProgramsTitle,
      badge: const TrainerViewBadge(),
      // The mark is a 12/16 caps line in a padded pill; it grows with the text.
      badgeHeight: MediaQuery.textScalerOf(context).scale(16) + 2 * AppSpacing.s4,
      actions: [
        HeaderIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: l10n.chatOpenTooltip,
          showDot: (ref.watch(unreadBadgeProvider).value ?? 0) > 0,
          onPressed: () => context.push('/chat'),
        ),
        const TrainerViewMenu(inTrainerView: true),
      ],
    );

    final bottomPad = MediaQuery.paddingOf(context).bottom + (twoPane ? AppSpacing.s24 : 96);

    final List<Widget> content = isOffline && !programs.hasValue
        ? [
            SliverFillRemaining(
              child: EmptyView(
                icon: Icons.cloud_off,
                title: l10n.trainerOfflineTitle,
                subtitle: l10n.trainerOfflineMessage,
                action: FilledButton.tonal(onPressed: refresh, child: Text(l10n.retryButton)),
              ),
            ),
          ]
        : programs.when(
            data: (list) => list.isEmpty
                ? [
                    SliverFillRemaining(
                      child: EmptyView(
                        icon: Icons.calendar_view_week_outlined,
                        title: l10n.trainerNoProgramsTitle,
                        subtitle: l10n.trainerNoProgramsMessage,
                        action: const EditOnWebButton(),
                      ),
                    ),
                  ]
                : [
                    SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.s12),
                        child: _ProgramCard(program: list[i], twoPane: twoPane),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s4, AppSpacing.screen, 0),
                        child: EditOnWebNotice(),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
                  ],
            loading: () => const [SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
            error: (error, _) => [SliverFillRemaining(child: ErrorView(error: error, onRetry: refresh))],
          );

    final list = ScrollCollapseListener(
      child: RefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top + 52,
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [header, ...content],
        ),
      ),
    );

    // Tablet: a program's weeks read far better beside the library than after
    // a push (docs/chat/41-trainer-mobile-v2-plan.md §8.2).
    return Scaffold(
      body: twoPane
          ? TrainerTwoPane(list: list, detail: const _ProgramDetailPane())
          : list,
    );
  }
}

/// The right-hand pane: the picked program, or an invitation to pick one.
class _ProgramDetailPane extends ConsumerWidget {
  const _ProgramDetailPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProgramControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    if (selected == null) {
      return EmptyView(
        icon: Icons.touch_app_outlined,
        title: l10n.trainerPickProgramTitle,
        subtitle: l10n.trainerPickProgramMessage,
      );
    }
    return ProgramDetailScreen(
      key: ValueKey(selected),
      programId: selected,
      embedded: true,
    );
  }
}

class _ProgramCard extends ConsumerWidget {
  const _ProgramCard({required this.program, required this.twoPane});

  final ProgramSummary program;
  final bool twoPane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final selected = twoPane && ref.watch(selectedProgramControllerProvider) == program.id;

    final card = LifeyCard(
      onTap: () => twoPane
          ? ref.read(selectedProgramControllerProvider.notifier).select(program.id)
          : context.push('$trainerProgramsLocation/${program.id}'),
      child: Row(
        children: [
          ListIconHolder(icon: Icons.calendar_view_week_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  [
                    l10n.trainerProgramWeeksLabel(program.weeksCount),
                    l10n.trainerProgramPerWeekLabel(program.slotsPerWeek),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: p.text2),
                ),
              ],
            ),
          ),
          if (program.activeAssignmentCount > 0) ...[
            const SizedBox(width: AppSpacing.s8),
            TintedChip(
              label: l10n.trainerProgramActiveCountLabel(program.activeAssignmentCount),
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );
    if (!selected) return card;
    // The program whose weeks sit beside the list: a primary ring around it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
      ),
      child: card,
    );
  }
}
