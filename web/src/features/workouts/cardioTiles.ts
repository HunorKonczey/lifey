import { activityFamilyOf } from "./activityType";
import { formatDistanceKm, formatDuration, formatPace } from "./cardioFormat";
import type { ActivityType, WorkoutSessionResponse } from "./types";

export interface CardioTile {
  label: string;
  value: string;
  icon: string;
}

/** Minimal shape of next-intl's translator — enough to call it, nothing UI-specific. */
type Translate = (key: string) => string;

/**
 * Builds the family-dependent metric tiles for a cardio session's read-only
 * detail view — a pure function so the branching (which fields appear, and
 * the "no distance source falls back to duration-only" rule) can be unit
 * tested without a component-testing setup, which this project doesn't have
 * (`vitest.config.ts` only runs `.test.ts`, not `.tsx`). Mirrors the mobile
 * `CardioSummaryScreen._metricSections` field selection exactly, so the same
 * session shows the same fields on both platforms.
 */
export function buildCardioTiles(
  session: WorkoutSessionResponse,
  t: Translate,
  locale: string,
): CardioTile[] {
  const activityType: ActivityType = session.activityType ?? "OTHER_CARDIO";
  const family = activityFamilyOf(activityType);
  const cardio = session.cardio;

  const grossSeconds = session.finishedAt
    ? (new Date(session.finishedAt).getTime() - new Date(session.startedAt).getTime()) / 1000
    : null;
  const effectiveSeconds = session.movingSeconds ?? grossSeconds;
  const durationValue = effectiveSeconds != null ? formatDuration(effectiveSeconds) : "—";
  const distanceM = cardio?.distanceMeters ?? null;
  const hasDistance = distanceM != null && distanceM > 0;

  const tiles: CardioTile[] = [];

  if (family === "DISTANCE") {
    if (hasDistance) {
      tiles.push({ label: t("cardioDistanceLabel"), value: formatDistanceKm(distanceM, locale), icon: "route" });
      if (effectiveSeconds != null) {
        tiles.push({ label: t("cardioDurationLabel"), value: durationValue, icon: "schedule" });
        const pace = formatPace(distanceM, effectiveSeconds);
        if (pace) tiles.push({ label: t("cardioPaceLabel"), value: pace, icon: "speed" });
      }
    } else {
      // No distance source (M11): fall back to duration only, never a
      // misleading "0.00 km".
      tiles.push({ label: t("cardioDurationLabel"), value: durationValue, icon: "schedule" });
    }
    if (cardio?.elevationGainMeters != null) {
      tiles.push({ label: t("cardioElevationGainLabel"), value: `${Math.round(cardio.elevationGainMeters)} m`, icon: "terrain" });
    }
    return tiles;
  }

  if (family === "MACHINE") {
    tiles.push({ label: t("cardioMovingTimeLabel"), value: durationValue, icon: "schedule" });
    tiles.push({ label: t("cardioDistanceLabel"), value: hasDistance ? formatDistanceKm(distanceM, locale) : "—", icon: "route" });
    if (cardio?.avgWatts != null) tiles.push({ label: t("cardioAvgWattsLabel"), value: `${Math.round(cardio.avgWatts)} W`, icon: "bolt" });
    if (cardio?.avgCadence != null) tiles.push({ label: t("cardioAvgCadenceLabel"), value: `${Math.round(cardio.avgCadence)} rpm`, icon: "autorenew" });
    if (cardio?.resistanceLevel != null) tiles.push({ label: t("cardioResistanceLabel"), value: `${cardio.resistanceLevel}`, icon: "tune" });
    if (cardio?.deviceCalories != null) {
      tiles.push({ label: t("cardioDeviceCaloriesLabel"), value: `${Math.round(cardio.deviceCalories)} kcal`, icon: "local_fire_department" });
    }
    return tiles;
  }

  // GAME
  tiles.push({ label: t("cardioPlayingTimeLabel"), value: durationValue, icon: "schedule" });
  if (cardio?.venue != null) {
    tiles.push({
      label: t("cardioVenueLabel"),
      value: cardio.venue === "INDOOR" ? t("cardioVenueIndoor") : t("cardioVenueOutdoor"),
      icon: "place",
    });
  }
  if (cardio?.intensity != null) tiles.push({ label: t("cardioIntensityLabel"), value: `${cardio.intensity}/5`, icon: "whatshot" });
  if (cardio?.scorePoints != null) tiles.push({ label: t("cardioScoreLabel"), value: `${cardio.scorePoints}`, icon: "scoreboard" });
  return tiles;
}
