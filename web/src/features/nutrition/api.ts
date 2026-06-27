import { api } from "@/lib/api/client";
import type { MealResponse } from "./types";

export const mealApi = {
  list: () => api.get<MealResponse[]>("/meals"),
};
