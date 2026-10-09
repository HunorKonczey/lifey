"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatDistanceToNowStrict } from "date-fns";
import { Avatar, Button, Card, ConfirmModal, Icon, colorForSeed } from "@/components/ds";
import { trainerRequestApi } from "@/features/trainer-requests/api";
import type { SuperAdminTrainerRequestResponse } from "@/features/trainer-requests/types";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useLocale } from "@/lib/hooks/useLocale";
import { DATE_LOCALES, useFormat } from "@/lib/i18n/format";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";

const PAGE_SIZE = 20;

/**
 * Trainer requests (W9-F): a card per request with enough to decide on — who and how long ago, the motivation quoted,
 * the expected client count, how old the account is and where the visitor came from. Rejecting asks first (focus on
 * "Mégse"); approving also asks, since it starts the 14-day trial.
 */
export default function SuperAdminTrainerRequestsPage() {
  const t = useTranslations("superadmin");
  const fmt = useFormat();
  const common = useTranslations("common");
  const locale = useLocale((s) => s.locale);
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [page, setPage] = useState(0);
  const [confirmTarget, setConfirmTarget] = useState<{ request: SuperAdminTrainerRequestResponse; approve: boolean } | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerRequests.pending({ page, size: PAGE_SIZE }),
    queryFn: () => trainerRequestApi.pending({ page, size: PAGE_SIZE }),
  });

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ["trainer-requests", "pending"] });
    queryClient.invalidateQueries({ queryKey: queryKeys.superAdminUsers.stats() });
  };

  const approveMutation = useMutation({
    mutationFn: (id: number) => trainerRequestApi.approve(id),
    onSuccess: () => {
      invalidate();
      show(t("requestApproved"), "success");
    },
    onError: () => show(t("requestApproveFailed"), "error"),
  });

  const rejectMutation = useMutation({
    mutationFn: (id: number) => trainerRequestApi.reject(id),
    onSuccess: () => {
      invalidate();
      show(t("requestRejected"), "success");
    },
    onError: () => show(t("requestRejectFailed"), "error"),
  });

  const ago = (iso: string) => formatDistanceToNowStrict(new Date(iso), { addSuffix: true, locale: DATE_LOCALES[locale] });

  return (
    <div className="flex max-w-3xl flex-col gap-4">
      {data && data.totalElements > 0 && (
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("pendingRequestsBadge", { count: data.totalElements })}</p>
      )}

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : !data || data.content.length === 0 ? (
        <EmptyState icon="how_to_reg" title={t("noPendingRequests")} body={t("noPendingRequestsBody")} />
      ) : (
        <>
          {data.content.map((req) => (
            <Card key={req.id} data-testid="trainer-request-row" data-user-email={req.userEmail} className="flex flex-col gap-4">
              <div className="flex items-center gap-3.5">
                <Avatar email={req.userEmail} size={44} color={colorForSeed(String(req.userId))} />
                <div className="min-w-0 flex-1">
                  <p className="type-body truncate" style={{ fontWeight: 800 }}>{req.userEmail}</p>
                  <p className="type-body-s" style={{ color: "var(--text-3)" }} title={fmt.date(req.createdAt, "dateTime")}>
                    {ago(req.createdAt)}
                  </p>
                </div>
              </div>

              {req.motivation ? (
                <blockquote className="type-body pl-3" style={{ borderLeft: "3px solid var(--role)", color: "var(--text)" }}>
                  {req.motivation}
                </blockquote>
              ) : (
                <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("noMotivation")}</p>
              )}

              <dl className="type-body-s grid grid-cols-[auto_1fr] gap-x-6 gap-y-1.5">
                <dt style={{ color: "var(--text-3)" }}>{t("qualifications")}</dt>
                <dd data-testid="request-qualifications" style={{ fontWeight: 700 }}>{req.qualifications ?? t("notGiven")}</dd>
                <dt style={{ color: "var(--text-3)" }}>{t("expectedClients")}</dt>
                <dd style={{ fontWeight: 700 }}>{req.clientCount != null ? req.clientCount : t("notGiven")}</dd>
                <dt style={{ color: "var(--text-3)" }}>{t("accountLabel")}</dt>
                <dd style={{ fontWeight: 700 }}>{t("accountAge", { date: fmt.date(req.userCreatedAt, "dayYear") })}</dd>
                {req.signupSource && (
                  <>
                    <dt style={{ color: "var(--text-3)" }}>{t("sourceLabel")}</dt>
                    <dd style={{ fontWeight: 700 }}>{req.signupSource}</dd>
                  </>
                )}
              </dl>

              <div className="flex flex-wrap justify-end gap-2.5">
                <Button variant="secondary" onClick={() => setConfirmTarget({ request: req, approve: false })}>
                  <Icon name="close" size={18} />
                  {t("reject")}
                </Button>
                <Button onClick={() => setConfirmTarget({ request: req, approve: true })}>
                  <Icon name="check" size={18} />
                  {t("approve")}
                </Button>
              </div>
            </Card>
          ))}

          {data.totalPages > 1 && (
            <div className="flex items-center justify-center gap-1.5">
              <button
                onClick={() => setPage((p) => Math.max(0, p - 1))}
                disabled={data.number === 0}
                className="lifey-button p-1.5 disabled:opacity-30"
                aria-label={common("previousPage")}
              >
                <Icon name="chevron_left" size={22} />
              </button>
              <span className="type-body-s tabular px-2" style={{ fontWeight: 700 }}>
                {data.number + 1} / {Math.max(1, data.totalPages)}
              </span>
              <button
                onClick={() => setPage((p) => (data.last ? p : p + 1))}
                disabled={data.last}
                className="lifey-button p-1.5 disabled:opacity-30"
                aria-label={common("nextPage")}
              >
                <Icon name="chevron_right" size={22} />
              </button>
            </div>
          )}
        </>
      )}

      <ConfirmModal
        open={confirmTarget !== null}
        onClose={() => setConfirmTarget(null)}
        onConfirm={() => {
          if (!confirmTarget) return;
          if (confirmTarget.approve) approveMutation.mutate(confirmTarget.request.id);
          else rejectMutation.mutate(confirmTarget.request.id);
          setConfirmTarget(null);
        }}
        confirmTestId="trainer-request-confirm-decision"
        icon={confirmTarget?.approve ? "how_to_reg" : "person_off"}
        tint={confirmTarget?.approve ? "var(--role)" : "var(--heart)"}
        destructive={!confirmTarget?.approve}
        title={confirmTarget?.approve ? t("confirmApproveTitle") : t("confirmRejectTitle")}
        body={`${confirmTarget?.request.userEmail ?? ""} ${confirmTarget?.approve ? t("confirmApproveBody") : t("confirmRejectBody")}`}
        cancelLabel={t("cancel")}
        confirmLabel={confirmTarget?.approve ? t("confirmApproveConfirm") : t("confirmRejectConfirm")}
      />
    </div>
  );
}
