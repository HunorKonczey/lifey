import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/web_links.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';

/// Says plainly where programs get built (frame G4's second outcome).
///
/// The plan left this as a decision to make after prototyping, and the answer
/// is that a program grid is not a phone screen. Three reasons, none of them
/// about effort:
///
/// * A program is up to 12 weeks × 7 days. Authoring one means dozens of
///   picker round trips on a phone; it is a desk job, done once, then reused.
/// * `PUT /trainer/programs/{id}` replaces the whole grid. Editing on mobile
///   means holding all 84 cells and resending them, where a half-finished
///   state overwrites the real one.
/// * The design's own suggested affordance — long-press to reorder — does not
///   fit the data. A slot lives *at* week 3, Monday; it is not the second item
///   in a list, so dragging it somewhere would have to guess a new weekday.
///
/// What a trainer actually needs on a phone is to read a program and start
/// someone on it, and both of those are here. So this notice is a signpost,
/// not an apology.
class EditOnWebNotice extends StatelessWidget {
  const EditOnWebNotice({super.key, this.programId});

  /// When set, the link opens this program rather than the library.
  final int? programId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.desktop_windows_outlined,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.trainerProgramsEditOnWebTitle,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.trainerProgramsEditOnWebMessage,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: EditOnWebButton(programId: programId),
          ),
        ],
      ),
    );
  }
}

/// The link on its own, for places that have already said why.
class EditOnWebButton extends StatelessWidget {
  const EditOnWebButton({super.key, this.programId});

  final int? programId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextButton.icon(
      onPressed: () => launchUrl(
        Uri.parse(
          programId == null
              ? WebLinks.adminPrograms
              : WebLinks.adminProgram(programId!),
        ),
        mode: LaunchMode.externalApplication,
      ),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(l10n.trainerOpenOnWebAction),
    );
  }
}
