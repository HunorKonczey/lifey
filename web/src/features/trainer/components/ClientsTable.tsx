"use client";

import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { DataTable, DeltaChip, type DataTableColumn } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { weightChange, type WeekSummary } from "../clientSignals";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";
import { sessionDay, useLastActivityLabel } from "./ClientCard";
import type { TrainerClientResponse } from "../types";

/** The table view of the clients (W7-A): the same facts as the card, one row per client, a row opens the client. */
export function ClientsTable({ clients, weeks }: { clients: TrainerClientResponse[]; weeks: Map<number, WeekSummary> }) {
  const t = useTranslations("admin.dashboard");
  const router = useRouter();
  const fmt = useFormat();
  const label = useLastActivityLabel();
  const dash = <span style={{ color: "var(--text-3)" }}>—</span>;

  const columns: DataTableColumn<TrainerClientResponse>[] = [
    {
      key: "name",
      header: t("colClient"),
      sort: (c) => clientDisplayName(c),
      render: (c) => (
        <span className="flex items-center gap-3 min-w-0">
          <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={32} />
          <span className="truncate" style={{ fontWeight: 700 }}>{clientDisplayName(c)}</span>
        </span>
      ),
    },
    {
      key: "activity",
      header: t("colActivity"),
      sort: (c) => c.lastActivityAt ?? "",
      render: (c) => {
        const a = label(c);
        return <span style={{ color: a.alert ? "var(--heart)" : undefined, fontWeight: a.alert ? 700 : 400 }}>{a.text}</span>;
      },
    },
    {
      key: "kcal",
      header: t("kpiCalories"),
      align: "right",
      sort: (c) => c.avgCalories7d ?? -1,
      render: (c) => (c.avgCalories7d != null ? <span className="num">{fmt.number(c.avgCalories7d, 0)} kcal</span> : dash),
    },
    {
      key: "workouts",
      header: t("kpiWorkouts"),
      align: "right",
      render: (c) => {
        const w = weeks.get(c.clientId);
        return w && w.scheduled > 0 ? <span className="num">{w.done} / {w.scheduled}</span> : dash;
      },
    },
    {
      key: "weight",
      header: t("kpiWeight"),
      align: "right",
      render: (c) => {
        const w = weightChange(c.weightTrend);
        if (!w) return <span style={{ color: "var(--text-3)" }}>{t("noWeighIn")}</span>;
        return (
          <span className="inline-flex items-center justify-end gap-2">
            <span className="num">{fmt.number(w.latestKg, 1)} kg</span>
            {w.deltaKg != null && <DeltaChip value={w.deltaKg} unit="kg" size="small" />}
          </span>
        );
      },
    },
    {
      key: "next",
      header: t("colNext"),
      render: (c) => {
        const n = weeks.get(c.clientId)?.next;
        return n ? <span>{sessionDay(fmt, n.scheduledFor)}{n.templateName ? ` · ${n.templateName}` : ""}</span> : <span style={{ color: "var(--text-3)" }}>{t("notScheduled")}</span>;
      },
    },
  ];

  return (
    <DataTable
      aria-label={t("tableAria")}
      columns={columns}
      rows={clients}
      rowKey={(c) => c.clientId}
      pageSize={25}
      onRowOpen={(c) => router.push(`/admin/clients/${c.clientId}`)}
      renderCardRow={(c) => ({ title: clientDisplayName(c), meta: label(c).text, value: c.avgCalories7d != null ? `${fmt.number(c.avgCalories7d, 0)} kcal` : undefined })}
      totalLabel={(n) => t("tableTotal", { count: n })}
    />
  );
}
