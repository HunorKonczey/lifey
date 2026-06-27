import { api } from "@/lib/api/client";
import type {
  FoodResponse, FoodRequest, BarcodeLookupResponse,
  MealResponse, MealRequest,
  RecipeResponse, RecipeRequest,
} from "./types";

export const foodApi = {
  list: () => api.get<FoodResponse[]>("/foods"),
  get: (id: number) => api.get<FoodResponse>(`/foods/${id}`),
  create: (body: FoodRequest) => api.post<FoodResponse>("/foods", body),
  update: (id: number, body: FoodRequest) => api.put<FoodResponse>(`/foods/${id}`, body),
  delete: (id: number) => api.delete(`/foods/${id}`),
  barcode: (barcode: string) =>
    api.get<BarcodeLookupResponse>(`/foods/barcode/${encodeURIComponent(barcode)}`),
};

export const mealApi = {
  list: () => api.get<MealResponse[]>("/meals"),
  create: (body: MealRequest) => api.post<MealResponse>("/meals", body),
  update: (id: number, body: MealRequest) => api.put<MealResponse>(`/meals/${id}`, body),
  delete: (id: number) => api.delete(`/meals/${id}`),
};

export const recipeApi = {
  list: () => api.get<RecipeResponse[]>("/recipes"),
  get: (id: number) => api.get<RecipeResponse>(`/recipes/${id}`),
  create: (body: RecipeRequest) => api.post<RecipeResponse>("/recipes", body),
  update: (id: number, body: RecipeRequest) => api.put<RecipeResponse>(`/recipes/${id}`, body),
  delete: (id: number) => api.delete(`/recipes/${id}`),
};
