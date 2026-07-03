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
