/// A pending trainer invite as seen by the invited client (mobile floating
/// card) — `GET /trainer-invites/pending`. Not a local-db entity, never
/// synced or persisted: the source of truth is the backend's `trainer_clients`
/// row, and this is just a transient read of it.
class TrainerInvite {
  const TrainerInvite({
    required this.id,
    required this.trainerEmail,
    required this.invitedAt,
    required this.expiresAt,
  });

  final int id;
  final String trainerEmail;
  final DateTime invitedAt;
  final DateTime expiresAt;

  factory TrainerInvite.fromJson(Map<String, dynamic> json) {
    return TrainerInvite(
      id: json['id'] as int,
      trainerEmail: json['trainerEmail'] as String,
      invitedAt: DateTime.parse(json['invitedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
