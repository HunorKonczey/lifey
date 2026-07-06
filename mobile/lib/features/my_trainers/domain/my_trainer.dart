/// An active trainer relationship as seen by the client — `GET /my-trainers`
/// (Settings §"Edzőim", docs/personal_trainer/05-mobil-terv.md §3). Not a
/// local-db entity: this is a transient, online-only read.
class MyTrainer {
  const MyTrainer({
    required this.trainerId,
    required this.trainerEmail,
    required this.activeSince,
  });

  final int trainerId;
  final String trainerEmail;
  final DateTime activeSince;

  factory MyTrainer.fromJson(Map<String, dynamic> json) {
    return MyTrainer(
      trainerId: json['trainerId'] as int,
      trainerEmail: json['trainerEmail'] as String,
      activeSince: DateTime.parse(json['activeSince'] as String),
    );
  }
}
