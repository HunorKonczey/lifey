"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { ClientDetailHeader, type ClientTab } from "@/features/trainer/components/ClientDetailHeader";
import { ClientOverviewTab } from "@/features/trainer/components/ClientOverviewTab";
import { ClientStatisticsTab } from "@/features/trainer/components/ClientStatisticsTab";
import { ClientStepsTab } from "@/features/trainer/components/ClientStepsTab";
import { ClientNutritionTab } from "@/features/trainer/components/ClientNutritionTab";
import { ClientWorkoutsTab } from "@/features/trainer/components/ClientWorkoutsTab";
import { Skeleton } from "@/components/status/Skeleton";

interface ClientDetailPageProps {
  params: Promise<{ clientId: string }>;
}

export default function ClientDetailPage({ params }: ClientDetailPageProps) {
  const { clientId: clientIdParam } = use(params);
  const clientId = Number(clientIdParam);
  const t = useTranslations("admin.clientDetail");
  const [tab, setTab] = useState<ClientTab>("overview");

  const { data: clients, isLoading } = useQuery({
    queryKey: queryKeys.trainerClients.all(),
    queryFn: trainerApi.clients,
  });

  if (isLoading) {
    return (
      <div className="flex flex-col gap-3.5">
        <Skeleton variant="card" className="h-[72px]" />
        <Skeleton variant="card" className="h-96" />
      </div>
    );
  }

  const client = clients?.find((c) => c.clientId === clientId);

  if (!client) {
    return (
      <div
        className="rounded-2xl p-4 flex items-center gap-3.5"
        style={{ background: "var(--surface)", border: "1px solid rgba(207,102,121,.22)" }}
      >
        <div
          className="w-[42px] h-[42px] rounded-2xl flex items-center justify-center shrink-0"
          style={{ background: "var(--error-container)", color: "var(--error)" }}
        >
          <span className="material-symbols-rounded text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>
            link_off
          </span>
        </div>
        <div className="flex-1">
          <p className="text-sm font-extrabold" style={{ color: "var(--on-surface)" }}>
            {t("clientUnavailable")}
          </p>
          <p className="text-xs mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("clientUnavailableBody")}
          </p>
        </div>
        <Link
          href="/admin"
          className="flex items-center gap-1.5 rounded-xl px-3.5 py-2.5 text-[13px] font-bold shrink-0"
          style={{ background: "var(--surface-high)", color: "var(--on-surface)" }}
        >
          <span className="material-symbols-rounded text-lg" style={{ color: "var(--tertiary)" }}>
            arrow_back
          </span>
          {t("backToList")}
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3.5">
      <ClientDetailHeader client={client} tab={tab} onTabChange={setTab} />
      {tab === "overview" && <ClientOverviewTab clientId={clientId} />}
      {tab === "statistics" && <ClientStatisticsTab clientId={clientId} />}
      {tab === "steps" && <ClientStepsTab clientId={clientId} />}
      {tab === "nutrition" && <ClientNutritionTab clientId={clientId} />}
      {tab === "workouts" && <ClientWorkoutsTab clientId={clientId} />}
    </div>
  );
}
