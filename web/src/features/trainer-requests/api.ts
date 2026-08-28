import { api, type Page } from "@/lib/api/client";
import type {
  SuperAdminTrainerRequestResponse,
  TrainerRequestRequest,
  TrainerRequestResponse,
} from "./types";

export const trainerRequestApi = {
  create: (body: TrainerRequestRequest) =>
    api.post<TrainerRequestResponse>("/trainer-requests", body),
  /** 404 (ApiError) if the user has never submitted one. */
  me: () => api.get<TrainerRequestResponse>("/trainer-requests/me"),

  // Superadmin queue (66 Prompt 3).
  pending: (params: { page: number; size?: number }) => {
    const query = new URLSearchParams({
      page: String(params.page),
      size: String(params.size ?? 20),
    });
    return api.get<Page<SuperAdminTrainerRequestResponse>>(`/superadmin/trainer-requests?${query}`);
  },
  approve: (id: number) => api.post<void>(`/superadmin/trainer-requests/${id}/approve`),
  reject: (id: number) => api.post<void>(`/superadmin/trainer-requests/${id}/reject`),
};
