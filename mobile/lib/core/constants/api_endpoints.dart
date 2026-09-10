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

  /// `docs/landing_page/64-billing-backend-plan.md` §3.1.
  static const entitlements = '/me/entitlements';

  /// `docs/landing_page/64-billing-backend-plan.md` §6.1.
  static const storePurchase = '/billing/store-purchase';

  /// The trainer's own client list — the trainer view's entry point, and the
  /// chat "new conversation" picker. Requires ROLE_TRAINER, unlike everything
  /// under `/chat`.
  static const trainerClients = '/trainer/clients';

  // One client's data, read-only, for the client detail screen
  // (docs/chat/41-trainer-mobile-v2-plan.md T2). Every one of these is
  // guarded server-side by an active trainer-client relationship.
  static String trainerClientStatistics(int clientId, String period) =>
      '/trainer/clients/$clientId/statistics/$period';
  static String trainerClientSteps(int clientId) => '/trainer/clients/$clientId/steps';
  static String trainerClientWeights(int clientId) => '/trainer/clients/$clientId/weights';
  static String trainerClientMeals(int clientId) => '/trainer/clients/$clientId/meals';
  static String trainerClientNutritionGoals(int clientId) =>
      '/trainer/clients/$clientId/nutrition-goals';
  static String trainerClientWorkoutSessions(int clientId) =>
      '/trainer/clients/$clientId/workout-sessions';

  /// The trainer's one editable comment on a client's session — PUT upserts
  /// it, DELETE clears it (docs/31-session-feedback-loop-plan.md B2).
  static String trainerClientSessionComment(int clientId, int sessionId) =>
      '/trainer/clients/$clientId/workout-sessions/$sessionId/comment';

  // Content assignments (docs/35-bulk-assignment-plan.md). POST takes a list
  // of client ids and is one all-or-nothing transaction.
  static const trainerAssignments = '/trainer/assignments';
  static String trainerClientAssignments(int clientId) =>
      '/trainer/clients/$clientId/assignments';
  static String trainerAssignment(int assignmentId) =>
      '/trainer/assignments/$assignmentId';

  /// Which clients already hold a given template/recipe — lets the picker
  /// lock those rows instead of letting the trainer assign a duplicate.
  static const trainerAssignmentClients = '/trainer/assignments/clients';

  // Scheduling (docs/personal_trainer/09..12). Creating a schedule
  // materializes every occurrence at once; the calendar reads them back by
  // date range, capped server-side at 62 days.
  static const trainerSchedules = '/trainer/schedules';
  static String trainerSchedule(int scheduleId) => '/trainer/schedules/$scheduleId';
  static String trainerClientSchedules(int clientId) =>
      '/trainer/clients/$clientId/schedules';
  static String trainerClientScheduledSessions(int clientId) =>
      '/trainer/clients/$clientId/scheduled-sessions';

  /// Every active client's occurrences in a range — the trainer calendar.
  static const trainerScheduledSessions = '/trainer/scheduled-sessions';
  static String trainerScheduledSession(int sessionId) =>
      '/trainer/scheduled-sessions/$sessionId';

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
