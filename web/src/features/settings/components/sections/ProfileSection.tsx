"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ds";
import { Skeleton } from "@/components/status/Skeleton";
import { userDetailsApi } from "@/features/onboarding/api";
import { useSessionStore } from "@/features/auth/store";
import { queryKeys } from "@/lib/api/queryKeys";
import { ApiError } from "@/lib/api/client";
import { AvatarUploader } from "../AvatarUploader";
import { ProfileDrawer } from "../ProfileDrawer";
import { SettingsSection } from "../SettingsSection";
import type { UnitSystem } from "../../types";

/** Profile (W6-G): the avatar uploader, name, "e-mail · role" and the body-and-goals editor in a drawer. */
export function ProfileSection({ unitSystem }: { unitSystem: UnitSystem }) {
  const t = useTranslations("settings");
  const router = useRouter();
  const { user } = useSessionStore();
  const [editing, setEditing] = useState(false);

  const { data: details, error } = useQuery({ queryKey: queryKeys.userDetails.all(), queryFn: userDetailsApi.get, retry: false });
  const notOnboarded = error instanceof ApiError && error.status === 404;

  const name = user?.firstName && user?.lastName ? `${user.firstName} ${user.lastName}` : null;
  // Never the raw ROLE_USER: an unknown role falls back to its own name without the prefix.
  const roles = user?.roles.map((r) => (t.has(`roleNames.${r}`) ? t(`roleNames.${r}`) : r.replace(/^ROLE_/, ""))).join(", ");

  return (
    <SettingsSection
      id="settings-profile"
      title={t("profile")}
      action={
        details && (
          <Button variant="secondary" onClick={() => setEditing(true)}>
            {t("editProfile")}
          </Button>
        )
      }
    >
      <AvatarUploader />
      <div className="flex flex-col gap-0.5">
        <span style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-0.01em" }}>{name ?? "—"}</span>
        <span className="type-body-s" style={{ color: "var(--text-2)" }}>
          {[user?.email, roles].filter(Boolean).join(" · ") || "—"}
        </span>
      </div>
      {notOnboarded && (
        <div className="flex flex-col items-start gap-3">
          <p className="type-body" style={{ color: "var(--text-2)" }}>{t("onboardingNotDone")}</p>
          <Button onClick={() => router.push("/onboarding")}>{t("startOnboarding")}</Button>
        </div>
      )}
      {!notOnboarded && !details && <Skeleton variant="text" />}
      {editing && details && <ProfileDrawer details={details} unitSystem={unitSystem} onClose={() => setEditing(false)} />}
    </SettingsSection>
  );
}
