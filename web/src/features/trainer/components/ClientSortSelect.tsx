"use client";

import { useTranslations } from "next-intl";
import type { ClientSortOption } from "../compliance";

interface ClientSortSelectProps {
  value: ClientSortOption;
  onChange: (value: ClientSortOption) => void;
}

/** Sort control for the client grid (docs/29) — pure client-side re-sort of the already-fetched list. */
export function ClientSortSelect({ value, onChange }: ClientSortSelectProps) {
  const t = useTranslations("admin.dashboard");

  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value as ClientSortOption)}
      aria-label={t("sortAria")}
      className="h-10 rounded-xl px-3 text-sm font-semibold outline-none"
      style={{ background: "var(--surface)", color: "var(--on-surface)", border: "1px solid var(--outline)" }}
    >
      <option value="recent">{t("sortRecent")}</option>
      <option value="leastActive">{t("sortLeastActive")}</option>
      <option value="mostMissed">{t("sortMostMissed")}</option>
      <option value="weightOverdue">{t("sortWeightOverdue")}</option>
    </select>
  );
}
