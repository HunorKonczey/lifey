"use client";

import { usePathname } from "next/navigation";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { useUiStore } from "@/lib/hooks/useUiStore";
import { ThemeToggle } from "./ThemeToggle";
import { format, addDays, subDays } from "date-fns";

const PAGE_TITLES: Record<string, string> = {
  "/dashboard": "Dashboard",
  "/nutrition": "Nutrition",
  "/workouts": "Workouts",
  "/weight": "Weight",
  "/water": "Water",
  "/steps": "Steps",
  "/statistics": "Statistics",
  "/settings": "Settings",
};

export function TopBar() {
  const pathname = usePathname();
  const { date, setDate } = useDateStore();
  const toggleDrawer = useUiStore((s) => s.toggleDrawer);

  const title =
    Object.entries(PAGE_TITLES).find(([prefix]) =>
      pathname.startsWith(prefix),
    )?.[1] ?? "Lifey";

  const isToday =
    format(date, "yyyy-MM-dd") === format(new Date(), "yyyy-MM-dd");

  return (
    <header
      className="sticky top-0 z-10 flex items-center justify-between px-6 h-[62px] shrink-0"
      style={{
        background: "var(--surface-high)",
        borderBottom: "1px solid var(--outline)",
      }}
    >
      <div className="flex items-center gap-2">
        <button
          onClick={toggleDrawer}
          className="p-1.5 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container md:hidden"
          style={{ color: "var(--on-surface)" }}
          aria-label="Open menu"
        >
          <span className="material-symbols-rounded text-xl">menu</span>
        </button>
        <h1 className="text-lg font-bold">{title}</h1>
      </div>

      {/* Date picker */}
      <div className="flex items-center gap-1">
        <button
          onClick={() => setDate(subDays(date, 1))}
          className="p-1.5 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container"
          style={{ color: "var(--on-surface-variant)" }}
          aria-label="Previous day"
        >
          <span className="material-symbols-rounded text-xl">chevron_left</span>
        </button>

        <button
          onClick={() => setDate(new Date())}
          className="px-3 py-1 rounded-[var(--r-sm)] text-sm font-semibold tabular transition-colors"
          style={{
            background: isToday ? "var(--primary)" : "var(--surface-container)",
            color: isToday ? "#1E1F18" : "var(--on-surface)",
          }}
        >
          {isToday ? "Today" : format(date, "MMM d")}
        </button>

        <button
          onClick={() => setDate(addDays(date, 1))}
          className="p-1.5 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container"
          style={{ color: "var(--on-surface-variant)" }}
          aria-label="Next day"
        >
          <span className="material-symbols-rounded text-xl">chevron_right</span>
        </button>
      </div>

      <ThemeToggle />
    </header>
  );
}
