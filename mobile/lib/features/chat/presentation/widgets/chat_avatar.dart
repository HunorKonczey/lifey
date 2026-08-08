import 'package:flutter/material.dart';

/// Monogram avatar, the pattern already used for trainer/client rows
/// elsewhere. Deliberately not a photo: the backend only serves the caller's
/// own picture, so there is nothing to load for a peer
/// (docs/chat/40-trainer-chat-plan.md §11/5).
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.monogram, this.size = 44});

  final String monogram;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        monogram,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
