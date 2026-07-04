"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatDistanceToNow } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useLocale } from "@/lib/hooks/useLocale";
import { ApiError } from "@/lib/api/client";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";

const DATE_LOCALES = { en: enUS, hu } as const;

function isUrgent(expiresAt: string) {
  return new Date(expiresAt).getTime() - Date.now() < 3 * 60 * 60 * 1000;
}

export default function AdminInvitesPage() {
  const t = useTranslations("admin.invites");
  const admin = useTranslations("admin");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const locale = useLocale((s) => s.locale);
  const dateLocale = DATE_LOCALES[locale];
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | null>(null);

  const { data: invites, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerInvites.all(),
    queryFn: trainerApi.pendingInvites,
  });

  const inviteMutation = useMutation({
    mutationFn: () => trainerApi.invite({ email }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerInvites.all() });
      show(t("sent"), "success");
      setEmail("");
      setError(null);
    },
    onError: (err) => {
      if (err instanceof ApiError) {
        if (err.status === 404) return setError(t("errorNotFound"));
        if (err.status === 409) return setError(t("errorAlreadyClient"));
        if (err.status === 429) return setError(t("errorRateLimited"));
      }
      setError(t("errorGeneric"));
    },
  });

  const revokeMutation = useMutation({
    mutationFn: (id: number) => trainerApi.cancelInvite(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerInvites.all() });
      show(t("revoked"), "success");
    },
    onError: () => show(t("revokeFailed"), "error"),
  });

  return (
    <div className="flex flex-col gap-3.5 max-w-2xl">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
            {t("title")}
          </p>
          <p className="text-xs mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("subtitle")}
          </p>
        </div>
        <span
          className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[10px] font-extrabold tracking-wide px-2.5 py-1"
          style={{ background: "var(--tertiary)", color: "#161611" }}
        >
          <span className="material-symbols-rounded text-[13px]" style={{ fontVariationSettings: "'FILL' 1" }}>
            fitness_center
          </span>
          {admin("chip")}
        </span>
      </div>

      <div className="rounded-[var(--r-lg)] p-4.5" style={{ background: "var(--surface-container)" }}>
        <div className="flex gap-3">
          <div
            className="flex-1 rounded-2xl h-[52px] flex items-center gap-2.5 px-4"
            style={{ background: "var(--bg)", border: `1.5px solid ${error ? "var(--error)" : "var(--outline)"}` }}
          >
            <span className="material-symbols-rounded text-xl" style={{ color: "var(--muted)" }}>
              mail
            </span>
            <input
              type="email"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                setError(null);
              }}
              placeholder={t("emailPlaceholder")}
              className="flex-1 bg-transparent outline-none text-sm"
              style={{ color: "var(--on-surface)" }}
            />
          </div>
          <button
            onClick={() => inviteMutation.mutate()}
            disabled={!email || inviteMutation.isPending}
            className="shrink-0 flex items-center gap-2 rounded-2xl h-[52px] px-6 text-[14.5px] font-extrabold disabled:opacity-50"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            <span className="material-symbols-rounded text-xl">send</span>
            {t("send")}
          </button>
        </div>
        {error && (
          <div className="flex items-center gap-1.5 mt-2.5 pl-1 text-[12.5px] font-semibold" style={{ color: "var(--error)" }}>
            <span className="material-symbols-rounded text-base">error</span>
            {error}
          </div>
        )}
      </div>

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : (
        <>
          <p className="text-[11px] font-bold tracking-wider uppercase mt-2" style={{ color: "var(--on-surface-variant)" }}>
            {t("pendingCount", { count: invites?.length ?? 0 })}
          </p>
          {!invites || invites.length === 0 ? (
            <div className="rounded-2xl p-6 text-center" style={{ background: "var(--surface)" }}>
              <div
                className="w-12 h-12 rounded-2xl flex items-center justify-center mx-auto mb-2.5"
                style={{ background: "var(--surface-container)", color: "var(--tertiary)" }}
              >
                <span className="material-symbols-rounded text-2xl">mark_email_read</span>
              </div>
              <p className="text-sm font-extrabold" style={{ color: "var(--on-surface)" }}>
                {t("emptyTitle")}
              </p>
              <p className="text-xs mt-1" style={{ color: "var(--on-surface-variant)" }}>
                {t("emptyBody")}
              </p>
            </div>
          ) : (
            <div className="flex flex-col gap-2">
              {invites.map((inv) => {
                const urgent = isUrgent(inv.expiresAt);
                return (
                  <div
                    key={inv.id}
                    className="rounded-2xl px-4 py-3.5 flex items-center gap-3.5"
                    style={{ background: "var(--surface)" }}
                  >
                    <div
                      className="w-9 h-9 rounded-full flex items-center justify-center shrink-0"
                      style={{ background: "var(--surface-highest)", color: "var(--on-surface-variant)" }}
                    >
                      <span className="material-symbols-rounded text-lg">hourglass_top</span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-bold truncate" style={{ color: "var(--on-surface)" }}>
                        {inv.clientEmail}
                      </p>
                      <p className="text-[11.5px] mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                        {t("sentAt", { time: formatDistanceToNow(new Date(inv.createdAt), { addSuffix: true, locale: dateLocale }) })}
                      </p>
                    </div>
                    <span
                      className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[11.5px] font-bold px-3 py-1.5"
                      style={{
                        background: urgent ? "var(--error-container)" : "var(--tertiary-container)",
                        color: urgent ? "var(--error)" : "var(--on-tertiary-container)",
                      }}
                    >
                      <span className="material-symbols-rounded text-[15px]">schedule</span>
                      {t("expiresIn", { time: formatDistanceToNow(new Date(inv.expiresAt), { locale: dateLocale }) })}
                    </span>
                    <button
                      onClick={() => revokeMutation.mutate(inv.id)}
                      className="flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-[12.5px] font-bold transition-colors hover:bg-surface-highest"
                      style={{ color: "var(--on-surface-variant)", border: "1px solid var(--outline)" }}
                    >
                      <span className="material-symbols-rounded text-base">close</span>
                      {t("revoke")}
                    </button>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}
    </div>
  );
}
