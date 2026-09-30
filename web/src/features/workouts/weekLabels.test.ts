import { describe, expect, it } from "vitest";
import { formatHoursMinutes, formatKg, formatKm, weekRangeLabel, weekSummaryParts } from "./weekLabels";

const nbsp = (s: string) => s.replace(/[  ]/g, " ");

describe("weekRangeLabel", () => {
  it("one month: the month once", () => {
    expect(weekRangeLabel(new Date(2026, 8, 21), new Date(2026, 8, 27), "hu")).toBe("szept. 21–27.");
    expect(weekRangeLabel(new Date(2026, 8, 21), new Date(2026, 8, 27), "en")).toBe("Sep 21–27");
  });

  it("across a month boundary: both ends spelled out", () => {
    expect(weekRangeLabel(new Date(2026, 8, 28), new Date(2026, 9, 4), "hu")).toBe("szept. 28. – okt. 4.");
    expect(weekRangeLabel(new Date(2026, 8, 28), new Date(2026, 9, 4), "en")).toBe("Sep 28 – Oct 4");
  });
});

describe("formatHoursMinutes", () => {
  it("hours and minutes, minutes only under an hour", () => {
    expect(formatHoursMinutes(3 * 3600 + 12 * 60, "hu")).toBe("3 ó 12 p");
    expect(formatHoursMinutes(3 * 3600 + 12 * 60, "en")).toBe("3h 12m");
    expect(formatHoursMinutes(52 * 60, "hu")).toBe("52 p");
    expect(formatHoursMinutes(52 * 60, "en")).toBe("52m");
  });
});

describe("numbers", () => {
  it("kg whole, km one decimal, with locale separators", () => {
    expect(nbsp(formatKg(19360, "hu"))).toBe("19 360 kg");
    expect(nbsp(formatKg(6240, "hu"))).toBe("6 240 kg"); // four digits too
    expect(formatKg(19360, "en")).toBe("19,360 kg");
    expect(formatKm(5200, "hu")).toBe("5,2 km");
    expect(formatKm(20000, "en")).toBe("20 km");
  });
});

describe("weekSummaryParts", () => {
  it("leaves out volume and distance when there is none", () => {
    expect(weekSummaryParts({ count: 2, seconds: 3600, volumeKg: 0, distanceMeters: 0 }, "en")).toEqual(["1h 0m"]);
    expect(weekSummaryParts({ count: 4, seconds: 11520, volumeKg: 500, distanceMeters: 20000 }, "en")).toEqual([
      "3h 12m",
      "500 kg",
      "20 km",
    ]);
    expect(weekSummaryParts({ count: 1, seconds: 0, volumeKg: 0, distanceMeters: 0 }, "en")).toEqual([]);
  });
});
