"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import { useLocale } from "@/lib/hooks/useLocale";
import type { TrainerClientResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

export type ClientTab = "overview" | "statistics" | "steps" | "nutrition" | "workouts";

const TABS: { key: ClientTab; icon: string }[] = [
  { key: "overview", icon: "dashboard" },
  { key: "statistics", icon: "bar_chart" },
  { key: "steps", icon: "directions_walk" },
  { key: "nutrition", icon: "restaurant" },
  { key: "workouts", icon: "fitness_center" },
];

interface ClientDetailHeaderProps {
  client: TrainerClientResponse;
  tab: ClientTab;
  onTabChange: (tab: ClientTab) => void;
}

export function ClientDetailHeader({ client, tab, onTabChange }: ClientDetailHeaderProps) {
  const t = useTranslations("admin.clientDetail");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];

  return (
    <div className="flex flex-col gap-3.5">
      <div
        className="flex items-center gap-4 rounded-[var(--r-card)] px-5 py-4"
        style={{ background: "var(--surface-high)" }}
      >
        <Link href="/admin" style={{ color: "var(--on-surface-variant)" }}>
          <span className="material-symbols-rounded text-2xl">arrow_back</span>
        </Link>
        <ClientAvatar clientId={client.clientId} email={client.clientEmail} size={48} />
        <div className="flex-1 min-w-0">
          <p className="text-lg font-extrabold tracking-tight truncate" style={{ color: "var(--on-surface)" }}>
            {nameFor(client.clientEmail)}
          </p>
          <p className="text-xs mt-0.5 truncate" style={{ color: "var(--on-surface-variant)" }}>
            {client.clientEmail}
          </p>
        </div>
        <span className="text-[11.5px] font-semibold whitespace-nowrap" style={{ color: "var(--muted)" }}>
          {t("relationshipSince", {
            date: format(new Date(client.activeSince), "yyyy. MMM d.", { locale: dateLocale }),
          })}
        </span>
        <span
          className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-xs font-bold px-3.5 py-1.5 whitespace-nowrap"
          style={{ border: "1px solid var(--outline)", color: "var(--on-surface-variant)" }}
        >
          <span className="material-symbols-rounded text-base">visibility</span>
          {t("readOnly")}
        </span>
      </div>

      <div className="flex rounded-[var(--r-pill)] p-1 w-fit" style={{ background: "var(--surface)" }}>
        {TABS.map(({ key, icon }) => {
          const active = tab === key;
          return (
            <button
              key={key}
              onClick={() => onTabChange(key)}
              className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[13px] font-bold px-5 py-2.5 transition-colors"
              style={{ background: active ? "var(--tertiary)" : "transparent", color: active ? "#161611" : "var(--on-surface-variant)" }}
            >
              <span className="material-symbols-rounded text-base" style={{ fontVariationSettings: active ? "'FILL' 1" : "'FILL' 0" }}>
                {icon}
              </span>
              {t(`tabs.${key}`)}
            </button>
          );
        })}
      </div>
    </div>
  );
}
