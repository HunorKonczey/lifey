export interface TrainerInviteResponse {
  id: number;
  clientEmail: string;
  createdAt: string;
  expiresAt: string;
}

export interface TrainerInviteRequest {
  email: string;
}

export interface WeightTrendPoint {
  date: string;
  weightKg: number;
}

export interface TrainerClientResponse {
  clientId: number;
  clientEmail: string;
  activeSince: string;
  weightTrend: WeightTrendPoint[];
  assignedPlanCount: number;
  workoutsPerWeek: number;
  /** Compliance overview (docs/29) — raw facts; thresholds/flags live in features/trainer/compliance.ts. */
  lastActivityAt: string | null;
  lastWeightAt: string | null;
  missedWorkoutCount: number;
}

export type ContentType = "TEMPLATE" | "RECIPE";

export interface AssignmentRequest {
  clientId: number;
  contentType: ContentType;
  sourceId: number;
}

export interface AssignmentResponse {
  id: number;
  contentType: ContentType;
  sourceId: number;
  copiedId: number;
  assignedAt: string;
  previouslyAssigned: boolean;
}

/** One row of "kiosztott tervek" for a given client — no source name/client
 *  email from the backend, the UI resolves those against the trainer's own
 *  content list and client list. */
export interface AssignmentListItemResponse {
  id: number;
  contentType: ContentType;
  sourceId: number;
  copiedId: number;
  assignedAt: string;
}

export interface ClientNutritionGoalsResponse {
  dailyCalorieGoal: number | null;
  dailyProteinGoal: number | null;
  dailyCarbsGoal: number | null;
  dailyFatGoal: number | null;
}

/** A missing/null field clears that goal — same shape as the response. */
export interface ClientNutritionGoalsRequest {
  dailyCalorieGoal: number | null;
  dailyProteinGoal: number | null;
  dailyCarbsGoal: number | null;
  dailyFatGoal: number | null;
}

// ─── Scheduled workouts (docs/personal_trainer/09-11) ───

export type Recurrence = "ONCE" | "DAILY" | "WEEKLY";

export const DAYS_OF_WEEK = [
  "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY",
] as const;
export type DayOfWeek = (typeof DAYS_OF_WEEK)[number];

export interface ScheduleRequest {
  clientId: number;
  templateId: number;
  recurrence: Recurrence;
  /* WEEKLY only. */
  daysOfWeek: DayOfWeek[];
  /* "HH:mm", optional. */
  timeOfDay?: string | null;
  startDate: string;
  /* Ignored by the backend for ONCE (startDate is used for both) but always required on the wire. */
  endDate: string;
}

export interface ScheduleResponse {
  id: number;
  clientId: number;
  templateId: number;
  templateName: string;
  recurrence: Recurrence;
  daysOfWeek: DayOfWeek[];
  timeOfDay: string | null;
  startDate: string;
  endDate: string;
  occurrencesCreated: number;
}

export interface ScheduleSummaryResponse {
  id: number;
  clientId: number;
  templateId: number;
  templateName: string;
  recurrence: Recurrence;
  daysOfWeek: DayOfWeek[];
  timeOfDay: string | null;
  startDate: string;
  endDate: string;
  doneCount: number;
  missedCount: number;
  remainingCount: number;
  cancelledAt: string | null;
}

export type OccurrenceStatus = "UPCOMING" | "DONE" | "MISSED" | "CANCELLED";

export interface ScheduledSessionResponse {
  sessionId: number;
  scheduledFor: string;
  scheduledTime: string | null;
  templateName: string | null;
  status: OccurrenceStatus;
  scheduleId: number;
}

/** Same as ScheduledSessionResponse but aggregated across every active client — backs the trainer calendar. */
export interface TrainerCalendarSessionResponse {
  sessionId: number;
  clientId: number;
  clientEmail: string;
  scheduledFor: string;
  scheduledTime: string | null;
  templateName: string | null;
  status: OccurrenceStatus;
  scheduleId: number;
}

/** The trainer's own preferences (docs/33) — not client data, separate from /settings. */
export interface TrainerPreferencesResponse {
  weeklyReportEmailEnabled: boolean;
}

export interface TrainerPreferencesRequest {
  weeklyReportEmailEnabled: boolean;
}
