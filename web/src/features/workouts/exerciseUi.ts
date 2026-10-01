import type { ExerciseResponse } from "./types";

/** The metric colour a muscle group wears on its icon tile and chip. */
export function muscleGroupColor(category: string | null): string {
  switch (category) {
    case "CHEST":
    case "QUADS":
      return "var(--m-kcal)";
    case "SHOULDERS":
    case "GLUTES":
      return "var(--m-carbs)";
    case "TRICEPS":
    case "FOREARMS":
    case "ABS":
      return "var(--m-fat)";
    case "BACK":
      return "var(--m-water)";
    case "BICEPS":
      return "var(--m-protein)";
    case "HAMSTRINGS":
    case "CALVES":
      return "var(--m-steps)";
    default:
      return "var(--m-weight)";
  }
}

export function exerciseIcon(e: Pick<ExerciseResponse, "category" | "equipment">): string {
  if (e.category === "CARDIO") return "directions_run";
  if (e.equipment === "BODYWEIGHT") return "sports_gymnastics";
  return "fitness_center";
}

/** "2:00" — a rest time in whole seconds as minutes and seconds; null when the exercise has none of its own. */
export function formatRest(seconds: number | null | undefined): string | null {
  if (seconds == null) return null;
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}
