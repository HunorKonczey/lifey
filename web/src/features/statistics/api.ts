import { api } from "@/lib/api/client";
import type { StatisticsResponse } from "./types";

export const statisticsApi = {
  daily: (date: string) =>
    api.get<StatisticsResponse>(`/statistics/daily?date=${date}`),
  weekly: (date: string) =>
    api.get<StatisticsResponse>(`/statistics/weekly?date=${date}`),
  monthly: (date: string) =>
    api.get<StatisticsResponse>(`/statistics/monthly?date=${date}`),
};
