/// What the other side of a thread is *to the current user*. Not a global
/// role: a trainer who also has their own trainer sees both kinds in one
/// list, and this is what tells the rows apart
/// (docs/chat/40-trainer-chat-plan.md §6.1).
enum ChatPeerRole { trainer, client }

/// The other participant. There is no avatar URL — the backend only serves
/// the *caller's* own picture, so the design uses a monogram built from
/// [displayName] (see the plan's §11/5).
class ChatPeer {
  const ChatPeer({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
  });

  final int userId;
  final String displayName;
  final String email;
  final ChatPeerRole role;

  /// Up to two initials for the monogram avatar; falls back to the first
  /// character of the email for an account with no name filled in.
  String get monogram {
    final words =
        displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  factory ChatPeer.fromJson(Map<String, dynamic> json) {
    return ChatPeer(
      userId: json['userId'] as int,
      displayName: json['displayName'] as String,
      email: json['email'] as String? ?? '',
      role: (json['role'] as String) == 'TRAINER' ? ChatPeerRole.trainer : ChatPeerRole.client,
    );
  }
}
