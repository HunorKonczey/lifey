import { describe, expect, it } from "vitest";
import { createFormat } from "./lifeyFormat";

const en = createFormat("en");
const hu = createFormat("hu");

// Hungarian groups thousands with a no-break space (Intl's `hu` symbols),
// not a plain space — mirrors mobile's lifey_format_test.dart `nb()` helper.
const NBSP = " ";
const MINUS = "−";

describe("integer", () => {
  it("groups thousands per locale", () => {
    expect(en.integer(1739)).toBe("1,739");
    expect(hu.integer(1739)).toBe(`1${NBSP}739`);
  });

  it("rounds — the canvas example 17518.6 kcal", () => {
    expect(en.integer(17518.6, "kcal")).toBe("17,519 kcal");
    expect(hu.integer(17518.6, "kcal")).toBe(`17${NBSP}519 kcal`);
  });

  it("handles zero and negatives", () => {
    expect(en.integer(0)).toBe("0");
    expect(en.integer(-212)).toBe("-212");
    expect(hu.integer(621)).toBe("621");
  });
});

describe("weight", () => {
  it("always shows one decimal, with the locale separator", () => {
    expect(en.weight(64.5)).toBe("64.5 kg");
    expect(hu.weight(64.5)).toBe("64,5 kg");
    expect(en.weight(64)).toBe("64.0 kg");
  });

  it("rounds correctly through a carry — the canvas edge case 999.95", () => {
    expect(en.weight(999.95)).toBe("1,000.0 kg");
  });
});

describe("grams", () => {
  it("shows at most one decimal, the canvas example 166.68", () => {
    expect(en.grams(166.68)).toBe("166.7 g");
    expect(hu.grams(166.68)).toBe("166,7 g");
  });

  it("drops the decimal entirely for a whole number", () => {
    expect(en.grams(68)).toBe("68 g");
  });
});

describe("litres", () => {
  it("shows one decimal at least and up to two, with the unit or without", () => {
    expect(en.litres(0.25)).toBe("0.25 L");
    expect(hu.litres(0.25)).toBe("0,25 L");
    expect(hu.litres(0.5)).toBe("0,5 L");
    expect(hu.litres(2)).toBe("2,0 L");
    expect(hu.litreNumber(1.6)).toBe("1,6");
    expect(en.litreNumber(1.6)).toBe("1.6");
  });
});

describe("litresOfGoal", () => {
  it("joins current and goal with a trailing unit", () => {
    expect(en.litresOfGoal(1.6, 2.5)).toBe("1.6 / 2.5 L");
    expect(hu.litresOfGoal(1.6, 2.5)).toBe("1,6 / 2,5 L");
  });

  it("always shows at least one decimal", () => {
    expect(en.litresOfGoal(1, 2.5)).toBe("1.0 / 2.5 L");
  });
});

describe("signedDelta", () => {
  it("uses a real minus sign for losses, plus for gains", () => {
    expect(en.signedDelta(-0.4, { unit: "kg" })).toBe(`${MINUS}0.4 kg`);
    expect(hu.signedDelta(-0.4, { unit: "kg" })).toBe(`${MINUS}0,4 kg`);
    expect(en.signedDelta(2.5)).toBe("+2.5");
  });

  it("whole-number deltas with no unit", () => {
    expect(en.signedDelta(1, { digits: 0 })).toBe("+1");
    expect(en.signedDelta(-1234, { digits: 0 })).toBe(`${MINUS}1,234`);
  });

  it("a change that rounds to zero is plus-or-minus, never unsigned", () => {
    expect(en.signedDelta(0, { digits: 0, unit: "kg" })).toBe("±0 kg");
    expect(en.signedDelta(-0.04, { unit: "kg" })).toBe("±0.0 kg");
    expect(en.signedDelta(0.04, { unit: "kg" })).toBe("±0.0 kg");
  });
});

describe("compactAxis", () => {
  it("matches the canvas axes", () => {
    expect(en.compactAxis(0)).toBe("0");
    expect(en.compactAxis(650)).toBe("650");
    expect(en.compactAxis(1200)).toBe("1.2k");
    expect(en.compactAxis(2400)).toBe("2.4k");
    expect(en.compactAxis(13000)).toBe("13k");
  });

  it("Hungarian uses 'e' (ezer), not the SI 'k'", () => {
    expect(hu.compactAxis(2400)).toBe("2,4 e");
  });
});

describe("dates", () => {
  // The canvases' "today" example is Saturday, 27 September — but the real
  // calendar has Sep 27, 2026 falling on a Sunday, so this uses Sep 26 (an
  // actual Saturday) to keep the weekday and the date honest together.
  const sat = new Date(2026, 8, 26, 7, 15);

  it("shortDate", () => {
    expect(en.shortDate(sat)).toBe("Sep 26");
    expect(hu.shortDate(sat)).toBe("szept. 26.");
  });

  it("longDate", () => {
    expect(en.longDate(sat)).toBe("Saturday, Sep 26, 2026");
    expect(hu.longDate(sat)).toBe("2026. szept. 26., szombat");
  });

  it("dayLabel prefixes today, and only today", () => {
    expect(en.dayLabel(sat, sat)).toBe("Today · Sat, Sep 26");
    expect(hu.dayLabel(sat, sat)).toBe("Ma · szept. 26., szombat");

    const dayBefore = new Date(2026, 8, 25);
    expect(en.dayLabel(dayBefore, sat)).toBe("Fri, Sep 25");
    expect(hu.dayLabel(dayBefore, sat)).toBe("szept. 25., péntek");
  });

  it("time is 24-hour in Hungarian, 12-hour with AM/PM in English, never seconds", () => {
    expect(en.time(sat)).toBe("7:15 AM");
    expect(hu.time(sat)).toBe("07:15");
    expect(en.time(sat)).not.toMatch(/:\d{2}:\d{2}/);
  });

  it("relative — yesterday and today carry a time, further back doesn't", () => {
    const now = sat; // Sep 26
    const yesterdayEvening = new Date(2026, 8, 25, 18, 20);
    expect(en.relative(yesterdayEvening, now)).toBe("yesterday 6:20 PM");
    expect(hu.relative(yesterdayEvening, now)).toBe("tegnap 18:20");

    const threeDaysAgo = new Date(2026, 8, 23);
    expect(en.relative(threeDaysAgo, now)).toBe("3 days ago");
    expect(hu.relative(threeDaysAgo, now)).toBe("3 napja");

    const overAWeekAgo = new Date(2026, 8, 10);
    expect(en.relative(overAWeekAgo, now)).toBe(en.shortDate(overAWeekAgo));
  });

  it("weekdayShort — Hungarian stays unambiguous across a week (H K Sze Cs P Szo V)", () => {
    const monday = new Date(2026, 8, 21);
    const week = [...Array(7)].map((_, i) => hu.weekdayShort(new Date(2026, 8, 21 + i)));
    expect(week).toEqual(["H", "K", "Sze", "Cs", "P", "Szo", "V"]);
    expect(en.weekdayShort(monday)).toBe("Mon");
  });
});

describe("pace", () => {
  it("formats minutes:seconds per km the same in both languages", () => {
    expect(en.pace(348)).toBe("5:48 /km");
    expect(hu.pace(348)).toBe("5:48 /km");
  });

  it("pads seconds under 10", () => {
    expect(en.pace(305)).toBe("5:05 /km");
  });
});

describe("locale tags with a region", () => {
  it("hu-HU still counts as Hungarian", () => {
    expect(createFormat("hu-HU").weight(64.5)).toBe("64,5 kg");
  });
});

describe("weightNumber / relativeDay", () => {
  const now = new Date(2026, 8, 30, 15, 0);

  it("weightNumber keeps one decimal and drops the unit", () => {
    expect(hu.weightNumber(69.6)).toBe("69,6");
    expect(en.weightNumber(70)).toBe("70.0");
  });

  it("relativeDay says today / yesterday in words and anything older as a short date", () => {
    expect(hu.relativeDay(new Date(2026, 8, 30, 7, 0), now)).toBe("ma");
    expect(en.relativeDay(new Date(2026, 8, 30, 7, 0), now)).toBe("today");
    expect(hu.relativeDay(new Date(2026, 8, 29, 23, 0), now)).toBe("tegnap");
    expect(en.relativeDay(new Date(2026, 8, 29, 23, 0), now)).toBe("yesterday");
    expect(hu.relativeDay(new Date(2026, 8, 25), now)).toBe("szept. 25.");
    expect(en.relativeDay(new Date(2026, 8, 25), now)).toBe("Sep 25");
  });
});
