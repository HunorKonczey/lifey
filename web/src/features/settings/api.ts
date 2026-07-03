import { api, ApiError } from "@/lib/api/client";
import type { SettingsResponse, SettingsRequest } from "./types";

export const settingsApi = {
  get: () => api.get<SettingsResponse>("/settings"),
  update: (body: SettingsRequest) => api.put<SettingsResponse>("/settings", body),
};

export const avatarApi = {
  /** Returns null (not an error) when the user has no profile picture set. */
  get: async (): Promise<Blob | null> => {
    try {
      return await api.getBlob("/users/me/avatar");
    } catch (e) {
      if (e instanceof ApiError && e.status === 404) return null;
      throw e;
    }
  },
  upload: (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    return api.putForm("/users/me/avatar", formData);
  },
  remove: () => api.delete("/users/me/avatar"),
};
