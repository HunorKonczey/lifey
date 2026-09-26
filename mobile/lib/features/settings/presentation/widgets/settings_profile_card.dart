import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/monogram_avatar.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';

/// The profile card at the top of Settings: the monogram — built from the
/// **name** ("AK"), not the first letter of the e-mail — or the picture, the
/// name, the e-mail and, for a Pro account, the gold "Pro" chip. Tapping it
/// opens the photo actions; the camera badge on the avatar says so.
class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({
    super.key,
    required this.name,
    required this.email,
    required this.avatarBytes,
    required this.busy,
    required this.isPro,
    required this.onTap,
  });

  final String name;
  final String? email;
  final Uint8List? avatarBytes;
  final bool busy;
  final bool isPro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final hasName = name.isNotEmpty;

    return LifeyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.s16),
      semanticsLabel: '${hasName ? '$name, ' : ''}${email ?? ''}. ${l10n.changePhotoLabel}',
      child: Row(
        children: [
          _Avatar(name: name, email: email, bytes: avatarBytes, busy: busy),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasName)
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleLarge!.copyWith(fontWeight: FontWeight.w800, color: p.text)),
                Text(
                  email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (hasName ? t.bodyMedium! : t.titleLarge!.copyWith(fontWeight: FontWeight.w800)).copyWith(
                    color: hasName ? p.text2 : p.text,
                  ),
                ),
              ],
            ),
          ),
          if (isPro) ...[
            const SizedBox(width: AppSpacing.s8),
            TintedChip(label: l10n.settingsProChip, color: context.metricColors.record),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.email, required this.bytes, required this.busy});

  final String name;
  final String? email;
  final Uint8List? bytes;
  final bool busy;

  static const double _size = 60;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          MonogramAvatar(
            name: name,
            email: email,
            size: _size,
            image: bytes == null ? null : MemoryImage(bytes!),
          ),
          if (busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: p.bg.withValues(alpha: 0.6), shape: BoxShape.circle),
                child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: p.card, width: 2),
              ),
              child: Icon(Icons.camera_alt_rounded, size: 12, color: scheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
