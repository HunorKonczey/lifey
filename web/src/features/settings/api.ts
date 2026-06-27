import { api } from "@/lib/api/client";
import type { SettingsResponse, SettingsRequest } from "./types";

export const settingsApi = {
  get: () => api.get<SettingsResponse>("/settings"),
  update: (body: SettingsRequest) => api.put<SettingsResponse>("/settings", body),
};
