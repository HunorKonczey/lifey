/// An active trainer relationship as seen by the client — `GET /my-trainers`
/// (Settings §"Edzőim", docs/personal_trainer/05-mobil-terv.md §3). Not a
/// local-db entity: this is a transient, online-only read.
class MyTrainer {
  const MyTrainer({
    required this.trainerId,
    required this.trainerEmail,
    this.trainerFirstName,
    this.trainerLastName,
    required this.activeSince,
  });

  final int trainerId;
  final String trainerEmail;
  final String? trainerFirstName;
  final String? trainerLastName;
  final DateTime activeSince;

  /// Display name built from first/last name, falling back to the email
  /// when neither is set (e.g. a Google account with no family name).
  String get displayName {
    final name = [trainerFirstName, trainerLastName]
        .where((part) => part != null && part.isNotEmpty)
        .join(' ');
    return name.isNotEmpty ? name : trainerEmail;
  }

  factory MyTrainer.fromJson(Map<String, dynamic> json) {
    return MyTrainer(
      trainerId: json['trainerId'] as int,
      trainerEmail: json['trainerEmail'] as String,
      trainerFirstName: json['trainerFirstName'] as String?,
      trainerLastName: json['trainerLastName'] as String?,
      activeSince: DateTime.parse(json['activeSince'] as String),
    );
  }
}
