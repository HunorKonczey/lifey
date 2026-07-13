export const queryKeys = {
  auth: {
    session: () => ["auth", "session"] as const,
  },
  settings: {
    all: () => ["settings"] as const,
    avatar: () => ["settings", "avatar"] as const,
  },
  userDetails: {
    all: () => ["user-details"] as const,
  },
  statistics: {
    daily: (date: string) => ["statistics", "daily", date] as const,
    weekly: (date: string) => ["statistics", "weekly", date] as const,
    monthly: (date: string) => ["statistics", "monthly", date] as const,
  },
  foods: {
    all: () => ["foods"] as const,
    page: (params: { page: number; size?: number; search?: string; sort?: string }) =>
      ["foods", "page", params] as const,
    barcode: (barcode: string) => ["foods", "barcode", barcode] as const,
    detail: (id: number) => ["foods", id] as const,
  },
  meals: {
    all: () => ["meals"] as const,
    byDate: (date: string) => ["meals", "date", date] as const,
    detail: (id: number) => ["meals", id] as const,
  },
  recipes: {
    all: () => ["recipes"] as const,
    page: (params: { page: number; size?: number; search?: string }) =>
      ["recipes", "page", params] as const,
    detail: (id: number) => ["recipes", id] as const,
    image: (id: number) => ["recipes", id, "image"] as const,
  },
  exercises: {
    all: () => ["exercises"] as const,
    detail: (id: number) => ["exercises", id] as const,
  },
  workoutTemplates: {
    all: () => ["workout-templates"] as const,
    detail: (id: number) => ["workout-templates", id] as const,
  },
  workoutSessions: {
    all: () => ["workout-sessions"] as const,
    detail: (id: number) => ["workout-sessions", id] as const,
  },
  weights: {
    all: () => ["weights"] as const,
    detail: (id: number) => ["weights", id] as const,
  },
  waterEntries: {
    all: () => ["water-entries"] as const,
    byDate: (date: string) => ["water-entries", "date", date] as const,
  },
  waterSources: {
    all: () => ["water-sources"] as const,
  },
  steps: {
    all: () => ["steps"] as const,
    byDate: (date: string) => ["steps", "date", date] as const,
  },
  trainerClients: {
    all: () => ["trainer-clients"] as const,
  },
  trainerInvites: {
    all: () => ["trainer-invites"] as const,
  },
  trainerAssignments: {
    forClient: (clientId: number) => ["trainer-assignments", "client", clientId] as const,
    assignedClients: (contentType: string, sourceId: number) =>
      ["trainer-assignments", "assigned-clients", contentType, sourceId] as const,
  },
  trainerClientData: {
    statistics: (clientId: number, period: "daily" | "weekly" | "monthly") =>
      ["trainer-client-data", clientId, "statistics", period] as const,
    steps: (clientId: number) => ["trainer-client-data", clientId, "steps"] as const,
    weights: (clientId: number) => ["trainer-client-data", clientId, "weights"] as const,
    sessions: (clientId: number, page: number, size: number) =>
      ["trainer-client-data", clientId, "sessions", page, size] as const,
    avatar: (clientId: number) => ["trainer-client-data", clientId, "avatar"] as const,
    meals: (clientId: number, date: string) => ["trainer-client-data", clientId, "meals", date] as const,
    nutritionGoals: (clientId: number) => ["trainer-client-data", clientId, "nutrition-goals"] as const,
  },
  trainerSchedules: {
    forClient: (clientId: number) => ["trainer-schedules", "client", clientId] as const,
    occurrences: (clientId: number, from: string, to: string) =>
      ["trainer-schedules", "client", clientId, "occurrences", from, to] as const,
  },
  trainerCalendar: {
    range: (from: string, to: string) => ["trainer-calendar", from, to] as const,
  },
  trainerPreferences: {
    all: () => ["trainer-preferences"] as const,
  },
  superAdminUsers: {
    page: (params: { page: number; size?: number; search?: string }) =>
      ["superadmin-users", "page", params] as const,
    roleAudit: (userId: number) => ["superadmin-users", userId, "role-audit"] as const,
    avatar: (userId: number) => ["superadmin-users", userId, "avatar"] as const,
  },
} as const;

/**
 * Invalidation map — after each mutation, invalidate these keys.
 * Keys reference queryKeys entries above.
 */
export const invalidationMap = {
  meal: [queryKeys.meals.all(), queryKeys.statistics.daily],
  food: [queryKeys.foods.all()],
  recipe: [queryKeys.recipes.all()],
  exercise: [queryKeys.exercises.all()],
  workoutTemplate: [queryKeys.workoutTemplates.all()],
  workoutSession: [queryKeys.workoutSessions.all()],
  weight: [queryKeys.weights.all()],
  waterEntry: [queryKeys.waterEntries.all(), queryKeys.waterSources.all()],
  waterSource: [queryKeys.waterSources.all()],
  steps: [queryKeys.steps.all()],
  settings: [queryKeys.settings.all()],
  userDetails: [queryKeys.userDetails.all()],
} as const;
