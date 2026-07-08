import { api, ApiError, type Page } from "@/lib/api/client";
import type { StatisticsResponse } from "@/features/statistics/types";
import type { DailyStepCountResponse } from "@/features/steps/types";
import type { WeightResponse } from "@/features/weight/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";
import type { MealResponse } from "@/features/nutrition/types";
import type {
  AssignmentListItemResponse,
  AssignmentRequest,
  AssignmentResponse,
  ClientNutritionGoalsResponse,
  ContentType,
  ScheduleRequest,
  ScheduleResponse,
  ScheduleSummaryResponse,
  ScheduledSessionResponse,
  TrainerCalendarSessionResponse,
  TrainerClientResponse,
  TrainerInviteRequest,
  TrainerInviteResponse,
} from "./types";

export const trainerApi = {
  invite: (body: TrainerInviteRequest) =>
    api.post<TrainerInviteResponse>("/trainer/invites", body),
  pendingInvites: () => api.get<TrainerInviteResponse[]>("/trainer/invites"),
  cancelInvite: (id: number) => api.delete(`/trainer/invites/${id}`),

  clients: () => api.get<TrainerClientResponse[]>("/trainer/clients"),
  revokeClient: (clientId: number) => api.delete(`/trainer/clients/${clientId}`),

  assign: (body: AssignmentRequest) =>
    api.post<AssignmentResponse>("/trainer/assignments", body),
  assignmentsForClient: (clientId: number) =>
    api.get<AssignmentListItemResponse[]>(`/trainer/clients/${clientId}/assignments`),
  assignedClientIds: (contentType: ContentType, sourceId: number) =>
    api.get<number[]>(`/trainer/assignments/clients?contentType=${contentType}&sourceId=${sourceId}`),
  unassign: (assignmentId: number) => api.delete(`/trainer/assignments/${assignmentId}`),

  clientStatistics: (clientId: number, period: "daily" | "weekly" | "monthly") =>
    api.get<StatisticsResponse>(`/trainer/clients/${clientId}/statistics/${period}`),
  clientSteps: (clientId: number, from?: string, to?: string) => {
    const params = new URLSearchParams();
    if (from) params.set("from", from);
    if (to) params.set("to", to);
    const qs = params.toString();
    return api.get<DailyStepCountResponse[]>(`/trainer/clients/${clientId}/steps${qs ? `?${qs}` : ""}`);
  },
  clientWeights: (clientId: number, from?: string, to?: string) => {
    const params = new URLSearchParams();
    if (from) params.set("from", from);
    if (to) params.set("to", to);
    const qs = params.toString();
    return api.get<WeightResponse[]>(`/trainer/clients/${clientId}/weights${qs ? `?${qs}` : ""}`);
  },
  clientWorkoutSessions: (clientId: number, page: number, size = 20) =>
    api.get<Page<WorkoutSessionResponse>>(
      `/trainer/clients/${clientId}/workout-sessions?page=${page}&size=${size}`,
    ),
  clientMeals: (clientId: number, from?: string, to?: string) => {
    const params = new URLSearchParams();
    if (from) params.set("from", from);
    if (to) params.set("to", to);
    const qs = params.toString();
    return api.get<MealResponse[]>(`/trainer/clients/${clientId}/meals${qs ? `?${qs}` : ""}`);
  },
  clientNutritionGoals: (clientId: number) =>
    api.get<ClientNutritionGoalsResponse>(`/trainer/clients/${clientId}/nutrition-goals`),
  /** Returns null (not an error) when the client has no profile picture set. */
  clientAvatar: async (clientId: number): Promise<Blob | null> => {
    try {
      return await api.getBlob(`/trainer/clients/${clientId}/avatar`);
    } catch (e) {
      if (e instanceof ApiError && e.status === 404) return null;
      throw e;
    }
  },

  createSchedule: (body: ScheduleRequest) => api.post<ScheduleResponse>("/trainer/schedules", body),
  schedulesForClient: (clientId: number) =>
    api.get<ScheduleSummaryResponse[]>(`/trainer/clients/${clientId}/schedules`),
  scheduledSessions: (clientId: number, from: string, to: string) =>
    api.get<ScheduledSessionResponse[]>(
      `/trainer/clients/${clientId}/scheduled-sessions?from=${from}&to=${to}`,
    ),
  cancelSchedule: (scheduleId: number) => api.delete(`/trainer/schedules/${scheduleId}`),
  cancelOccurrence: (sessionId: number) => api.delete(`/trainer/scheduled-sessions/${sessionId}`),
  calendarSessions: (from: string, to: string) =>
    api.get<TrainerCalendarSessionResponse[]>(`/trainer/scheduled-sessions?from=${from}&to=${to}`),
};
