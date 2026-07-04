import { api, type Page } from "@/lib/api/client";
import type { StatisticsResponse } from "@/features/statistics/types";
import type { DailyStepCountResponse } from "@/features/steps/types";
import type { WeightResponse } from "@/features/weight/types";
import type { WorkoutSessionResponse } from "@/features/workouts/types";
import type {
  AssignmentListItemResponse,
  AssignmentRequest,
  AssignmentResponse,
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
};
