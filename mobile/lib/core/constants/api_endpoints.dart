/// Centralized REST API endpoint paths.
class ApiEndpoints {
  const ApiEndpoints._();

  static const foods = '/foods';
  static String foodByBarcode(String barcode) => '/foods/barcode/$barcode';
  static const recipes = '/recipes';
  static const meals = '/meals';
  static const workoutTemplates = '/workout-templates';
  static const workoutSessions = '/workout-sessions';
  static const weights = '/weights';
  static const statistics = '/statistics';
  static const trainerInvitesPending = '/trainer-invites/pending';
  static String trainerInviteRespond(int id) => '/trainer-invites/$id/respond';
  static const myTrainers = '/my-trainers';
  static String myTrainer(int trainerId) => '/my-trainers/$trainerId';

  /// The trainer's own client list — used by the chat "new conversation"
  /// picker. Requires ROLE_TRAINER, unlike everything under `/chat`.
  static const trainerClients = '/trainer/clients';

  // Chat (docs/chat/40-trainer-chat-plan.md §4). Under `/chat`, not
  // `/trainer`, because both sides of a conversation call these.
  static const chatConversations = '/chat/conversations';
  static String chatConversationWithUser(int userId) => '/chat/conversations/with-user/$userId';
  static String chatMessages(int conversationId) => '/chat/conversations/$conversationId/messages';
  static String chatConversationRead(int conversationId) => '/chat/conversations/$conversationId/read';
  static String chatMessageSearch(int conversationId) =>
      '/chat/conversations/$conversationId/messages/search';
  static String chatMessage(int messageId) => '/chat/messages/$messageId';
  static String chatAttachment(int messageId) => '/chat/messages/$messageId/attachment';
  static String chatAttachmentThumbnail(int messageId) =>
      '/chat/messages/$messageId/attachment/thumbnail';
  static String chatConversationMute(int conversationId) =>
      '/chat/conversations/$conversationId/mute';

  /// Long-lived `text/event-stream` carrying every thread's events (I4).
  static const chatStream = '/chat/stream';

  /// "I'm looking at this thread" — what decides whether a push is needed.
  static const chatPresence = '/chat/presence';

  /// "I'm writing here" — fire and forget, throttled on both sides (I6).
  static const chatTyping = '/chat/typing';
}
