/**
 * The web port of the mobile `weather_condition.dart` — `cardio.weatherCondition`
 * is a free, unconstrained string on the wire (same precedent as `gameFormat`),
 * so an unrecognized code is never a parse error, just an icon/label this
 * client falls back on.
 */

const ICON_BY_CODE: Record<string, string> = {
  CLEAR: "wb_sunny",
  PARTLY_CLOUDY: "wb_cloudy",
  CLOUDY: "cloud",
  RAIN: "water_drop",
  SNOW: "ac_unit",
  WINDY: "air",
};

const LABEL_KEY_BY_CODE: Record<string, string> = {
  CLEAR: "cardioWeatherConditionClear",
  PARTLY_CLOUDY: "cardioWeatherConditionPartlyCloudy",
  CLOUDY: "cardioWeatherConditionCloudy",
  RAIN: "cardioWeatherConditionRain",
  SNOW: "cardioWeatherConditionSnow",
  WINDY: "cardioWeatherConditionWindy",
};

/** Material Symbols icon name — `cloud_off` for null/unrecognized, matching mobile's fallback. */
export function weatherConditionIcon(code: string | null): string {
  return (code && ICON_BY_CODE[code]) || "cloud_off";
}

/** The i18n key for a condition code, or `null` for an unrecognized one — the caller shows the raw code then. */
export function weatherConditionLabelKey(code: string): string | null {
  return LABEL_KEY_BY_CODE[code] ?? null;
}
