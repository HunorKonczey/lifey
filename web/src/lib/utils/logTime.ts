/**
 * Pick the timestamp to store for an entry logged against a given day.
 *
 * The dashboard lets you log against a selected day (today or a past day). The
 * backend requires a past-or-present instant. So:
 *  - logging for **today** (or no date) → use the real current time, so the
 *    entry reflects when it was actually added (matches the mobile app);
 *  - logging for a **past day** → anchor at noon of that local day, a valid
 *    past timestamp that lands unambiguously on the intended day;
 *  - a future day (shouldn't happen) → clamp to now.
 */
export function logTimestampFor(date?: Date): string {
  const now = new Date();
  if (!date) return now.toISOString();

  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();

  if (sameDay || date > now) return now.toISOString();

  const dt = new Date(date);
  dt.setHours(12, 0, 0, 0);
  return dt.toISOString();
}
