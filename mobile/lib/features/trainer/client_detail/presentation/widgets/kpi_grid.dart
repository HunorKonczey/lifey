import 'package:flutter/material.dart';

/// KPI tiles two to a row (canvas Lifey 6, client overview), each row as tall
/// as its taller tile — a tile with a subline beside one without must not leave
/// a ragged edge. An odd last tile takes half a row rather than stretching.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.tiles, this.gap = 10});

  final List<Widget> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < tiles.length; row += 2) ...[
          if (row > 0) SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[row]),
                SizedBox(width: gap),
                Expanded(child: row + 1 < tiles.length ? tiles[row + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
