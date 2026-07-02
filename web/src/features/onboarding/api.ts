import { api } from "@/lib/api/client";
import type {
  SuggestGoalsRequest,
  SuggestGoalsResponse,
  UserDetailsRequest,
  UserDetailsResponse,
} from "./types";

export const userDetailsApi = {
  // 404 (via ApiError) means the user hasn't completed onboarding yet.
  get: () => api.get<UserDetailsResponse>("/user-details"),
  update: (body: UserDetailsRequest) => api.put<UserDetailsResponse>("/user-details", body),
  // Stateless — nothing is persisted, safe to call repeatedly while the wizard is open.
  suggestGoals: (body: SuggestGoalsRequest) =>
    api.post<SuggestGoalsResponse>("/user-details/suggest-goals", body),
};
