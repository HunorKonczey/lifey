import '../../clients/domain/trainer_client.dart' show parseTrainerTimestamp;

/// An invite this trainer has sent and nobody has answered yet
/// (`TrainerInviteResponse`).
class SentInvite {
  const SentInvite({
    required this.id,
    required this.clientEmail,
    required this.createdAt,
    required this.expiresAt,
  });

  final int id;
  final String clientEmail;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// How long the invitee still has. Zero once it has run out — the backend
  /// stops listing expired invites, but a list can be a few seconds stale and
  /// a negative countdown reads as a bug.
  Duration remaining({DateTime? now}) {
    final left = expiresAt.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  factory SentInvite.fromJson(Map<String, dynamic> json) {
    return SentInvite(
      id: (json['id'] as num).toInt(),
      clientEmail: json['clientEmail'] as String? ?? '',
      createdAt: parseTrainerTimestamp(json['createdAt'] as String),
      expiresAt: parseTrainerTimestamp(json['expiresAt'] as String),
    );
  }
}
