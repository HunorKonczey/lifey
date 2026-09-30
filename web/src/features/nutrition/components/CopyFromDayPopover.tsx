"use client";

import { useEffect, useRef, useState, type RefObject } from "react";
import { useQuery } from "@tanstack/react-query";
import { useLocale, useTranslations } from "next-intl";
import { Button, Checkbox, Icon, Popover } from "@/components/ds";
import { CalendarPopover } from "@/components/ds/date";
import { createFormat } from "@/lib/format/lifeyFormat";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { mealApi } from "../api";
import { dayKey, loggedDayKeys, mealsOnDay, quickSourceDays, sourceChip } from "../copyFromDay";
import { MEAL_TYPE_STYLE } from "../mealTypeStyle";
import { useCopyMeals } from "../useCopyMeals";
import type { MealResponse } from "../types";
import { isRecipeMeal, mealKcal } from "./MealCard";

const MEAL_TYPE_KEY = { BREAKFAST: "breakfast", LUNCH: "lunch", SNACK: "snack", DINNER: "dinner" } as const;

export interface CopyFromDayViewProps {
  open: boolean;
  onClose: () => void;
  anchorRef: RefObject<HTMLElement | null>;
  /** Every logged meal — the popover picks the chosen day's out of it. */
  meals: MealResponse[];
  /** The day being viewed — the one the copies land on. */
  target: Date;
  today: Date;
  pending?: boolean;
  onCopy: (meals: MealResponse[]) => void;
}

/**
 * Copy from an earlier day (W2.9, extra-003): day chips ("Tegnap · szept. 26.", "szept. 25.",
 * "Másik nap" → a month grid with dots on logged days), the chosen day's meals with checkboxes and
 * kcal, and "N étkezés másolása". Copies are added to the viewed day and never overwrite anything.
 */
export function CopyFromDayView({ open, onClose, anchorRef, meals, target, today, pending, onCopy }: CopyFromDayViewProps) {
  return (
    <Popover open={open} onClose={onClose} anchorRef={anchorRef} width={392}>
      <Panel meals={meals} target={target} today={today} pending={pending} onCopy={onCopy} />
    </Popover>
  );
}

function Panel({ meals, target, today, pending, onCopy }: Omit<CopyFromDayViewProps, "open" | "onClose" | "anchorRef">) {
  const t = useTranslations("nutrition");
  const locale = useLocale();
  const fmt = useFormat();
  const format = createFormat(locale);
  const [first, second] = quickSourceDays(target);

  // Fresh each time the popover opens (the Popover unmounts its children when closed).
  const [source, setSource] = useState(first);
  const [calendarOpen, setCalendarOpen] = useState(false);
  const [unchecked, setUnchecked] = useState<Set<number>>(new Set());
  const firstChip = useRef<HTMLButtonElement>(null);
  // A frame late, like `Menu`: the Popover records the trigger for focus-return in its own effect, which runs after this one.
  useEffect(() => {
    const raf = requestAnimationFrame(() => firstChip.current?.focus());
    return () => cancelAnimationFrame(raf);
  }, []);

  const chip = sourceChip(source, target);
  const dayMeals = mealsOnDay(meals, source);
  const chosen = dayMeals.filter((m) => !unchecked.has(m.id));
  const logged = loggedDayKeys(meals);

  function pickDay(day: Date) {
    setSource(day);
    setUnchecked(new Set());
  }
  function toggle(id: number) {
    setUnchecked((prev) => {
      const next = new Set(prev);
      if (!next.delete(id)) next.add(id);
      return next;
    });
  }

  const isYesterdayOfToday = dayKey(first) === dayKey(new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1));
  const chips: { key: string; label: string; on: boolean; onClick: () => void; ref?: RefObject<HTMLButtonElement | null> }[] = [
    {
      key: "first",
      label: isYesterdayOfToday ? t("copyChipYesterday", { date: format.shortDate(first) }) : format.shortDate(first),
      on: chip === "first",
      onClick: () => {
        pickDay(first);
        setCalendarOpen(false);
      },
      ref: firstChip,
    },
    {
      key: "second",
      label: format.shortDate(second),
      on: chip === "second",
      onClick: () => {
        pickDay(second);
        setCalendarOpen(false);
      },
    },
    {
      key: "other",
      label: chip === "other" ? `${t("copyChipOther")} · ${format.shortDate(source)}` : t("copyChipOther"),
      on: chip === "other" || calendarOpen,
      onClick: () => setCalendarOpen((o) => !o),
    },
  ];

  return (
    <div className="flex flex-col gap-3 p-4" data-testid="copy-from-day">
      <h3 style={{ fontSize: 16, fontWeight: 800 }}>{t("copyFromDay")}</h3>

      <div className="flex flex-wrap gap-2" role="group" aria-label={t("copyDayChipsAria")}>
        {chips.map((c) => (
          <button
            key={c.key}
            ref={c.ref}
            type="button"
            aria-pressed={c.on}
            onClick={c.onClick}
            className="lifey-button type-body-s"
            style={{
              height: 30,
              padding: "0 12px",
              borderRadius: "var(--r-pill)",
              fontWeight: 700,
              background: c.on ? "var(--primary)" : "var(--nested)",
              color: c.on ? "var(--on-primary)" : "var(--text-2)",
            }}
          >
            {c.label}
          </button>
        ))}
      </div>

      {calendarOpen && (
        <CalendarPopover
          value={source}
          today={today}
          disableFuture
          hasData={(d) => logged.has(dayKey(d))}
          onChange={(d) => {
            pickDay(d);
            setCalendarOpen(false);
          }}
        />
      )}

      {!calendarOpen && (
        <ul className="flex flex-col" data-testid="copy-day-meals">
          {dayMeals.length === 0 && (
            <li className="type-body-s py-3" style={{ color: "var(--text-3)" }}>
              {t("copyEmptyDay")}
            </li>
          )}
          {dayMeals.map((m) => {
            const style = MEAL_TYPE_STYLE[m.mealType];
            const name = t(MEAL_TYPE_KEY[m.mealType]);
            const time = fmt.time(new Date(m.dateTime));
            return (
              <li key={m.id} className="flex items-center gap-3 py-2">
                <Checkbox checked={!unchecked.has(m.id)} onChange={() => toggle(m.id)} aria-label={`${name} ${time}`} />
                <button
                  type="button"
                  tabIndex={-1}
                  onClick={() => toggle(m.id)}
                  className="flex min-w-0 flex-1 items-center gap-3 text-left"
                >
                  <span
                    className="flex shrink-0 items-center justify-center"
                    style={{
                      width: 32,
                      height: 32,
                      borderRadius: "var(--r-control)",
                      background: `color-mix(in srgb, ${style.color} var(--chip-tint), transparent)`,
                    }}
                  >
                    <Icon name={style.icon} size={18} fill={1} color={style.color} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block type-body-s" style={{ fontWeight: 700 }}>
                      {name}
                    </span>
                    <span className="block type-label tabular" style={{ color: "var(--text-3)" }}>
                      {isRecipeMeal(m) ? `${time} · ${m.name}` : t("mealMeta", { time, count: m.entries.length })}
                    </span>
                  </span>
                  <span className="type-body-s tabular" style={{ fontWeight: 700 }}>
                    {fmt.integer(mealKcal(m))} kcal
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      )}

      <p className="type-label" style={{ color: "var(--text-3)" }}>
        {dayKey(target) === dayKey(today) ? t("copyNoteToday") : t("copyNoteDay", { day: format.relativeDay(target, today) })}
      </p>
      <Button onClick={() => onCopy(chosen)} disabled={chosen.length === 0 || pending} fullWidth>
        {t("copyAction", { count: chosen.length })}
      </Button>
    </div>
  );
}

export interface CopyFromDayPopoverProps {
  open: boolean;
  onClose: () => void;
  anchorRef: RefObject<HTMLElement | null>;
  /** The viewed day. */
  date: Date;
}

/** The connected popover: reads the meals the log already loads and copies through `useCopyMeals` (undo toast). */
export function CopyFromDayPopover({ open, onClose, anchorRef, date }: CopyFromDayPopoverProps) {
  const t = useTranslations("nutrition");
  const { data } = useQuery({ queryKey: queryKeys.meals.all(), queryFn: mealApi.list });
  const copy = useCopyMeals(date);
  const [today] = useState(() => new Date());

  return (
    <CopyFromDayView
      open={open}
      onClose={onClose}
      anchorRef={anchorRef}
      meals={data ?? []}
      target={date}
      today={today}
      pending={copy.isPending}
      onCopy={(meals) => copy.mutate({ meals, message: t("mealsCopied", { count: meals.length }) }, { onSuccess: onClose })}
    />
  );
}
