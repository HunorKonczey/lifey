/** A calendar month as a Monday-first 6×7 grid (D-W0.10), including the
 *  leading/trailing days from the adjacent months that fill the first and
 *  last week — the shape every calendar UI needs, kept separate from any
 *  rendering so it's cheap to unit test.
 */
export interface MonthGridDay {
  date: Date;
  /** False for a day from the previous/next month, shown muted to fill the grid. */
  inMonth: boolean;
}

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

/** Monday = 0 … Sunday = 6, unlike `Date#getDay()`'s Sunday = 0. */
function mondayIndex(date: Date): number {
  return (date.getDay() + 6) % 7;
}

export function monthGrid(year: number, month: number): MonthGridDay[] {
  const firstOfMonth = new Date(year, month, 1);
  const gridStart = new Date(year, month, 1 - mondayIndex(firstOfMonth));

  return Array.from({ length: 42 }, (_, i) => {
    const date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + i);
    return { date, inMonth: date.getMonth() === month };
  });
}

export function isSameDay(a: Date, b: Date): boolean {
  return startOfDay(a).getTime() === startOfDay(b).getTime();
}

export function isFuture(date: Date, today: Date): boolean {
  return startOfDay(date).getTime() > startOfDay(today).getTime();
}
