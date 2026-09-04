"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { trainerRequestApi } from "@/features/trainer-requests/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import type { SuperAdminTrainerRequestResponse } from "@/features/trainer-requests/types";

const PAGE_SIZE = 20;

export default function SuperAdminTrainerRequestsPage() {
  const t = useTranslations("superadmin");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [page, setPage] = useState(0);
  const [confirmTarget, setConfirmTarget] = useState<{
    request: SuperAdminTrainerRequestResponse;
    approve: boolean;
  } | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerRequests.pending({ page, size: PAGE_SIZE }),
    queryFn: () => trainerRequestApi.pending({ page, size: PAGE_SIZE }),
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["trainer-requests", "pending"] });

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

  return (
    <div className="flex flex-col gap-3.5 max-w-4xl mx-auto">
      <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
        {t("trainerRequestsTitle")}
      </p>

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : !data || data.content.length === 0 ? (
        <p className="text-sm text-center py-10" style={{ color: "var(--on-surface-variant)" }}>
          {t("noPendingRequests")}
        </p>
      ) : (
        <>
          <div className="rounded-[var(--r-lg)] p-2 flex flex-col gap-1" style={{ background: "var(--surface)" }}>
            {data.content.map((req) => (
              <div
                key={req.id}
                data-testid="trainer-request-row"
                data-user-email={req.userEmail}
                className="rounded-[13px] px-3.5 py-3 flex flex-col gap-2"
              >
                <div className="flex items-center gap-3.5">
                  <div
                    className="w-9 h-9 rounded-full flex items-center justify-center shrink-0 text-sm font-extrabold"
                    style={{ background: "var(--tertiary)", color: "var(--bg)" }}
                  >
                    {req.userEmail.charAt(0).toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                      {req.userEmail}
                    </p>
                    <p className="text-[11px] font-mono" style={{ color: "var(--on-surface-variant)" }}>
                      {format(new Date(req.createdAt), "yyyy-MM-dd HH:mm")}
                      {req.signupSource ? ` · ${req.signupSource}` : ""}
                    </p>
                  </div>
                  {req.clientCount != null && (
                    <span
                      className="shrink-0 rounded-[var(--r-pill)] text-[10.5px] font-extrabold tracking-wide px-2.5 py-1"
                      style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
                    >
                      {t("clientCountBadge", { count: req.clientCount })}
                    </span>
                  )}
                  <div className="flex gap-1.5 shrink-0">
                    <button
                      onClick={() => setConfirmTarget({ request: req, approve: false })}
                      className="flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-extrabold"
                      style={{ border: "1.5px solid rgba(207,102,121,.5)", color: "var(--error)" }}
                    >
                      <span className="material-symbols-rounded text-base">close</span>
                      {t("reject")}
                    </button>
                    <button
                      onClick={() => setConfirmTarget({ request: req, approve: true })}
                      className="flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-extrabold"
                      style={{ background: "var(--primary)", color: "var(--bg)" }}
                    >
                      <span className="material-symbols-rounded text-base">check</span>
                      {t("approve")}
                    </button>
                  </div>
                </div>
                {req.motivation && (
                  <p
                    className="pl-[47px] text-[12.5px] leading-relaxed"
                    style={{ color: "var(--on-surface-variant)" }}
                  >
                    {req.motivation}
                  </p>
                )}
              </div>
            ))}
          </div>

          <div className="flex items-center justify-center gap-1.5">
            <button
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              disabled={data.number === 0}
              className="p-1.5 disabled:opacity-30"
              style={{ color: "var(--on-surface-variant)" }}
              aria-label={common("previousPage")}
            >
              <span className="material-symbols-rounded text-xl">chevron_left</span>
            </button>
            <span className="text-xs font-bold px-2" style={{ color: "var(--on-surface-variant)" }}>
              {data.number + 1} / {Math.max(1, data.totalPages)}
            </span>
            <button
              onClick={() => setPage((p) => (data.last ? p : p + 1))}
              disabled={data.last}
              className="p-1.5 disabled:opacity-30"
              style={{ color: "var(--on-surface-variant)" }}
              aria-label={common("nextPage")}
            >
              <span className="material-symbols-rounded text-xl">chevron_right</span>
            </button>
          </div>
        </>
      )}

      {confirmTarget && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4"
          style={{ background: "rgba(8,9,6,.6)" }}
          onClick={() => setConfirmTarget(null)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-md rounded-[var(--r-lg)] p-5.5"
            style={{ background: "var(--surface-container)", boxShadow: "0 18px 44px rgba(0,0,0,.4)" }}
          >
            <p className="text-base font-extrabold mb-1.5" style={{ color: "var(--on-surface)" }}>
              {confirmTarget.approve ? t("confirmApproveTitle") : t("confirmRejectTitle")}
            </p>
            <p className="text-[12.5px] leading-relaxed mb-4.5" style={{ color: "var(--on-surface-variant)" }}>
              <span style={{ color: "var(--on-surface)", fontWeight: 800 }}>{confirmTarget.request.userEmail}</span>{" "}
              {confirmTarget.approve ? t("confirmApproveBody") : t("confirmRejectBody")}
            </p>
            <div className="flex gap-2.5 justify-end">
              <button
                onClick={() => setConfirmTarget(null)}
                className="text-sm font-bold px-4 py-2.5"
                style={{ color: "var(--on-surface-variant)" }}
              >
                {t("cancel")}
              </button>
              <button
                data-testid="trainer-request-confirm-decision"
                onClick={() => {
                  if (confirmTarget.approve) approveMutation.mutate(confirmTarget.request.id);
                  else rejectMutation.mutate(confirmTarget.request.id);
                  setConfirmTarget(null);
                }}
                className="rounded-xl px-4.5 py-2.5 text-sm font-extrabold"
                style={{
                  background: confirmTarget.approve ? "var(--primary)" : "var(--error)",
                  color: "#161611",
                }}
              >
                {confirmTarget.approve ? t("confirmApproveConfirm") : t("confirmRejectConfirm")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
