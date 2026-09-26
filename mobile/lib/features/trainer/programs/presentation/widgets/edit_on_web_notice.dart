import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/constants/web_links.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/notice_card.dart';

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

  final int? programId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // A trainer thing, so the clay accent: the notice explains what this role
    // cannot do on the phone.
    return NoticeCard(
      icon: Icons.desktop_windows_outlined,
      accent: context.palette.role,
      title: l10n.trainerProgramsEditOnWebTitle,
      body: l10n.trainerProgramsEditOnWebMessage,
      actionLabel: l10n.trainerOpenOnWebAction,
      onAction: () => _openOnWeb(programId),
    );
  }
}

void _openOnWeb(int? programId) => launchUrl(
      Uri.parse(programId == null ? WebLinks.adminPrograms : WebLinks.adminProgram(programId)),
      mode: LaunchMode.externalApplication,
    );

/// The link on its own, for places that have already said why.
class EditOnWebButton extends StatelessWidget {
  const EditOnWebButton({super.key, this.programId});

  final int? programId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextButton.icon(
      onPressed: () => _openOnWeb(programId),
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: Text(l10n.trainerOpenOnWebAction),
    );
  }
}
