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
import { Button, Card, Icon, TextArea, TextField, TintedChip } from "@/components/ds";
import { LifeyLogo } from "@/features/auth/components/BrandPanel";
import { TrainerSignupStepper } from "@/features/auth/components/TrainerSignupStepper";
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
  const [qualifications, setQualifications] = useState("");
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
        qualifications: qualifications.trim() || undefined,
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
      <div className="flex min-h-screen items-center justify-center" style={{ background: "var(--bg)" }}>
        <LifeyLogo size={40} />
      </div>
    );
  }

  if (isError && !notFound) {
    return (
      <div className="flex min-h-screen items-center justify-center px-4" style={{ background: "var(--bg)" }}>
        <ErrorState onRetry={refetch} />
      </div>
    );
  }

  const isApproved = request?.status === "APPROVED";
  const showForm = notFound || request?.status === "REJECTED";
  const showWaiting = request?.status === "PENDING" || isApproved;

  // Focus mode (W9.6): no sidebar, no top bar — the logo, the trainer stepper at step 2 and one card.
  return (
    <div className="flex min-h-screen flex-col items-center gap-6 px-4 py-10" style={{ background: "var(--bg)" }}>
      <LifeyLogo size={40} />
      <TrainerSignupStepper current={2} />
      <Card variant="hero" className="w-full max-w-md">
        {showWaiting ? (
          <WaitingState redirecting={isApproved} t={t} />
        ) : showForm ? (
          <RequestForm
            t={t}
            motivation={motivation}
            qualifications={qualifications}
            clientCount={clientCount}
            error={formError}
            submitting={submitMutation.isPending}
            wasRejected={request?.status === "REJECTED"}
            onMotivationChange={(v) => {
              setMotivation(v);
              setFormError(null);
            }}
            onQualificationsChange={(v) => {
              setQualifications(v);
              setFormError(null);
            }}
            onClientCountChange={(v) => {
              setClientCount(v);
              setFormError(null);
            }}
            onSubmit={() => submitMutation.mutate()}
          />
        ) : null}
      </Card>
    </div>
  );
}

function WaitingState({ redirecting, t }: { redirecting: boolean; t: ReturnType<typeof useTranslations> }) {
  return (
    <div className="flex flex-col items-center gap-3 text-center" data-testid="trainer-request-status">
      <span className="flex h-14 w-14 items-center justify-center rounded-full" style={{ background: "var(--role-tint)" }}>
        <Icon name={redirecting ? "check_circle" : "hourglass_top"} size={28} fill={1} color="var(--role)" />
      </span>
      <TintedChip label={redirecting ? t("statusApproved") : t("statusPending")} color={redirecting ? "var(--primary)" : "var(--m-carbs)"} />
      <h1 className="type-title">{redirecting ? t("approvedTitle") : t("pendingTitle")}</h1>
      <p className="type-body" style={{ color: "var(--text-2)" }}>
        {redirecting ? t("approvedBody") : t("pendingBody")}
      </p>
    </div>
  );
}

function RequestForm({
  t,
  motivation,
  qualifications,
  clientCount,
  error,
  submitting,
  wasRejected,
  onMotivationChange,
  onQualificationsChange,
  onClientCountChange,
  onSubmit,
}: {
  t: ReturnType<typeof useTranslations>;
  motivation: string;
  qualifications: string;
  clientCount: string;
  error: string | null;
  submitting: boolean;
  wasRejected: boolean;
  onMotivationChange: (v: string) => void;
  onQualificationsChange: (v: string) => void;
  onClientCountChange: (v: string) => void;
  onSubmit: () => void;
}) {
  return (
    <div className="flex flex-col gap-5">
      <div>
        <h1 className="type-title">{t("title")}</h1>
        <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }}>{t("formIntro")}</p>
      </div>

      {wasRejected && (
        <Card variant="nested">
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("rejectedNote")}</p>
        </Card>
      )}

      <form
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit();
        }}
        className="flex flex-col gap-4"
      >
        <TextArea
          label={t("motivationLabel")}
          value={motivation}
          onChange={(e) => onMotivationChange(e.target.value)}
          placeholder={t("motivationPlaceholder")}
          rows={4}
        />
        <TextArea
          label={t("qualificationsLabel")}
          value={qualifications}
          onChange={(e) => onQualificationsChange(e.target.value)}
          placeholder={t("qualificationsPlaceholder")}
          rows={2}
          maxLength={500}
        />
        <TextField
          label={t("clientCountLabel")}
          type="number"
          min={1}
          value={clientCount}
          onChange={(e) => onClientCountChange(e.target.value)}
          placeholder={t("clientCountPlaceholder")}
        />
        {error && (
          <p className="type-body-s" role="alert" style={{ color: "var(--heart)" }}>{error}</p>
        )}
        <Button type="submit" disabled={submitting} fullWidth>
          {submitting ? t("submitting") : t("submit")}
        </Button>
      </form>
    </div>
  );
}
