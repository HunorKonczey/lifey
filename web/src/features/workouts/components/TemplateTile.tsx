"use client";

import type { ReactNode } from "react";
import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";
import type { PickerTemplate } from "../templatePicker";

/**
 * The template tile the start picker and the Templates tab share (W3.5 / W3.11, W3-F): a tinted `list_alt` icon,
 * the name with its "Javasolt" chip, "4 gyakorlat · kb. 40 perc" and "7 napja" on the right. Selected = the
 * primary tint with a 2 px inset ring. `radio` makes it a radio of the picker's group; otherwise it is a button
 * that marks the list's current selection with `aria-current`. `footer` holds a list row's own actions.
 */
export function TemplateTile({
  item,
  selected,
  radio = false,
  onClick,
  onDoubleClick,
  footer,
}: {
  item: PickerTemplate;
  selected: boolean;
  radio?: boolean;
  onClick: () => void;
  onDoubleClick?: () => void;
  footer?: ReactNode;
}) {
  const t = useTranslations("workouts");
  const daysAgo = item.daysAgo == null ? t("pickerNeverDone") : item.daysAgo === 0 ? t("pickerToday") : t("pickerDaysAgo", { count: item.daysAgo });

  return (
    <div
      className="flex flex-col gap-2 p-3"
      style={{
        borderRadius: "var(--r-card)",
        background: selected ? "var(--primary-tint)" : "var(--nested)",
        boxShadow: selected ? "inset 0 0 0 2px var(--primary)" : undefined,
        transition: "background-color var(--dur-hover) var(--ease-standard)",
      }}
    >
      <button
        type="button"
        role={radio ? "radio" : undefined}
        aria-checked={radio ? selected : undefined}
        aria-current={!radio && selected ? "true" : undefined}
        onClick={onClick}
        onDoubleClick={onDoubleClick}
        className="lifey-button flex w-full items-center gap-3 text-left"
      >
        <span
          className="flex flex-none items-center justify-center"
          style={{ width: 40, height: 40, borderRadius: 12, background: "color-mix(in srgb, var(--primary) var(--chip-tint), transparent)", color: "var(--primary)" }}
        >
          <Icon name="list_alt" size={22} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="flex flex-wrap items-center gap-2">
            <span className="type-body truncate" style={{ fontWeight: 700 }}>
              {item.template.name}
            </span>
            {item.recommended && (
              // Solid, not a tint on the selected tile's tint: primary-on-primary-tint was 4.25:1 in dark.
              <span className="type-label rounded-[var(--r-pill)] px-2 py-0.5" style={{ background: "var(--primary)", color: "var(--on-primary)" }}>
                {t("recommendedBadge")}
              </span>
            )}
          </span>
          <span className="type-body-s block" style={{ color: "var(--text-2)" }}>
            {t("pickerMeta", { exercises: item.exerciseCount, minutes: item.estimatedMinutes })}
          </span>
        </span>
        <span className="type-body-s flex-none" style={{ color: "var(--text-2)" }}>
          {daysAgo}
        </span>
      </button>
      {footer}
    </div>
  );
}
