import { describe, it, expect } from "vitest";
import { weatherConditionIcon, weatherConditionLabelKey } from "./weatherCondition";

describe("weatherConditionIcon", () => {
  it("maps each known code to its icon", () => {
    expect(weatherConditionIcon("CLEAR")).toBe("wb_sunny");
    expect(weatherConditionIcon("RAIN")).toBe("water_drop");
    expect(weatherConditionIcon("SNOW")).toBe("ac_unit");
  });

  it("falls back to cloud_off for null or an unrecognized code", () => {
    expect(weatherConditionIcon(null)).toBe("cloud_off");
    expect(weatherConditionIcon("HAIL")).toBe("cloud_off");
  });
});

describe("weatherConditionLabelKey", () => {
  it("returns the i18n key for a known code", () => {
    expect(weatherConditionLabelKey("CLOUDY")).toBe("cardioWeatherConditionCloudy");
  });

  it("returns null for an unrecognized code, so the caller can fall back to the raw string", () => {
    expect(weatherConditionLabelKey("HAIL")).toBeNull();
  });
});
