"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { formatDistanceToNow } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import { useLocale } from "@/lib/hooks/useLocale";
import type { TrainerClientResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

interface ClientListModalProps {
  clients: TrainerClientResponse[];
  onClose: () => void;
}

export function ClientListModal({ clients, onClose }: ClientListModalProps) {
  const t = useTranslations("admin.dashboard");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: "rgba(8,9,6,.6)" }}
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        onClick={(e) => e.stopPropagation()}
        className="w-full max-w-[560px] rounded-[var(--r-lg)] p-6"
        style={{ background: "var(--surface-container)", boxShadow: "0 30px 70px rgba(0,0,0,.6)" }}
      >
        <h2 className="text-xl font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
          {t("modalTitle")}
        </h2>
        <p className="text-sm mt-1 mb-5" style={{ color: "var(--on-surface-variant)" }}>
          {t("modalSubtitle", { count: clients.length })}
        </p>

        <div className="flex flex-col gap-1.5 max-h-[50vh] overflow-y-auto">
          {clients.map((c) => (
            <Link
              key={c.clientId}
              href={`/admin/clients/${c.clientId}`}
              onClick={onClose}
              className="flex items-center gap-3 rounded-2xl px-3.5 py-2.5 transition-colors hover:bg-surface-high"
            >
              <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={36} />
              <span className="flex-1 min-w-0 text-sm font-bold truncate" style={{ color: "var(--on-surface)" }}>
                {nameFor(c.clientEmail)}
              </span>
              <span className="text-[11.5px]" style={{ color: "var(--muted)" }}>
                {formatDistanceToNow(new Date(c.activeSince), { addSuffix: true, locale: dateLocale })}
              </span>
              <span className="material-symbols-rounded text-xl" style={{ color: "var(--muted)" }}>
                chevron_right
              </span>
            </Link>
          ))}
        </div>

        <div
          className="flex items-center justify-between mt-5 pt-4"
          style={{ borderTop: "1px solid var(--outline)" }}
        >
          <button
            onClick={onClose}
            className="text-sm font-bold px-4 py-2.5"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {t("close")}
          </button>
          <Link
            href="/admin/invites"
            className="flex items-center gap-2 rounded-2xl px-4.5 py-2.5 text-sm font-extrabold"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            <span className="material-symbols-rounded text-xl">person_add</span>
            {t("inviteClient")}
          </Link>
        </div>
      </div>
    </div>
  );
}
