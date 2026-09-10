import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/application/peer_avatar_controller.dart';
import '../clients/domain/trainer_client.dart';

/// A client's avatar: their photo where there is room for one, their initials
/// everywhere else.
///
/// The picture comes from `GET /users/{id}/avatar`, which a trainer may read
/// for anyone they are actively linked to — the same endpoint and the same
/// [peerAvatarProvider] the chat already uses, so this inherits its disk
/// cache, its ETag revalidation and its wipe on logout. (`/trainer/clients/
/// {id}/avatar` would serve the same bytes with none of that, which is why
/// this side does not call it.)
///
/// [showPhoto] is off by default, and that is a design choice rather than a
/// performance one: the client list is specified as monogram avatars (frame
/// B1), and monograms tell a roster of twenty people apart faster than twenty
/// small photographs do. It goes on where the screen is about one person.
class ClientAvatar extends ConsumerWidget {
  const ClientAvatar({
    super.key,
    required this.client,
    this.size = 44,
    this.showPhoto = false,
  });

  final TrainerClient client;
  final double size;
  final bool showPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    // Null covers every case the UI does not need to tell apart: no picture
    // set, no longer allowed to see it, or offline with nothing cached. All
    // of them draw the monogram.
    final photo = showPhoto
        ? ref.watch(peerAvatarProvider(client.userId)).value
        : null;

    // The initials stand in for a photo; the name itself is always next to
    // this, so announcing "A K" as well is just noise.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          shape: BoxShape.circle,
        ),
        child: photo == null
            ? Text(
                client.monogram,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w800,
                  color: scheme.onTertiaryContainer,
                ),
              )
            : Image.memory(
                photo,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
      ),
    );
  }
}
