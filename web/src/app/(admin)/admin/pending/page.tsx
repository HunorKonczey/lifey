"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { trainerRequestApi } from "@/features/trainer-requests/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useSessionStore } from "@/features/auth/store";
import { ApiError } from "@/lib/api/client";
import { extractAttribution, readAttributionCookie } from "@/lib/attribution";
import { ErrorState } from "@/components/status/ErrorState";

// Fixed-interval polling (matches the chat feature's own precedent,
// features/chat/hooks.ts) — the doc's backing-off 1s->30s poll (D-T3) is a
// different, not-yet-built pattern for the billing checkout flow (`66`
// Prompt 6); this page's wait is measured in hours, not seconds, so a plain
// fixed interval is the right amount of machinery here.
const POLL_INTERVAL_MS = 10_000;

function currentSignupSource(): string | undefined {
  return readAttributionCookie(document.cookie) ?? extractAttribution(window.location.search) ?? undefined;
}

export default function AdminPendingPage() {
  const t = useTranslations("trainerRequest");
  const router = useRouter();
  const queryClient = useQueryClient();
  const refreshUser = useSessionStore((s) => s.refreshUser);
  const [motivation, setMotivation] = useState("");
  const [clientCount, setClientCount] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  // A ref, not state: this only guards against re-triggering the async
  // refresh+redirect below, and doesn't need to cause a re-render itself —
  // request?.status === "APPROVED" already drives what's shown.
  const hasStartedRedirect = useRef(false);

  const { data: request, isLoading, isError, error, refetch } = useQuery({
    queryKey: queryKeys.trainerRequests.mine(),
    queryFn: trainerRequestApi.me,
    retry: false,
    refetchInterval: (query) => (query.state.data?.status === "PENDING" ? POLL_INTERVAL_MS : false),
  });

  const notFound = error instanceof ApiError && error.status === 404;

  const submitMutation = useMutation({
    mutationFn: () =>
      trainerRequestApi.create({
        motivation: motivation.trim() || undefined,
        clientCount: clientCount ? Number(clientCount) : undefined,
        signupSource: currentSignupSource(),
      }),
    onSuccess: (created) => {
      queryClient.setQueryData(queryKeys.trainerRequests.mine(), created);
      setFormError(null);
    },
    onError: (err) => {
      if (err instanceof ApiError && err.status === 409) {
        setFormError(t("errorAlreadyOpen"));
        return;
      }
      setFormError(t("errorGeneric"));
    },
  });

  // 66 §2: approval doesn't retroactively update an already-issued JWT — the
  // access token needs to be re-exchanged before /admin's own ROLE_TRAINER
  // guard will let this browser through.
  useEffect(() => {
    if (request?.status !== "APPROVED" || hasStartedRedirect.current) return;
    hasStartedRedirect.current = true;
    refreshUser().finally(() => router.push("/admin"));
  }, [request?.status, refreshUser, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg">
        <span
          className="material-symbols-rounded text-4xl animate-pulse"
          style={{ color: "var(--tertiary)" }}
        >
          eco
        </span>
      </div>
    );
  }

  if (isError && !notFound) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg px-4">
        <ErrorState onRetry={refetch} />
      </div>
    );
  }

  const isApproved = request?.status === "APPROVED";
  const showForm = notFound || request?.status === "REJECTED";
  const showWaiting = request?.status === "PENDING" || isApproved;

  return (
    <div className="min-h-screen flex items-center justify-center bg-bg px-4 py-12">
      <div className="w-full max-w-md rounded-[var(--r-lg)] p-8" style={{ background: "var(--surface)" }}>
        <div className="flex items-center gap-2 mb-6">
          <span
            className="material-symbols-rounded text-3xl"
            style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}
          >
            eco
          </span>
          <span className="text-xl font-bold tracking-tight">Lifey</span>
        </div>

        {showWaiting ? (
          <WaitingState redirecting={isApproved} t={t} />
        ) : showForm ? (
          <RequestForm
            t={t}
            motivation={motivation}
            clientCount={clientCount}
            error={formError}
            submitting={submitMutation.isPending}
            wasRejected={request?.status === "REJECTED"}
            onMotivationChange={(v) => {
              setMotivation(v);
              setFormError(null);
            }}
            onClientCountChange={(v) => {
              setClientCount(v);
              setFormError(null);
            }}
            onSubmit={() => submitMutation.mutate()}
          />
        ) : null}
      </div>
    </div>
  );
}

function WaitingState({
  redirecting,
  t,
}: {
  redirecting: boolean;
  t: ReturnType<typeof useTranslations>;
}) {
  return (
    <div className="flex flex-col items-center text-center gap-3">
      <div
        className="w-14 h-14 rounded-full flex items-center justify-center"
        style={{ background: "var(--surface-container)", color: "var(--tertiary)" }}
      >
        <span className="material-symbols-rounded text-2xl animate-pulse">hourglass_top</span>
      </div>
      <p className="text-lg font-extrabold" style={{ color: "var(--on-surface)" }}>
        {redirecting ? t("approvedTitle") : t("pendingTitle")}
      </p>
      <p className="text-sm leading-relaxed" style={{ color: "var(--on-surface-variant)" }}>
        {redirecting ? t("approvedBody") : t("pendingBody")}
      </p>
    </div>
  );
}

function RequestForm({
  t,
  motivation,
  clientCount,
  error,
  submitting,
  wasRejected,
  onMotivationChange,
  onClientCountChange,
  onSubmit,
}: {
  t: ReturnType<typeof useTranslations>;
  motivation: string;
  clientCount: string;
  error: string | null;
  submitting: boolean;
  wasRejected: boolean;
  onMotivationChange: (v: string) => void;
  onClientCountChange: (v: string) => void;
  onSubmit: () => void;
}) {
  return (
    <>
      <h1 className="text-2xl font-bold mb-1">{t("title")}</h1>
      <p className="text-sm mb-6" style={{ color: "var(--on-surface-variant)" }}>
        {t("formIntro")}
      </p>

      {wasRejected && (
        <div
          className="mb-5 px-3.5 py-2.5 rounded-[var(--r-card)] text-sm"
          style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
        >
          {t("rejectedNote")}
        </div>
      )}

      <form
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit();
        }}
        className="flex flex-col gap-4"
      >
        <div className="flex flex-col gap-1">
          <label className="text-sm font-semibold">{t("motivationLabel")}</label>
          <textarea
            value={motivation}
            onChange={(e) => onMotivationChange(e.target.value)}
            placeholder={t("motivationPlaceholder")}
            rows={4}
            className="rounded-[var(--r-input)] px-3 py-2.5 text-sm bg-transparent outline-none resize-none"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
            data-ring-frame
          />
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-sm font-semibold">{t("clientCountLabel")}</label>
          <input
            type="number"
            min={1}
            value={clientCount}
            onChange={(e) => onClientCountChange(e.target.value)}
            placeholder={t("clientCountPlaceholder")}
            className="rounded-[var(--r-input)] h-11 px-3 text-sm bg-transparent outline-none"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
            data-ring-frame
          />
        </div>

        {error && (
          <p className="text-xs" style={{ color: "var(--error)" }}>
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={submitting}
          className="mt-2 h-11 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
          style={{ background: "var(--primary)", color: "#1E1F18" }}
        >
          {submitting ? t("submitting") : t("submit")}
        </button>
      </form>
    </>
  );
}
