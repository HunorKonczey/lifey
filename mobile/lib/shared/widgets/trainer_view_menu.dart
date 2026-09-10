import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/current_roles_provider.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/trainer/application/trainer_view_preference.dart';
import '../../l10n/app_localizations.dart';

/// Where the trainer shell starts. Kept next to the switch that navigates
/// there so the two never drift apart.
const String trainerShellLocation = '/trainer/clients';

/// The shell's other branches, in navigation order.
const String trainerCalendarLocation = '/trainer/calendar';
const String trainerAssignmentsLocation = '/trainer/assignments';
const String trainerProgramsLocation = '/trainer/programs';

/// Pushed over the shell rather than being a branch of it: both are things a
/// trainer visits and leaves, not places they work from.
const String trainerInvitesLocation = '/trainer/invites';
const String trainerSettingsLocation = '/trainer/settings';

/// The avatar menu that moves a trainer between their two homes:
/// "Trainer view" from the client side, "My own log" from the trainer side
/// (docs/chat/41-trainer-mobile-v2-plan.md §2.1).
///
/// This is navigation, not a mode: both shells stay alive side by side, and
/// the choice is remembered so the app opens where the user last worked.
/// Renders nothing at all for a user without `ROLE_TRAINER` — which is almost
/// everyone, so the client dashboard is unchanged for them.
class TrainerViewMenu extends ConsumerWidget {
  const TrainerViewMenu({super.key, required this.inTrainerView});

  /// Which side the menu is being shown from — it offers the *other* side.
  final bool inTrainerView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isTrainerProvider)) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<void>(
      tooltip: l10n.trainerViewSwitchTooltip,
      position: PopupMenuPosition.under,
      icon: _Avatar(
        monogram: _monogramOf(ref),
        // The avatar wears the accent of the view it can take you to, so the
        // switch is legible before the menu is even open.
        color: inTrainerView ? scheme.primaryContainer : scheme.tertiaryContainer,
        foreground: inTrainerView ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
      ),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: () => _switchTo(context, ref, trainer: !inTrainerView),
          child: Row(
            children: [
              Icon(
                inTrainerView ? Icons.person_outline : Icons.fitness_center,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              // Flexible, not bare: a popup menu is as wide as its widest
              // item and no wider, so a long label in either language has to
              // be allowed to wrap rather than overflow the row.
              Flexible(
                child: Text(
                  inTrainerView
                      ? l10n.trainerViewSwitchToClientLabel
                      : l10n.trainerViewSwitchToTrainerLabel,
                ),
              ),
            ],
          ),
        ),
        // Only from inside the trainer view: on the client side this menu is
        // a door, and a door does not need a settings drawer.
        if (inTrainerView)
          PopupMenuItem<void>(
            onTap: () => context.push(trainerSettingsLocation),
            child: Row(
              children: [
                Icon(Icons.tune, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Flexible(child: Text(l10n.trainerSettingsTitle)),
              ],
            ),
          ),
      ],
    );
  }

  void _switchTo(BuildContext context, WidgetRef ref, {required bool trainer}) {
    // Remember first: if the app is killed right after the switch, it should
    // come back where the user just went, not where they left.
    ref.read(lastViewIsTrainerProvider.notifier).set(isTrainerView: trainer);
    context.go(trainer ? trainerShellLocation : '/dashboard');
  }

  String _monogramOf(WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return '?';
    final name = [user.firstName, user.lastName]
        .where((part) => part != null && part.isNotEmpty)
        .join(' ')
        .trim();
    final source = name.isNotEmpty ? name : user.email;
    final words = source.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.monogram,
    required this.color,
    required this.foreground,
  });

  final String monogram;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        monogram,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
