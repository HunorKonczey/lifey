import 'package:flutter/material.dart';

import '../clients/domain/trainer_client.dart';

/// Monogram avatar for a client row (frame B1).
///
/// Deliberately not a photo yet: the backend serves client pictures from
/// `GET /trainer/clients/{id}/avatar` as bytes, and loading N of those on the
/// list screen would undo the single-request client list. The detail screen
/// (T2) is where a real picture belongs.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({super.key, required this.client, this.size = 44});

  final TrainerClient client;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // The initials stand in for a photo; the name itself is always next to
    // this, so announcing "A K" as well is just noise.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          client.monogram,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: size * 0.36,
            fontWeight: FontWeight.w800,
            color: scheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}
