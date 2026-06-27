import { api } from "@/lib/api/client";
import type {
  ExerciseResponse, ExerciseRequest,
  WorkoutTemplateResponse, WorkoutTemplateRequest,
  WorkoutSessionResponse, WorkoutSessionRequest,
} from "./types";

export const exerciseApi = {
  list: () => api.get<ExerciseResponse[]>("/exercises"),
  create: (body: ExerciseRequest) => api.post<ExerciseResponse>("/exercises", body),
  update: (id: number, body: ExerciseRequest) => api.put<ExerciseResponse>(`/exercises/${id}`, body),
  delete: (id: number) => api.delete(`/exercises/${id}`),
};

export const templateApi = {
  list: () => api.get<WorkoutTemplateResponse[]>("/workout-templates"),
  get: (id: number) => api.get<WorkoutTemplateResponse>(`/workout-templates/${id}`),
  create: (body: WorkoutTemplateRequest) => api.post<WorkoutTemplateResponse>("/workout-templates", body),
  update: (id: number, body: WorkoutTemplateRequest) => api.put<WorkoutTemplateResponse>(`/workout-templates/${id}`, body),
  delete: (id: number) => api.delete(`/workout-templates/${id}`),
};

export const workoutSessionApi = {
  list: () => api.get<WorkoutSessionResponse[]>("/workout-sessions"),
  create: (body: WorkoutSessionRequest) => api.post<WorkoutSessionResponse>("/workout-sessions", body),
  update: (id: number, body: WorkoutSessionRequest) => api.put<WorkoutSessionResponse>(`/workout-sessions/${id}`, body),
  delete: (id: number) => api.delete(`/workout-sessions/${id}`),
};
