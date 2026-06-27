import { api } from "@/lib/api/client";
import type { DailyStepCountResponse, DailyStepCountRequest } from "./types";

export const stepsApi = {
  list: () => api.get<DailyStepCountResponse[]>("/steps"),
  create: (body: DailyStepCountRequest) => api.post<DailyStepCountResponse>("/steps", body),
  update: (id: number, body: DailyStepCountRequest) => api.put<DailyStepCountResponse>(`/steps/${id}`, body),
  delete: (id: number) => api.delete(`/steps/${id}`),
};
