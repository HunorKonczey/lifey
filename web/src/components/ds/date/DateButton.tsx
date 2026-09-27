"use client";

import { useLocale } from "next-intl";
import { createFormat } from "@/lib/format/lifeyFormat";
import { Icon } from "../Icon";

export interface DateButtonProps {
  value: Date;
  onClick: () => void;
  disabled?: boolean;
  className?: string;
}

/** The trigger for `CalendarPopover` — shows `lifeyFormat.longDate` (D-W0.10). */
export function DateButton({ value, onClick, disabled, className }: DateButtonProps) {
  const locale = useLocale();
  const format = createFormat(locale);

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={["lifey-button inline-flex items-center gap-2 px-3 h-10 type-body-s rounded-[var(--r-control)]", className]
        .filter(Boolean)
        .join(" ")}
      style={{ background: "var(--control)", color: "var(--text)" }}
    >
      <Icon name="calendar_today" size={16} color="var(--text-2)" />
      {format.longDate(value)}
    </button>
  );
}
