import { api } from "@/lib/api/client";
import type { WeightResponse, WeightRequest } from "./types";

export const weightApi = {
  list: () => api.get<WeightResponse[]>("/weights"),
  create: (body: WeightRequest) => api.post<WeightResponse>("/weights", body),
  delete: (id: number) => api.delete(`/weights/${id}`),
};
