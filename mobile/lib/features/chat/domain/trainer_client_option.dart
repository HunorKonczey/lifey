/// One of the trainer's active clients, as offered by the "new conversation"
/// picker. Read-only and online-only — this is a chooser, not a cached list.
class TrainerClientOption {
  const TrainerClientOption({
    required this.userId,
    required this.email,
    this.firstName,
    this.lastName,
  });

  final int userId;
  final String email;
  final String? firstName;
  final String? lastName;

  String get displayName {
    final name = [firstName, lastName]
        .where((part) => part != null && part.isNotEmpty)
        .join(' ');
    return name.isNotEmpty ? name : email;
  }

  String get monogram {
    final words =
        displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  factory TrainerClientOption.fromJson(Map<String, dynamic> json) {
    return TrainerClientOption(
      userId: json['clientId'] as int,
      email: json['clientEmail'] as String,
      firstName: json['clientFirstName'] as String?,
      lastName: json['clientLastName'] as String?,
    );
  }
}
