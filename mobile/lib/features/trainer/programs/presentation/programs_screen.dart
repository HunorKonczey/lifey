import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/sync/connectivity_status_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/adaptive_app_bar.dart';
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

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;
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

    final list = ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                displacement: contentTop,
                onRefresh: refresh,
                child: isOffline && !programs.hasValue
                    ? EmptyView(
                        icon: Icons.cloud_off,
                        title: l10n.trainerOfflineTitle,
                        subtitle: l10n.trainerOfflineMessage,
                        action: FilledButton.tonal(
                          onPressed: refresh,
                          child: Text(l10n.retryButton),
                        ),
                      )
                    : programs.when(
                        data: (list) => list.isEmpty
                            ? EmptyView(
                                icon: Icons.calendar_view_week_outlined,
                                title: l10n.trainerNoProgramsTitle,
                                subtitle: l10n.trainerNoProgramsMessage,
                                action: const EditOnWebButton(),
                              )
                            : ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.only(
                                  top: contentTop,
                                  bottom:
                                      MediaQuery.paddingOf(context).bottom + 90,
                                ),
                                children: [
                                  for (final program in list)
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                      child: _ProgramCard(
                                        program: program,
                                        twoPane: twoPane,
                                      ),
                                    ),
                                  const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                                    child: EditOnWebNotice(),
                                  ),
                                ],
                              ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            ErrorView(error: error, onRetry: refresh),
                      ),
              ),
            ),
            Positioned(
              top: barTop,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(
                title: l10n.trainerProgramsTitle,
                titleBadge: const TrainerViewBadge(),
                actions: [
                  AdaptiveAppBarAction(
                    icon: Icons.chat_bubble_outline,
                    tooltip: l10n.chatOpenTooltip,
                    badgeCount: ref.watch(unreadBadgeProvider).value ?? 0,
                    onPressed: () => context.push('/chat'),
                  ),
                ],
                trailing: const TrainerViewMenu(inTrainerView: true),
              ),
            ),
          ],
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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final selected = twoPane && ref.watch(selectedProgramControllerProvider) == program.id;

    return Material(
      color: selected ? scheme.surfaceContainerHighest : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: selected
            ? BorderSide(color: scheme.tertiary, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => twoPane
            ? ref
                .read(selectedProgramControllerProvider.notifier)
                .select(program.id)
            : context.push('$trainerProgramsLocation/${program.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.calendar_view_week, size: 20, color: scheme.tertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        l10n.trainerProgramWeeksLabel(program.weeksCount),
                        l10n.trainerProgramPerWeekLabel(program.slotsPerWeek),
                      ].join(' · '),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (program.activeAssignmentCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    l10n.trainerProgramActiveCountLabel(
                      program.activeAssignmentCount,
                    ),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
