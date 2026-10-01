"use client";

import { useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { Skeleton } from "@/components/status/Skeleton";
import { queryKeys } from "@/lib/api/queryKeys";
import { superAdminApi } from "../api";
import { personLabel } from "../userRoles";
import { RoleHistoryTimeline } from "./RoleHistoryTimeline";

/** One user's role changes (the `role-audit` endpoint) as the timeline, newest first; the actor is the profile name when there is one, else the e-mail. */
export function RoleHistoryDrawer({ userId, name, email, onClose }: { userId: number; name?: string | null; email: string; onClose: () => void }) {
  const t = useTranslations("superadmin");
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.superAdminUsers.roleAudit(userId),
    queryFn: () => superAdminApi.roleAudit(userId),
  });

  return (
    <Drawer open onClose={onClose} width={480} overline={personLabel(name, email) ?? email} title={t("auditHistory")}>
      {isLoading ? (
        <Skeleton variant="text" />
      ) : !data || data.length === 0 ? (
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("noAuditHistory")}</p>
      ) : (
        <RoleHistoryTimeline entries={[...data].sort((a, b) => b.createdAt.localeCompare(a.createdAt))} />
      )}
    </Drawer>
  );
}
