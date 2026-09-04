import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// D-P10 (`docs/landing_page/67-mobile-free-pro-plan.md` §5): "The ad layer
/// never reaches the watch, widgets or notifications — `core/ads/` is
/// imported only from phone-side presentation code... a test that
/// `core/watch/` and `core/home_screen_widget/` have no path to it."
///
/// A real transitive-reachability check over the import graph, not a
/// direct-import grep — a watch file importing something in, say,
/// `core/subscription/` that later grows its own `core/ads/` import would
/// slip past a shallow check but must still fail this one.

const _libDir = 'lib';
const _packagePrefix = 'package:lifey/';

final _importPattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);

/// Resolves one `import` line's target to a `lib/`-relative path, or `null`
/// for a non-project import (another package, a `dart:` core library) —
/// those can never lead back into this project's own `core/ads/`.
String? _resolveImport(String fromFile, String importPath) {
  if (importPath.startsWith(_packagePrefix)) {
    return importPath.substring(_packagePrefix.length);
  }
  if (importPath.startsWith('dart:') || importPath.contains('://')) return null;

  final fromDir = fromFile.contains('/') ? fromFile.substring(0, fromFile.lastIndexOf('/')) : '';
  final segments = [...fromDir.split('/'), ...importPath.split('/')];
  final resolved = <String>[];
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else {
      resolved.add(segment);
    }
  }
  return resolved.join('/');
}

Future<Map<String, Set<String>>> _buildImportGraph() async {
  final graph = <String, Set<String>>{};
  await for (final entity in Directory(_libDir).list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relPath = entity.path.substring(_libDir.length + 1).replaceAll('\\', '/');
    final content = await entity.readAsString();
    final targets = <String>{
      for (final match in _importPattern.allMatches(content))
        if (_resolveImport(relPath, match.group(1)!) case final resolved?) resolved,
    };
    graph[relPath] = targets;
  }
  return graph;
}

/// Depth-first search: is [targetPrefix] reachable from [from] by following
/// zero or more imports?
bool _hasPathTo(
  String from,
  String targetPrefix,
  Map<String, Set<String>> graph,
  Set<String> visited,
) {
  if (!visited.add(from)) return false;
  for (final target in graph[from] ?? const <String>{}) {
    if (target.startsWith(targetPrefix)) return true;
    if (_hasPathTo(target, targetPrefix, graph, visited)) return true;
  }
  return false;
}

void main() {
  late Map<String, Set<String>> graph;

  setUpAll(() async {
    graph = await _buildImportGraph();
  });

  test('core/watch/ has no import path to core/ads/', () {
    final watchFiles = graph.keys.where((f) => f.startsWith('core/watch/'));
    expect(watchFiles, isNotEmpty, reason: 'sanity check that the scan actually found core/watch/');
    for (final file in watchFiles) {
      expect(
        _hasPathTo(file, 'core/ads/', graph, {}),
        isFalse,
        reason: '$file has an import path into core/ads/ (D-P10)',
      );
    }
  });

  test('core/home_screen_widget/ has no import path to core/ads/', () {
    final widgetFiles = graph.keys.where((f) => f.startsWith('core/home_screen_widget/'));
    expect(widgetFiles, isNotEmpty,
        reason: 'sanity check that the scan actually found core/home_screen_widget/');
    for (final file in widgetFiles) {
      expect(
        _hasPathTo(file, 'core/ads/', graph, {}),
        isFalse,
        reason: '$file has an import path into core/ads/ (D-P10)',
      );
    }
  });
}
