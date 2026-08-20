import { activityFamilyOf } from "./activityType";
import { formatDistanceKm, formatDuration, formatPace, formatElevation, formatWeight } from "./cardioFormat";
import type { ActivityType, WorkoutSessionResponse } from "./types";

export interface CardioTile {
  label: string;
  value: string;
  icon: string;
}

/** Minimal shape of next-intl's translator — enough to call it, nothing UI-specific. */
type Translate = (key: string) => string;

/**
 * `cardio_details.game_format` is a free-text wire value (docs/cardio/60
 * §5 M45 doc-comment on the mobile `GameFormat` enum: "a future format needs
 * no migration"), so this is only the set the picker offers today — the same
 * four codes as mobile's `GameFormat`. An unrecognized code falls back to
 * showing the raw string rather than mislabeling it, unlike mobile's
 * `GameFormat.fromCode(...) ?? GameSetup.defaults.format`, which would
 * silently relabel an unknown code as "5v5".
 */
const GAME_FORMAT_LABEL_KEYS: Record<string, string> = {
  "5V5": "cardioGameFormatFiveVsFive",
  SMALL_SIDED: "cardioGameFormatSmallSided",
  PRACTICE: "cardioGameFormatPractice",
  MATCH: "cardioGameFormatMatch",
};

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
    // Peak altitude is DISTANCE-wide (Q-D6), not HIKING-only — any DISTANCE
    // session with local altitude data gets it, same gating as elevation gain.
    if (cardio?.maxAltitudeMeters != null) {
      tiles.push({ label: t("cardioMaxAltitudeLabel"), value: formatElevation(cardio.maxAltitudeMeters), icon: "landscape" });
    }
    if (activityType === "HIKING") {
      // Backpack weight is hike-only and manual-only (docs/cardio/60 §8
      // C8w.4) — always a tile once you're on a hike, "—" until it's set,
      // same presence rule as mobile's tappable version (this one just isn't
      // tappable, the web never edits cardio).
      tiles.push({
        label: t("cardioBackpackWeightLabel"),
        value: cardio?.backpackWeightKg != null ? formatWeight(cardio.backpackWeightKg) : "—",
        icon: "backpack",
      });
      // Grade-adjusted pace, unlike backpack weight, is presence-gated, not
      // always shown: it's a derived value with no manual-entry path, so a
      // "—" here would mean something different (nobody bothered to enter
      // it) than what's actually true (nothing produced it — see docs/cardio/60
      // §8 C8w.4's note on `avgGapSecondsPerKm` never being populated today).
      if (cardio?.avgGapSecondsPerKm != null) {
        const gap = formatPace(1000, cardio.avgGapSecondsPerKm);
        if (gap) tiles.push({ label: t("cardioGapLabel"), value: gap, icon: "trending_up" });
      }
    }
    return tiles;
  }

  if (family === "MACHINE") {
    // avgWatts and deviceCalories are deliberately not grid tiles here —
    // avgWatts only ever appears inside `TotalWorkCard` (docs/cardio/60 §8
    // C7w.2, mirroring mobile: the MACHINE grid never has its own watts
    // tile, only the hero card does), and deviceCalories moved to the
    // two-sided `CalorieCard`, which explains *why* it's never summed —
    // strictly more context than a bare "N kcal" tile gave.
    tiles.push({ label: t("cardioMovingTimeLabel"), value: durationValue, icon: "schedule" });
    tiles.push({ label: t("cardioDistanceLabel"), value: hasDistance ? formatDistanceKm(distanceM, locale) : "—", icon: "route" });
    if (cardio?.avgCadence != null) tiles.push({ label: t("cardioAvgCadenceLabel"), value: `${Math.round(cardio.avgCadence)} rpm`, icon: "autorenew" });
    if (cardio?.resistanceLevel != null) tiles.push({ label: t("cardioResistanceLabel"), value: `${cardio.resistanceLevel}`, icon: "tune" });
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
  if (cardio?.gameFormat != null) {
    const labelKey = GAME_FORMAT_LABEL_KEYS[cardio.gameFormat];
    tiles.push({
      label: t("cardioGameFormatLabel"),
      value: labelKey ? t(labelKey) : cardio.gameFormat,
      icon: "grid_view",
    });
  }
  if (cardio?.intensity != null) tiles.push({ label: t("cardioIntensityLabel"), value: `${cardio.intensity}/5`, icon: "whatshot" });
  if (cardio?.scorePoints != null) {
    tiles.push({
      label: activityType === "BASKETBALL" ? t("cardioBoxScorePointsLabel") : t("cardioBoxScoreGoalsLabel"),
      value: `${cardio.scorePoints}`,
      icon: "scoreboard",
    });
  }
  if (cardio?.scoreRebounds != null) {
    tiles.push({ label: t("cardioBoxScoreReboundsLabel"), value: `${cardio.scoreRebounds}`, icon: "replay" });
  }
  if (cardio?.scoreAssists != null) {
    tiles.push({ label: t("cardioBoxScoreAssistsLabel"), value: `${cardio.scoreAssists}`, icon: "handshake" });
  }
  return tiles;
}
