import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_roles_provider.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/monogram_avatar.dart';
import '../../../../shared/widgets/trainer_view_menu.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../settings/application/avatar_controller.dart';

/// The monogram avatar at the end of the dashboard header — the way to
/// Settings ("Profile & settings") and, for trainers, into the trainer view
/// (docs/redesign/77-mobile-redesign-plan.md R1.2; canvas Lifey 1 top: "innen
/// érhető el a profil és edzőknek az edzői nézet").
///
/// Initials come from the name ("AK"), not the first letter of the e-mail;
/// an uploaded profile photo takes their place. The touch box is 48 dp around
/// the 44 px circle, like the other header buttons.
class DashboardAvatarMenu extends ConsumerWidget {
  const DashboardAvatarMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).value;
    final photo = ref.watch(avatarControllerProvider).value;
    final isTrainer = ref.watch(isTrainerProvider);
    final name = [user?.firstName, user?.lastName]
        .where((part) => part != null && part.isNotEmpty)
        .join(' ');

    return PopupMenuButton<void>(
      tooltip: l10n.dashboardProfileMenuLabel,
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: MonogramAvatar(
            name: name,
            email: user?.email,
            image: photo == null ? null : MemoryImage(photo),
          ),
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: () => context.push('/settings'),
          child: _MenuRow(
            icon: Icons.person_outline_rounded,
            label: l10n.dashboardProfileMenuLabel,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (isTrainer)
          PopupMenuItem<void>(
            onTap: () => switchTrainerView(context, ref, trainer: true),
            child: _MenuRow(
              icon: Icons.fitness_center_rounded,
              label: l10n.trainerViewSwitchToTrainerLabel,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.s12),
        // Flexible: a popup menu is as wide as its widest item, so a long
        // Hungarian label has to wrap instead of overflowing.
        Flexible(child: Text(label)),
      ],
    );
  }
}
