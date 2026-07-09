import { api, ApiError, type Page } from "@/lib/api/client";
import type {
  FoodResponse, FoodRequest, BarcodeLookupResponse,
  MealResponse, MealRequest,
  RecipeResponse, RecipeRequest,
} from "./types";

export interface FoodPageParams {
  page: number;
  size?: number;
  search?: string;
  sort?: string;
}

export const foodApi = {
  list: () => api.get<FoodResponse[]>("/foods"),
  page: ({ page, size, search, sort }: FoodPageParams) => {
    const params = new URLSearchParams({ page: String(page) });
    if (size != null) params.set("size", String(size));
    if (search) params.set("search", search);
    if (sort) params.set("sort", sort);
    return api.get<Page<FoodResponse>>(`/foods?${params.toString()}`);
  },
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

export interface RecipePageParams {
  page: number;
  size?: number;
  search?: string;
}

export const recipeApi = {
  list: () => api.get<RecipeResponse[]>("/recipes"),
  page: ({ page, size, search }: RecipePageParams) => {
    const params = new URLSearchParams({ page: String(page) });
    if (size != null) params.set("size", String(size));
    if (search) params.set("search", search);
    return api.get<Page<RecipeResponse>>(`/recipes?${params.toString()}`);
  },
  get: (id: number) => api.get<RecipeResponse>(`/recipes/${id}`),
  create: (body: RecipeRequest) => api.post<RecipeResponse>("/recipes", body),
  update: (id: number, body: RecipeRequest) => api.put<RecipeResponse>(`/recipes/${id}`, body),
  delete: (id: number) => api.delete(`/recipes/${id}`),
};

export const recipeImageApi = {
  /** Returns null (not an error) when the recipe has no photo set. */
  get: async (id: number): Promise<Blob | null> => {
    try {
      return await api.getBlob(`/recipes/${id}/image/thumbnail`);
    } catch (e) {
      if (e instanceof ApiError && e.status === 404) return null;
      throw e;
    }
  },
  upload: (id: number, file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    return api.putForm(`/recipes/${id}/image`, formData);
  },
  remove: (id: number) => api.delete(`/recipes/${id}/image`),
};
