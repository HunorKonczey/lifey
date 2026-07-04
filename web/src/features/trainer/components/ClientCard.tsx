"use client";

import Link from "next/link";
import { useState } from "react";
import { useTranslations } from "next-intl";
import { formatDistanceToNow } from "date-fns";
import { Sparkline } from "@/components/data/Sparkline";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import type { TrainerClientResponse } from "../types";

interface ClientCardProps {
  client: TrainerClientResponse;
  onRevoke: (clientId: number) => void;
  revoking?: boolean;
}

export function ClientCard({ client, onRevoke, revoking }: ClientCardProps) {
  const t = useTranslations("admin.dashboard");
  const [menuOpen, setMenuOpen] = useState(false);
  const [confirmingRevoke, setConfirmingRevoke] = useState(false);

  return (
    <div className="relative rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface-container)" }}>
      <div className="flex items-center gap-3">
        <ClientAvatar clientId={client.clientId} email={client.clientEmail} />
        <div className="flex-1 min-w-0">
          <p className="text-[15.5px] font-extrabold truncate" style={{ color: "var(--on-surface)" }}>
            {nameFor(client.clientEmail)}
          </p>
          <p className="text-[11.5px] mt-0.5 truncate" style={{ color: "var(--on-surface-variant)" }}>
            {t("clientSince", { time: formatDistanceToNow(new Date(client.activeSince), { addSuffix: true }) })}
          </p>
        </div>
        <button
          onClick={() => setMenuOpen((o) => !o)}
          className="w-[34px] h-[34px] rounded-[11px] flex items-center justify-center shrink-0 transition-colors hover:bg-surface-high"
          style={{ background: menuOpen ? "var(--surface-high)" : "transparent", color: "var(--on-surface)" }}
          aria-label={t("cardMenuAria")}
        >
          <span className="material-symbols-rounded text-xl">more_horiz</span>
        </button>
      </div>

      {client.weightTrend.length > 1 && (
        <div className="mt-3 -mx-1">
          <Sparkline data={client.weightTrend.map((p) => ({ date: p.date, value: p.weightKg }))} />
        </div>
      )}

      <div className="mt-3 flex items-center gap-4">
        <span className="flex items-center gap-1.5 text-[12px] font-bold" style={{ color: "var(--on-surface-variant)" }}>
          <span className="material-symbols-rounded text-base" style={{ color: "var(--tertiary)" }}>
            assignment
          </span>
          {t("assignedPlansCount", { count: client.assignedPlanCount })}
        </span>
        <span className="flex items-center gap-1.5 text-[12px] font-bold" style={{ color: "var(--on-surface-variant)" }}>
          <span className="material-symbols-rounded text-base" style={{ color: "var(--tertiary)" }}>
            fitness_center
          </span>
          {t("workoutsPerWeekCount", { count: client.workoutsPerWeek })}
        </span>
      </div>

      {menuOpen && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setMenuOpen(false)} />
          <div
            className="absolute top-14 right-4 w-[210px] rounded-2xl p-1.5 z-20"
            style={{ background: "var(--surface-highest)", boxShadow: "0 18px 44px rgba(0,0,0,.55)" }}
          >
            <Link
              href={`/admin/clients/${client.clientId}`}
              className="flex items-center gap-2.5 rounded-xl px-3 py-2.5 transition-colors hover:bg-surface-high"
              style={{ color: "var(--on-surface)" }}
            >
              <span className="material-symbols-rounded text-lg">open_in_new</span>
              <span className="text-[13px] font-bold">{t("openClient")}</span>
            </Link>
            <button
              onClick={() => {
                setMenuOpen(false);
                setConfirmingRevoke(true);
              }}
              className="w-full flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-left transition-colors hover:bg-surface-high"
              style={{ color: "var(--error)" }}
            >
              <span className="material-symbols-rounded text-lg">link_off</span>
              <span className="text-[13px] font-bold">{t("endRelationship")}</span>
            </button>
          </div>
        </>
      )}

      {confirmingRevoke && (
        <div
          className="fixed inset-0 z-30 flex items-center justify-center p-4"
          style={{ background: "rgba(8,9,6,.6)" }}
          onClick={() => setConfirmingRevoke(false)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-sm rounded-[var(--r-lg)] p-6"
            style={{ background: "var(--surface-container)", boxShadow: "0 18px 44px rgba(0,0,0,.4)" }}
          >
            <p className="text-base font-extrabold mb-2" style={{ color: "var(--on-surface)" }}>
              {t("endRelationshipConfirmTitle")}
            </p>
            <p className="text-[12.5px] leading-relaxed mb-5" style={{ color: "var(--on-surface-variant)" }}>
              {t("endRelationshipConfirmBody", { name: nameFor(client.clientEmail) })}
            </p>
            <div className="flex gap-2.5 justify-end">
              <button
                onClick={() => setConfirmingRevoke(false)}
                className="text-sm font-bold px-4 py-2.5"
                style={{ color: "var(--on-surface-variant)" }}
              >
                {t("cancel")}
              </button>
              <button
                onClick={() => {
                  setConfirmingRevoke(false);
                  onRevoke(client.clientId);
                }}
                disabled={revoking}
                className="rounded-xl px-4.5 py-2.5 text-sm font-extrabold disabled:opacity-60"
                style={{ background: "var(--error)", color: "#161611" }}
              >
                {t("endRelationshipConfirm")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
