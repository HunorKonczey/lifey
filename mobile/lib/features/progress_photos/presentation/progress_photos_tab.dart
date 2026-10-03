import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/progress_photo_controller.dart';
import 'widgets/progress_photo_tile.dart';

/// The photos tab of the Body screen (docs/80 §7 P6): the timeline as a
/// three-column grid, newest first. No Scaffold of its own — the Body screen
/// owns the app bar and the floating "Add photo" button. Photos are
/// online-only (docs/80 §2.1), so a failed load is an error with a retry
/// rather than an empty list.
class ProgressPhotosTab extends ConsumerWidget {
  const ProgressPhotosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(progressPhotoControllerProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom + AppSpacing.s56 + AppSpacing.s32;

    return RefreshIndicator(
      onRefresh: () => ref.read(progressPhotoControllerProvider.notifier).refresh(),
      child: state.when(
        data: (photos) => photos.isEmpty
            ? CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: EmptyView(
                      icon: Icons.photo_camera_outlined,
                      title: l10n.photosEmptyTitle,
                      subtitle: l10n.photosEmptySubtitle,
                    ),
                  ),
                ],
              )
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (photos.length >= 2)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.s8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonalIcon(
                            onPressed: () => context.push('/progress-photos/compare'),
                            icon: const Icon(Icons.compare_rounded, size: 20),
                            label: Text(l10n.photosCompareButton),
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, bottomPad),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: AppSpacing.s8,
                        crossAxisSpacing: AppSpacing.s8,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, i) => ProgressPhotoTile(
                        photo: photos[i],
                        onTap: () => context.push('/progress-photos/${photos[i].id}'),
                      ),
                    ),
                  ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(progressPhotoControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}
