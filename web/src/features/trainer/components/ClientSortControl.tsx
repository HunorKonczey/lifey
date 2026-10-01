"use client";

import { useTranslations } from "next-intl";
import { SegmentedControl } from "@/components/ds";
import type { ClientListSort } from "../clientSignals";

export type ClientView = "grid" | "table";

/** The sort segmented control (Figyelem · Név · Utolsó aktivitás) and the grid / table toggle of W7-A. */
export function ClientSortControl({ sort, onSort, view, onView }: { sort: ClientListSort; onSort: (s: ClientListSort) => void; view: ClientView; onView: (v: ClientView) => void }) {
  const t = useTranslations("admin.dashboard");
  return (
    <div className="flex flex-wrap items-center gap-3">
      <SegmentedControl<ClientListSort>
        aria-label={t("sortAria")}
        value={sort}
        onChange={onSort}
        options={[
          { value: "attention", label: t("sortAttention") },
          { value: "name", label: t("sortName") },
          { value: "activity", label: t("sortActivity") },
        ]}
      />
      <SegmentedControl<ClientView>
        aria-label={t("viewAria")}
        value={view}
        onChange={onView}
        options={[
          { value: "grid", label: t("viewGrid"), icon: "grid_view" },
          { value: "table", label: t("viewTable"), icon: "table_rows" },
        ]}
      />
    </div>
  );
}
