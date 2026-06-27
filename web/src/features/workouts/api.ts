import { api } from "@/lib/api/client";
import type { WorkoutSessionResponse } from "./types";

export const workoutSessionApi = {
  list: () => api.get<WorkoutSessionResponse[]>("/workout-sessions"),
};
