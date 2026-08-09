/// What the other side of a thread is *to the current user*. Not a global
/// role: a trainer who also has their own trainer sees both kinds in one
/// list, and this is what tells the rows apart
/// (docs/chat/40-trainer-chat-plan.md §6.1).
enum ChatPeerRole { trainer, client }

/// The other participant. Carries no avatar URL: the picture is fetched by
/// [userId] from the monolith's `/users/{id}/avatar`, which the chat service
/// has no access to, and the monogram built from [displayName] stays the
/// answer for everyone who never set one (see the plan's §11/5).
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
