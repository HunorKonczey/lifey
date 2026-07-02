export type Gender = "MALE" | "FEMALE" | "UNSPECIFIED";
export type ActivityLevel = "SEDENTARY" | "LIGHT" | "MODERATE" | "ACTIVE" | "VERY_ACTIVE";
export type PrimaryGoal = "LOSE_WEIGHT" | "MAINTAIN" | "GAIN_MUSCLE";

export interface UserDetailsResponse {
  gender: Gender;
  birthDate: string; // yyyy-MM-dd
  heightCm: number;
  activityLevel: ActivityLevel;
  primaryGoal: PrimaryGoal;
  targetWeightKg: number | null;
  onboardingCompletedAt: string;
  updatedAt: string;
}

export interface UserDetailsRequest {
  gender: Gender;
  birthDate: string;
  heightCm: number;
  activityLevel: ActivityLevel;
  primaryGoal: PrimaryGoal;
  targetWeightKg?: number | null;
}

export interface SuggestGoalsRequest {
  gender: Gender;
  birthDate: string;
  heightCm: number;
  weightKg: number;
  activityLevel: ActivityLevel;
  primaryGoal: PrimaryGoal;
}

export interface SuggestGoalsResponse {
  bmr: number;
  tdee: number;
  calories: number;
  proteinGrams: number;
  carbsGrams: number;
  fatGrams: number;
  waterLiters: number;
}
