import { api } from "@/lib/api/client";
import type { WaterEntryResponse, WaterEntryRequest, WaterSourceResponse, WaterSourceRequest } from "./types";

export const waterApi = {
  entries: {
    list: () => api.get<WaterEntryResponse[]>("/water-entries"),
    create: (body: WaterEntryRequest) => api.post<WaterEntryResponse>("/water-entries", body),
    delete: (id: number) => api.delete(`/water-entries/${id}`),
  },
  sources: {
    list: () => api.get<WaterSourceResponse[]>("/water-sources"),
    create: (body: WaterSourceRequest) => api.post<WaterSourceResponse>("/water-sources", body),
    update: (id: number, body: WaterSourceRequest) => api.put<WaterSourceResponse>(`/water-sources/${id}`, body),
    delete: (id: number) => api.delete(`/water-sources/${id}`),
  },
};
