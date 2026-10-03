"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatDistanceToNow } from "date-fns";
import { Button, Card, ConfirmModal, Icon, TextField, TintedChip } from "@/components/ds";
import { trainerApi } from "@/features/trainer/api";
import { canResend, historyRows, inviteStatus, inviteUrgent, outcomeAt } from "@/features/trainer/invites";
import { queryKeys, invalidationMap } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useLocale } from "@/lib/hooks/useLocale";
import { DATE_LOCALES } from "@/lib/i18n/format";
import { ApiError } from "@/lib/api/client";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { useTrainerBillingGate } from "@/features/billing/hooks";
import { BillingBlockedDialog } from "@/features/billing/components/BillingBlockedDialog";
import type { InviteOutcome, TrainerInviteResponse } from "@/features/trainer/types";

/**
 * Invites with their state (W9-B): a "Kliens meghívása" card (e-mail + Küldés), then a row per invite — the e-mail, "3 napja
 * küldve", a status chip (Függő carbs tint · Lejárt neutral, from `expiresAt`) and the next step: "Visszavonás…" behind a
 * confirmation for a pending one, "Újraküldés" (a fresh invite to the same e-mail) for one that has run out. Below the live list
 * the **history** (docs/redesign-web/82 S2): every invite that has an outcome — elfogadva, elutasítva, visszavonva, lejárt — newest
 * first, "Továbbiak" for more. There is still no shareable link (D-W0.19).
 */
const HISTORY_PAGE = 20;

/** Icon, chip colour and label key of an outcome row. */
const OUTCOME_LOOK: Record<Exclude<InviteOutcome, "PENDING">, { icon: string; color: string; label: string; at: string }> = {
  ACCEPTED: { icon: "check_circle", color: "var(--primary)", label: "outcomeAccepted", at: "outcomeAcceptedAt" },
  DECLINED: { icon: "cancel", color: "var(--text-2)", label: "outcomeDeclined", at: "outcomeDeclinedAt" },
  CANCELLED: { icon: "mail_off", color: "var(--text-2)", label: "outcomeCancelled", at: "outcomeCancelledAt" },
  EXPIRED: { icon: "schedule", color: "var(--text-2)", label: "outcomeExpired", at: "outcomeExpiredAt" },
};
export default function AdminInvitesPage() {
  const t = useTranslations("admin.invites");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const locale = useLocale((s) => s.locale);
  const dateLocale = DATE_LOCALES[locale];
  const [email, setEmail] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [blockedOpen, setBlockedOpen] = useState(false);
  const [revoking, setRevoking] = useState<TrainerInviteResponse | null>(null);
  const gate = useTrainerBillingGate();
  // Re-read the clock so an invite that runs out while the page is open flips to "Lejárt".
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(timer);
  }, []);

  const { data: invites, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerInvites.all(),
    queryFn: trainerApi.pendingInvites,
  });

  const [historySize, setHistorySize] = useState(HISTORY_PAGE);
  const { data: history } = useQuery({
    queryKey: queryKeys.trainerInvites.history(historySize),
    queryFn: () => trainerApi.inviteHistory({ size: historySize }),
    placeholderData: keepPreviousData,
  });
  const pastInvites = historyRows(history?.content ?? []);

  const refresh = () => invalidationMap.trainerInvite.forEach((key) => queryClient.invalidateQueries({ queryKey: key }));

  const inviteMutation = useMutation({
    mutationFn: (to: string) => trainerApi.invite({ email: to }),
    onSuccess: (_, to) => {
      // Pending invites count toward the seat limit (64 §4.3), so sending one can push the trainer's
      // entitlement into OVER_LIMIT — the seat meter must never show a stale count.
      refresh();
      show(t("sent"), "success");
      if (to === email) setEmail("");
      setError(null);
    },
    onError: (err) => {
      const message =
        err instanceof ApiError && err.status === 404
          ? t("errorNotFound")
          : err instanceof ApiError && err.status === 409
            ? t("errorAlreadyClient")
            : err instanceof ApiError && err.status === 429
              ? t("errorRateLimited")
              : t("errorGeneric");
      setError(message);
      show(message, "error");
    },
  });

  const revokeMutation = useMutation({
    mutationFn: (id: number) => trainerApi.cancelInvite(id),
    onSuccess: () => {
      refresh();
      show(t("revoked"), "success");
      setRevoking(null);
    },
    onError: () => show(t("revokeFailed"), "error"),
  });

  // D-T5: a blocked "Send" stays clickable and explains itself, rather than silently disabling.
  const send = (to: string) => {
    if (gate.state !== "OK") {
      setBlockedOpen(true);
      return;
    }
    inviteMutation.mutate(to);
  };


  return (
    <div className="flex max-w-2xl flex-col gap-5">
      <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("subtitle")}</p>

      <Card className="flex flex-col gap-3">
        <h3 className="type-body" style={{ fontWeight: 800 }}>{t("cardTitle")}</h3>
        <form
          className="flex items-start gap-3"
          onSubmit={(e) => {
            e.preventDefault();
            if (email.trim()) send(email.trim());
          }}
        >
          <TextField
            className="flex-1"
            type="email"
            leadingIcon="mail"
            value={email}
            onChange={(e) => {
              setEmail(e.target.value);
              setError(null);
            }}
            placeholder={t("emailPlaceholder")}
            aria-label={t("emailPlaceholder")}
            error={error ?? undefined}
          />
          <Button type="submit" disabled={!email.trim() || inviteMutation.isPending}>
            <Icon name="send" size={20} />
            {t("send")}
          </Button>
        </form>
      </Card>

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : !invites || invites.length === 0 ? (
        <EmptyState icon="mark_email_read" title={t("emptyTitle")} body={t("emptyBody")} />
      ) : (
        <section aria-label={t("pendingCount", { count: invites.length })} className="flex flex-col gap-2">
          <p className="type-overline" style={{ color: "var(--text-3)" }}>{t("pendingCount", { count: invites.length })}</p>
          <ul className="flex flex-col gap-2">
            {invites.map((inv) => {
              const status = inviteStatus(inv.expiresAt, now);
              const urgent = inviteUrgent(inv.expiresAt, now);
              return (
                <li key={inv.id} data-testid="invite-row">
                  <Card className="flex flex-wrap items-center gap-x-4 gap-y-2 !py-3">
                    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full" style={{ background: "var(--nested)" }}>
                      <Icon name={status === "PENDING" ? "hourglass_top" : "schedule"} size={18} color="var(--text-2)" />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="type-body block truncate" style={{ fontWeight: 700 }}>{inv.clientEmail}</span>
                      <span className="type-body-s block" style={{ color: urgent ? "var(--heart)" : "var(--text-3)" }}>
                        {t("sentAt", { time: formatDistanceToNow(new Date(inv.createdAt), { addSuffix: true, locale: dateLocale }) })}
                        {status === "PENDING" && ` · ${t("expiresIn", { time: formatDistanceToNow(new Date(inv.expiresAt), { locale: dateLocale }) })}`}
                      </span>
                    </span>
                    <TintedChip label={t(status === "PENDING" ? "statusPending" : "statusExpired")} color={status === "PENDING" ? "var(--m-carbs)" : "var(--text-2)"} />
                    {status === "PENDING" ? (
                      <Button variant="secondary" onClick={() => setRevoking(inv)}>{t("revoke")}</Button>
                    ) : (
                      <Button variant="secondary" onClick={() => send(inv.clientEmail)} disabled={inviteMutation.isPending}>{t("resend")}</Button>
                    )}
                  </Card>
                </li>
              );
            })}
          </ul>
        </section>
      )}

      {pastInvites.length > 0 && (
        <section aria-label={t("historyTitle", { count: history?.totalElements ?? pastInvites.length })} className="flex flex-col gap-2">
          <p className="type-overline" style={{ color: "var(--text-3)" }}>
            {t("historyTitle", { count: history?.totalElements ?? pastInvites.length })}
          </p>
          <ul className="flex flex-col gap-2">
            {pastInvites.map((row) => {
              const look = OUTCOME_LOOK[row.outcome as Exclude<InviteOutcome, "PENDING">];
              const ago = (iso: string) => formatDistanceToNow(new Date(iso), { addSuffix: true, locale: dateLocale });
              return (
                <li key={row.id} data-testid="invite-history-row" data-outcome={row.outcome}>
                  <Card className="flex flex-wrap items-center gap-x-4 gap-y-2 !py-3">
                    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full" style={{ background: "var(--nested)" }}>
                      <Icon name={look.icon} size={18} color={look.color} />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="type-body block truncate" style={{ fontWeight: 700 }}>{row.clientEmail}</span>
                      <span className="type-body-s block" style={{ color: "var(--text-3)" }}>
                        {t("sentAt", { time: ago(row.createdAt) })}
                        {` · ${t(look.at, { time: ago(outcomeAt(row)) })}`}
                        {row.outcome === "ACCEPTED" && row.endedAt && ` · ${t("relationshipEndedAt", { time: ago(row.endedAt) })}`}
                      </span>
                    </span>
                    <TintedChip label={t(look.label)} color={look.color} />
                    {canResend(row.outcome) && (
                      <Button variant="secondary" onClick={() => send(row.clientEmail)} disabled={inviteMutation.isPending}>{t("resend")}</Button>
                    )}
                  </Card>
                </li>
              );
            })}
          </ul>
          {history && history.totalElements > historySize && (
            <div>
              <Button variant="secondary" onClick={() => setHistorySize((size) => size + HISTORY_PAGE)}>{t("showMore")}</Button>
            </div>
          )}
        </section>
      )}

      <ConfirmModal
        open={revoking !== null}
        onClose={() => setRevoking(null)}
        onConfirm={() => revoking && revokeMutation.mutate(revoking.id)}
        icon="mail_off"
        title={t("revokeConfirmTitle")}
        body={t("revokeConfirmBody", { email: revoking?.clientEmail ?? "" })}
        cancelLabel={t("cancel")}
        confirmLabel={t("revokeConfirm")}
      />

      <BillingBlockedDialog
        open={blockedOpen}
        onClose={() => setBlockedOpen(false)}
        reason={gate.state === "RESTRICTED" ? "restricted" : "overLimit"}
        currentPlan={gate.currentPlan}
        activeClients={gate.activeClients}
        maxClients={gate.maxClients}
      />
    </div>
  );
}
