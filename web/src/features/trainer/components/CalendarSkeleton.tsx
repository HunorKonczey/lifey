"use client";

/* Column card counts mimic the design's organic loading pattern (frame D) rather
 * than a uniform grid — it reads closer to what real content will look like. */
const WEEK_COLUMN_CARD_COUNTS = [2, 1, 3, 2, 1, 1, 0];

export function CalendarWeekSkeleton() {
  return (
    <div className="flex-1 grid grid-cols-7 gap-2">
      {WEEK_COLUMN_CARD_COUNTS.map((count, i) => (
        <div key={i} className="rounded-2xl p-2 flex flex-col gap-1.5" style={{ background: "var(--surface)" }}>
          <div className="skeleton-pulse h-[9px] w-[60%] mx-1.5 my-1" />
          {Array.from({ length: count }).map((_, j) => (
            <div key={j} className="skeleton-pulse h-[52px] rounded-2xl" style={{ background: "var(--surface-container)" }} />
          ))}
        </div>
      ))}
    </div>
  );
}

export function CalendarAgendaSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      {[3, 2, 1].map((rows, i) => (
        <div key={i} className="flex flex-col gap-1.5">
          <div className="skeleton-pulse h-3 w-32" />
          {Array.from({ length: rows }).map((_, j) => (
            <div key={j} className="skeleton-pulse h-[56px] rounded-2xl" style={{ background: "var(--surface-container)" }} />
          ))}
        </div>
      ))}
    </div>
  );
}

export function CalendarMonthSkeleton() {
  return (
    <div className="flex-1 grid grid-cols-7 gap-1.5" style={{ gridAutoRows: "1fr" }}>
      {Array.from({ length: 35 }).map((_, i) => (
        <div key={i} className="skeleton-pulse rounded-xl" style={{ minHeight: 64, background: "var(--surface)" }} />
      ))}
    </div>
  );
}
