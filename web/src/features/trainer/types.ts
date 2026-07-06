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
