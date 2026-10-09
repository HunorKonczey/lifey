"use client";

import { useEffect } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery } from "@tanstack/react-query";
import { Button, Icon } from "@/components/ds";
import { Skeleton } from "@/components/status/Skeleton";
import { withNext } from "@/features/auth/nextPath";
import { useSessionStore } from "@/features/auth/store";
import { trainerApi } from "@/features/trainer/api";
import { ApiError } from "@/lib/api/client";
import { useToast } from "@/lib/hooks/useToast";

/**
 * The landing page of a trainer's shareable join link (LIF-103). The preview is public, so it says who is inviting before
 * anyone has an account; signing in or registering brings the visitor back here (`?next=`), where one tap makes them
 * the trainer's client. A link that was used, withdrawn or has run out is one dead end, whatever the reason.
 */
export default function JoinPage() {
  const t = useTranslations("join");
  const router = useRouter();
  const { show } = useToast();
  const { token } = useParams<{ token: string }>();
  const { user, isLoading: sessionLoading, initialize } = useSessionStore();

  useEffect(() => {
    initialize();
  }, [initialize]);

  const preview = useQuery({
    queryKey: ["invite-link-preview", token],
    queryFn: () => trainerApi.inviteLinkPreview(token),
    retry: false,
  });

  const accept = useMutation({
    mutationFn: () => trainerApi.acceptInviteLink(token),
    onSuccess: () => {
      show(t("joined", { name: preview.data?.trainerName ?? "" }), "success");
      router.push("/dashboard");
    },
  });

  const here = `/join/${token}`;

  if (preview.isLoading || sessionLoading) return <Skeleton variant="card" className="h-72" />;

  if (preview.isError || !preview.data) {
    return (
      <div className="flex flex-col gap-4" data-testid="join-invalid">
        <Icon name="link_off" size={40} color="var(--text-3)" />
        <h1 style={{ fontSize: 28, lineHeight: 1.15, fontWeight: 800 }}>{t("invalidTitle")}</h1>
        <p style={{ color: "var(--text-2)" }}>{t("invalidBody")}</p>
      </div>
    );
  }

  const name = preview.data.trainerName;
  const error = accept.error;
  const errorText =
    error instanceof ApiError
      ? error.status === 409
        ? t("errorConflict")
        : error.status === 400
          ? t("errorOwn")
          : error.status === 404
            ? t("invalidTitle")
            : t("errorGeneric")
      : error
        ? t("errorGeneric")
        : null;

  return (
    <div className="flex flex-col gap-5" data-testid="join-page">
      <div className="flex flex-col gap-2">
        <h1 style={{ fontSize: 30, lineHeight: 1.15, fontWeight: 800, letterSpacing: "-0.02em" }}>{t("title", { name })}</h1>
        <p style={{ fontSize: 16, lineHeight: 1.5, color: "var(--text-2)" }}>{t("subtitle")}</p>
      </div>

      {user ? (
        <>
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("share")}</p>
          {errorText && (
            <p role="alert" data-testid="join-error" className="type-body-s" style={{ color: "var(--heart)", fontWeight: 600 }}>
              {errorText}
            </p>
          )}
          <div className="flex flex-col gap-3">
            <Button size="auth" fullWidth disabled={accept.isPending} onClick={() => accept.mutate()} data-testid="join-accept">
              {accept.isPending ? t("accepting") : t("accept", { name })}
            </Button>
            <Link href="/dashboard" className="text-center type-body" style={{ color: "var(--text-2)", fontWeight: 700 }}>
              {t("notNow")}
            </Link>
          </div>
        </>
      ) : (
        <>
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("signInPrompt")}</p>
          <div className="flex flex-col gap-3">
            <Link href={withNext("/login", here)} data-testid="join-sign-in">
              <Button size="auth" fullWidth>{t("signIn")}</Button>
            </Link>
            <Link href={withNext("/register", here)} data-testid="join-sign-up">
              <Button size="auth" fullWidth variant="secondary">{t("signUp")}</Button>
            </Link>
          </div>
        </>
      )}
    </div>
  );
}
