import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// One lazily built row of a grouped card — the "fewer boxes" `ListGroup` look
/// for paged lists, where the rows cannot all sit inside one [ListGroup]
/// (docs/redesign/77-mobile-redesign-plan.md R2.9 foods, R3.3 sessions).
///
/// Each item carries the card surface; [first] and [last] round the group's
/// corners and every item but the first starts with a hairline (indented by
/// [dividerInset], under the text like `ListGroup`). Pass [dismissKey] and
/// [confirmDismiss] for swipe-to-delete: the row is only ever removed by the
/// list's own stream, so [confirmDismiss] should run the delete itself and
/// return false.
class GroupedListItem extends StatelessWidget {
  const GroupedListItem({
    super.key,
    required this.first,
    required this.last,
    required this.child,
    this.dividerInset = 74,
    this.dismissKey,
    this.confirmDismiss,
  }) : assert((dismissKey == null) == (confirmDismiss == null), 'dismissKey and confirmDismiss go together');

  final bool first;
  final bool last;
  final Widget child;
  final double dividerInset;
  final Key? dismissKey;
  final Future<bool> Function()? confirmDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const radius = Radius.circular(AppRadius.card);
    final shape = BorderRadius.vertical(top: first ? radius : Radius.zero, bottom: last ? radius : Radius.zero);

    Widget item = Material(
      color: p.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!first) Divider(height: 1, thickness: 1, indent: dividerInset, color: p.hairline),
          child,
        ],
      ),
    );

    if (dismissKey != null) {
      final heart = context.metricColors.heart;
      item = Dismissible(
        key: dismissKey!,
        direction: DismissDirection.endToStart,
        background: Container(
          color: heart.withValues(alpha: 0.16),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          child: Icon(Icons.delete_rounded, color: heart),
        ),
        confirmDismiss: (_) => confirmDismiss!(),
        child: item,
      );
    }
    return ClipRRect(borderRadius: shape, child: item);
  }
}
