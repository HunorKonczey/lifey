import 'package:flutter/material.dart';

/// KPI tiles [columns] to a row — two on a phone, four on the tablet's wide
/// detail pane (canvas Lifey 6) — each row as tall as its tallest tile: a tile
/// with a subline beside one without must not leave a ragged edge. A short last
/// row leaves its empty cells empty rather than stretching the tiles.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.tiles, this.columns = 2, this.gap = 10});

  final List<Widget> tiles;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < tiles.length; row += columns) ...[
          if (row > 0) SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: row + i < tiles.length ? tiles[row + i] : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
