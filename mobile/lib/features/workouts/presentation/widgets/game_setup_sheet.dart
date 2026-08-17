import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/game_setup_preferences.dart';

String gameFormatLabel(AppLocalizations l10n, GameFormat format) => switch (format) {
      GameFormat.fiveVsFive => l10n.gameFormatFiveVsFive,
      GameFormat.smallSided => l10n.gameFormatSmallSided,
      GameFormat.practice => l10n.gameFormatPractice,
      GameFormat.match => l10n.gameFormatMatch,
    };

/// M45's format selector: **2×2, not a single row**. Four segments across one
/// line don't fit in Hungarian ("Kispálya"), and a squeezed segmented control
/// either ellipsises its labels or forces type down to an unreadable size.
class GameFormatSelector extends StatelessWidget {
  const GameFormatSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final GameFormat value;
  final ValueChanged<GameFormat> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Two rows of two, in the enum's own order.
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: _FormatOption(
                    label: gameFormatLabel(l10n, GameFormat.values[row * 2 + col]),
                    selected: value == GameFormat.values[row * 2 + col],
                    onTap: enabled ? () => onChanged(GameFormat.values[row * 2 + col]) : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.18) : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: selected ? Border.all(color: scheme.primary, width: 1.5) : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: selected ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// M45's venue pair. The **one** place venue is chosen: it drives GPS on the
/// phone and `locationType` on the watch (C5.2), and a second control for it
/// anywhere would let the two disagree.
class GameVenueSelector extends StatelessWidget {
  const GameVenueSelector({
    super.key,
    required this.venue,
    required this.onChanged,
    this.enabled = true,
  });

  final String venue;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _VenueOption(
            icon: Icons.home_work,
            label: l10n.venueIndoorLabel,
            selected: venue == 'INDOOR',
            onTap: enabled ? () => onChanged('INDOOR') : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _VenueOption(
            icon: Icons.park,
            label: l10n.venueOutdoorLabel,
            selected: venue == 'OUTDOOR',
            onTap: enabled ? () => onChanged('OUTDOOR') : null,
          ),
        ),
      ],
    );
  }
}

class _VenueOption extends StatelessWidget {
  const _VenueOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.18) : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: selected ? Border.all(color: scheme.primary, width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? scheme.primary : scheme.onSurface,
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

/// The sheet a GAME-family session starts through (C9.3, M45).
///
/// **It never blocks the start**: both fields open pre-filled with the last
/// match's answers ([GameSetupPreferences]), so "Start" is reachable with the
/// first tap and someone who plays the same 5v5 every week never touches
/// anything else. Dismissing it by swiping is a cancel, not a broken start —
/// the caller only creates the session when [GameSetup] comes back.
class GameSetupSheet extends ConsumerStatefulWidget {
  const GameSetupSheet({super.key});

  @override
  ConsumerState<GameSetupSheet> createState() => _GameSetupSheetState();
}

class _GameSetupSheetState extends ConsumerState<GameSetupSheet> {
  GameSetup? _setup;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final setup = await ref.read(gameSetupPreferencesProvider).load();
    if (mounted) setState(() => _setup = setup);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final setup = _setup;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.gameSetupTitle,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.gameSetupSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (setup == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _SectionLabel(label: l10n.gameFormatSectionLabel),
            const SizedBox(height: 8),
            GameFormatSelector(
              value: setup.format,
              onChanged: (format) => setState(() => _setup = setup.copyWith(format: format)),
            ),
            const SizedBox(height: 16),
            _SectionLabel(label: l10n.venueSectionLabel),
            const SizedBox(height: 8),
            GameVenueSelector(
              venue: setup.venue,
              onChanged: (venue) => setState(() => _setup = setup.copyWith(venue: venue)),
            ),
            // M45: the GPS row exists **only outdoors**. Indoors it isn't
            // switched off, it isn't there — there is nothing to record in a
            // hall, so no toggle and no permission prompt either ("nem
            // letiltva, hanem nem létezik").
            if (setup.isOutdoor) ...[
              const SizedBox(height: 8),
              _GpsRow(
                enabled: setup.gpsEnabled,
                onChanged: (value) => setState(() => _setup = setup.copyWith(gpsEnabled: value)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(setup),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.gameSetupStart),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// M45's GPS row plus the one promise the app makes nowhere else: **what you
/// get and what you don't**. A match records distance and a route, but *not
/// pace* — min/km on a basketball court is not a number that means anything,
/// and saying so here is what stops it reading as a bug on the summary
/// (docs/cardio/51 §3.4).
class _GpsRow extends StatelessWidget {
  const _GpsRow({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(Icons.gps_fixed, color: scheme.onSurfaceVariant),
          title: Text(l10n.gameGpsSwitchLabel),
          subtitle: Text(l10n.gameGpsSwitchDescription),
          value: enabled,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 8),
          child: Text(
            l10n.gameGpsPromise,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Shows [GameSetupSheet]. Returns the chosen setup, or `null` when the sheet
/// was dismissed without starting.
Future<GameSetup?> showGameSetupSheet(BuildContext context) {
  return showModalBottomSheet<GameSetup>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const GameSetupSheet(),
  );
}
