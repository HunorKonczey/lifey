import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../shared/client_avatar.dart';
import '../../domain/trainer_client.dart';
import 'client_status.dart';

/// A client as one compact row of the tablet list pane (canvas Lifey 6 ›
/// Trainer tablet): the 44 dp monogram, the name over the status line with its
/// dot, and a chevron. The picked client sits on the nested surface inside a
/// 1.5 px primary ring; the rest are bare rows — the detail beside the list
/// carries the numbers the phone's card puts on the card.
class ClientListRow extends StatelessWidget {
  const ClientListRow({
    super.key,
    required this.client,
    required this.now,
    required this.selected,
    required this.onTap,
  });

  final TrainerClient client;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final status = clientStatusOf(context, client, now, weighInFirst: true);
    final radius = BorderRadius.circular(AppRadius.nested(AppRadius.card, AppSpacing.s4));

    return Semantics(
      button: true,
      selected: selected,
      label: '${client.displayName}, ${status.label}',
      excludeSemantics: true,
      child: Material(
        color: selected ? p.nested : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected ? BorderSide(color: primary, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                ClientAvatar(client: client, size: 44),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall!.copyWith(color: p.text),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              status.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall!.copyWith(fontWeight: FontWeight.w600, color: status.color),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: p.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
