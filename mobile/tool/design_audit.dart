// Style-debt audit for the design-system migration
// (docs/redesign/77-mobile-redesign-plan.md R7.1).
//
// Counts, per file under `lib/`, the hand-rolled styling the v2 design system
// replaces: `fontSize:` literals, `Color(0x…)` literals, `BorderRadius.circular(`
// literals, plain `AppBar(`s, `AdaptiveAppBar(`s and the legacy `AppRadius`
// aliases (sm / md / input / lg / nav). Files under `lib/core/theme/` (where the
// tokens are defined) and `lib/shared/widgets/ds/` (the design system itself)
// are skipped, as are generated files, and lines that are only a comment.
//
// Run it at the end of every iteration and paste the totals in the PR:
//
//     dart run tool/design_audit.dart            # totals + the 25 worst files
//     dart run tool/design_audit.dart --files    # every file with a count
//     dart run tool/design_audit.dart --strict   # exit 1 while anything is left
//
// A literal that is *meant* to stay (a brand colour, a size that is a geometry
// rather than a type size) carries `// design-audit: ok` on its line and is
// counted separately as "allowed".
import 'dart:io';

/// The measures, in report order.
const _measures = <String, String>{
  'fontSize': r'fontSize\s*:',
  'Color(0x': r'\bColor\(\s*0x',
  'BorderRadius.circular': r'\bBorderRadius\.circular\(',
  'AppBar': r'(?<![A-Za-z])AppBar\(',
  'AdaptiveAppBar': r'\bAdaptiveAppBar\(',
  'AppRadius legacy': r'\bAppRadius\.(sm|md|input|lg|nav)(All)?\b',
};

/// Path fragments that are never audited.
const _skipped = <String>[
  'lib/core/theme/',
  'lib/shared/widgets/ds/',
  'lib/l10n/app_localizations',
];

const _allowMarker = 'design-audit: ok';

void main(List<String> args) {
  final strict = args.contains('--strict');
  final allFiles = args.contains('--files');
  final root = Directory('lib');
  if (!root.existsSync()) {
    stderr.writeln('Run from the mobile/ directory (no lib/ here).');
    exit(2);
  }

  final patterns = {for (final e in _measures.entries) e.key: RegExp(e.value)};
  final totals = {for (final k in _measures.keys) k: 0};
  var allowed = 0;
  final perFile = <String, Map<String, int>>{};

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
    if (_skipped.any(path.contains)) continue;

    final counts = {for (final k in _measures.keys) k: 0};
    for (final line in entity.readAsLinesSync()) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) continue;
      final ok = line.contains(_allowMarker);
      for (final e in patterns.entries) {
        var hits = 0;
        for (final match in e.value.allMatches(line)) {
          // `BorderRadius.circular(AppRadius.card)` is the token in use, not debt.
          if (e.key == 'BorderRadius.circular' && !_hasNumericArgument(line, match.end)) continue;
          hits++;
        }
        if (hits == 0) continue;
        if (ok) {
          allowed += hits;
        } else {
          counts[e.key] = counts[e.key]! + hits;
        }
      }
    }
    final sum = counts.values.fold<int>(0, (a, b) => a + b);
    if (sum == 0) continue;
    perFile[path] = counts;
    for (final e in counts.entries) {
      totals[e.key] = totals[e.key]! + e.value;
    }
  }

  final grand = totals.values.fold<int>(0, (a, b) => a + b);
  stdout.writeln('Design audit (lib/, excluding core/theme and shared/widgets/ds)');
  stdout.writeln('');
  for (final e in totals.entries) {
    stdout.writeln('  ${e.key.padRight(24)} ${e.value.toString().padLeft(5)}');
  }
  stdout.writeln('  ${'-' * 30}');
  stdout.writeln('  ${'total'.padRight(24)} ${grand.toString().padLeft(5)}   (${perFile.length} files; $allowed allowed by marker)');

  if (perFile.isNotEmpty) {
    final ranked = perFile.entries.toList()
      ..sort((a, b) => _sum(b.value).compareTo(_sum(a.value)));
    final shown = allFiles ? ranked : ranked.take(25).toList();
    stdout.writeln('');
    stdout.writeln(allFiles ? 'Files:' : 'Worst ${shown.length} files (--files for all):');
    for (final e in shown) {
      final detail = [
        for (final m in e.value.entries)
          if (m.value > 0) '${m.key} ${m.value}',
      ].join(', ');
      stdout.writeln('  ${_sum(e.value).toString().padLeft(4)}  ${e.key.replaceFirst('lib/', '')}  ($detail)');
    }
  }

  if (strict && grand > 0) exit(1);
}

int _sum(Map<String, int> counts) => counts.values.fold<int>(0, (a, b) => a + b);

/// True when the argument that starts at [from] (just after `circular(`)
/// contains a number once identifiers — `AppRadius.card`, `AppSpacing.s16`,
/// `height` — are taken out: `18`, `size / 6`, `nested ? 14 : 18`.
bool _hasNumericArgument(String line, int from) {
  var depth = 1;
  var i = from;
  for (; i < line.length && depth > 0; i++) {
    final c = line[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
  }
  final argument = line.substring(from, depth == 0 ? i - 1 : line.length);
  // Derived from the tokens (`AppRadius.nested(AppRadius.card, 12)`): in use.
  if (argument.trimLeft().startsWith('AppRadius.')) return false;
  final withoutIdentifiers = argument.replaceAll(RegExp(r'[A-Za-z_][A-Za-z0-9_.]*'), '');
  return RegExp(r'\d').hasMatch(withoutIdentifiers);
}
