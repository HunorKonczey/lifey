"use client";

import { useEffect, useState } from "react";
import { useFormat } from "@/lib/format/useFormat";

/** DS-07's formatting table, rendered through the real `lifeyFormat` /
 *  `useFormat` functions (D-W0.8) rather than typed out by hand — a
 *  regression in the formatter shows up here in whichever language the
 *  toolbar has selected. */
export function FormattingSection() {
  const f = useFormat();
  // `now` is filled in after mount instead of read directly during render:
  // a bare `new Date()` runs once on the server and again on the client at
  // hydration, and those are genuinely different instants (a real hydration
  // mismatch when they straddle a clock tick, not test flakiness).
  const [now, setNow] = useState<Date | null>(null);
  // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time mount fill-in, not a sync loop
  useEffect(() => setNow(new Date()), []);

  if (!now) return null;

  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  yesterday.setHours(18, 20, 0, 0);

  const rows: [string, string][] = [
    ["weight(69.6)", f.weight(69.6)],
    ["litresOfGoal(1.6, 2.5)", f.litresOfGoal(1.6, 2.5)],
    ["integer(17519, kcal)", f.integer(17519, "kcal")],
    ["grams(166.68)", f.grams(166.68)],
    ["shortDate(today)", f.shortDate(now)],
    ["longDate(today)", f.longDate(now)],
    ["dayLabel(today, today)", f.dayLabel(now, now)],
    ["relative(yesterday 18:20)", f.relative(yesterday, now)],
    ["time(now)", f.time(now)],
    ["pace(348)", f.pace(348)],
    ["compactAxis(2400)", f.compactAxis(2400)],
    ["weekdayShort(today)", f.weekdayShort(now)],
    ["signedDelta(-0.4, kg)", f.signedDelta(-0.4, { unit: "kg" })],
    ["signedDelta(0, digits:0, kg)", f.signedDelta(0, { digits: 0, unit: "kg" })],
    ["roleLabel(ROLE_TRAINER)", f.roleLabel("ROLE_TRAINER")],
    ["activityLabel(CYCLING)", f.activityLabel("CYCLING")],
    ["mealTypeLabel(BREAKFAST)", f.mealTypeLabel("BREAKFAST")],
  ];

  return (
    <table className="w-full type-body-s">
      <tbody>
        {rows.map(([call, result]) => (
          <tr key={call} style={{ borderBottom: "1px solid var(--hairline)" }}>
            <td className="py-1.5 pr-4">
              <code style={{ color: "var(--text-3)" }}>{call}</code>
            </td>
            <td className="py-1.5 tabular">{result}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
