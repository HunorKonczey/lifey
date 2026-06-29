/**
 * Pick the timestamp to store for an entry logged against a given day.
 *
 *  - logging for **today** (or no date) → use the real current time so the
 *    entry reflects when it was actually added (matches the mobile app);
 *  - logging for a **past or future day** → anchor at noon of that local day,
 *    landing unambiguously on the intended day.
 */
export function logTimestampFor(date?: Date): string {
  const now = new Date();
  if (!date) return now.toISOString();

  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();

  if (sameDay) return now.toISOString();

  const dt = new Date(date);
  dt.setHours(12, 0, 0, 0);
  return dt.toISOString();
}
