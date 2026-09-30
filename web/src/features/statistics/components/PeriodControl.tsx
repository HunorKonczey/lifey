"use client";

import { useTranslations } from "next-intl";
import { IconButton, SegmentedControl } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import {
  canStepForward,
  periodRange,
  shiftPeriod,
  STATS_PERIODS,
  switchPeriod,
  type PeriodState,
  type StatsPeriod,
} from "../period";

export interface PeriodControlProps {
  state: PeriodState;
  onChange: (next: PeriodState) => void;
  /** A phone stacks the two controls full width under the title (W5-D); the top bar keeps them side by side. */
  stacked?: boolean;
}

/** "szept. 21–27." · "2026. szeptember" · "2026" — the stepper's centre for each view. */
export function usePeriodLabel() {
  const fmt = useFormat();
  return (state: PeriodState) => {
    const range = periodRange(state.period, state.start);
    if (state.period === "week") return fmt.dateRange(range.start, range.end);
    if (state.period === "month") return fmt.monthYear(range.start);
    return String(range.start.getFullYear());
  };
}

/**
 * The statistics top bar's centre (W5-A): the Hét · Hónap · Év switch and a "‹ szept. 21–27. ›" stepper. The
 * forward arrow is disabled on the current period — a future period has nothing to show.
 */
export function PeriodControl({ state, onChange, stacked = false }: PeriodControlProps) {
  const t = useTranslations("statistics");
  const label = usePeriodLabel()(state);
  const now = new Date();
  const forward = canStepForward(state.period, state.start, now);

  return (
    <div className={stacked ? "flex flex-col gap-3 w-full" : "flex items-center gap-4"}>
      <SegmentedControl<StatsPeriod>
        aria-label={t("periodAria")}
        options={STATS_PERIODS.map((p) => ({ value: p, label: t(p) }))}
        value={state.period}
        onChange={(p) => onChange(switchPeriod(state, p, now))}
        fullWidth={stacked}
      />
      <div
        className={["flex items-center gap-1 p-1 rounded-[var(--r-pill)]", stacked ? "justify-between" : ""].join(" ")}
        style={{ background: "var(--control)" }}
      >
        <IconButton
          icon="chevron_left"
          label={t(`previous_${state.period}`)}
          size={36}
          style={{ borderRadius: "var(--r-pill)" }}
          onClick={() => onChange({ ...state, start: shiftPeriod(state.period, state.start, -1) })}
        />
        <span className="type-body-s px-1.5 whitespace-nowrap" style={{ fontWeight: 700 }} aria-live="polite">
          {label}
        </span>
        <IconButton
          icon="chevron_right"
          label={t(`next_${state.period}`)}
          size={36}
          disabled={!forward}
          aria-disabled={!forward}
          style={{ borderRadius: "var(--r-pill)", opacity: forward ? 1 : 0.4 }}
          onClick={() => onChange({ ...state, start: shiftPeriod(state.period, state.start, 1) })}
        />
      </div>
    </div>
  );
}
