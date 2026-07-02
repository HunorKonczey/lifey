import { z } from "zod";

// Mirrors the backend's BirthDateValidator (com.lifey.userdetails.dto.ValidBirthDate):
// must be a past date implying an age between 13 and 120.
function isValidBirthDate(value: string): boolean {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return false;
  const today = new Date();
  if (date >= today) return false;

  let age = today.getFullYear() - date.getFullYear();
  const monthDiff = today.getMonth() - date.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < date.getDate())) {
    age--;
  }
  return age >= 13 && age <= 120;
}

// Fields that map 1:1 onto UserDetailsRequest (backend com.lifey.userdetails.dto).
// Shared between the onboarding wizard and the Settings > Profile edit form —
// weight is deliberately excluded here since it isn't part of user_details
// (it's owned by the weight-entries feature; see the plan doc).
export const userDetailsFieldsSchema = z.object({
  gender: z.enum(["MALE", "FEMALE", "UNSPECIFIED"], { message: "required" }),
  birthDate: z.string().refine(isValidBirthDate, { message: "invalidBirthDate" }),
  // Plain z.number() (not z.coerce.number()) — inputs already convert to a
  // number themselves (RHF's valueAsNumber, or the imperial-unit converters
  // via setValue), and coerce here would make the resolver's input/output
  // types diverge in a way @hookform/resolvers can't reconcile against a
  // single useForm<T> type parameter.
  heightCm: z.number({ message: "required" })
    .min(80, { message: "heightRange" })
    .max(250, { message: "heightRange" }),
  activityLevel: z.enum(["SEDENTARY", "LIGHT", "MODERATE", "ACTIVE", "VERY_ACTIVE"], {
    message: "required",
  }),
  primaryGoal: z.enum(["LOSE_WEIGHT", "MAINTAIN", "GAIN_MUSCLE"], { message: "required" }),
  targetWeightKg: z.number()
    .min(30, { message: "weightRange" })
    .max(300, { message: "weightRange" })
    .optional(),
});

export type UserDetailsFormValues = z.infer<typeof userDetailsFieldsSchema>;

// Onboarding also collects the current weight, which seeds the first
// weight_entries row and feeds the suggest-goals calculation — it isn't
// persisted on user_details itself.
export const onboardingSchema = userDetailsFieldsSchema.extend({
  currentWeightKg: z.number({ message: "required" })
    .min(30, { message: "weightRange" })
    .max(300, { message: "weightRange" }),
});

export type OnboardingFormValues = z.infer<typeof onboardingSchema>;

// Fields validated (via RHF trigger()) before advancing off each wizard step.
export const STEP_FIELDS: Record<number, (keyof OnboardingFormValues)[]> = {
  1: ["gender", "birthDate"],
  2: ["heightCm", "currentWeightKg"],
  3: ["activityLevel", "primaryGoal", "targetWeightKg"],
};
