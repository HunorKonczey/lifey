import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/peer_avatar_controller.dart';

/// The peer's profile picture, falling back to a monogram.
///
/// The monogram is not a placeholder to be replaced later — it stays the
/// answer for every account that never set a picture, and while the bytes are
/// still loading, so the row never changes size or flashes an empty circle.
///
/// [userId] is optional: entry points that only know a name (a not-yet-created
/// conversation, say) pass none and always get the monogram.
class ChatAvatar extends ConsumerWidget {
  const ChatAvatar({super.key, required this.monogram, this.userId, this.size = 44});

  final String monogram;
  final int? userId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final id = userId;
    final bytes = id == null ? null : ref.watch(peerAvatarProvider(id)).value;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: bytes == null
          ? Text(
              monogram,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
                letterSpacing: 0.2,
              ),
            )
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
    );
  }
}
