"use client";

import { useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { Skeleton } from "@/components/status/Skeleton";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/i18n/format";
import { superAdminApi } from "../api";

/** One user's role changes (existing `role-audit` endpoint) in a drawer — restyled as a timeline in W9.9. */
export function RoleHistoryDrawer({ userId, email, onClose }: { userId: number; email: string; onClose: () => void }) {
  const t = useTranslations("superadmin");
  const fmt = useFormat();
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.superAdminUsers.roleAudit(userId),
    queryFn: () => superAdminApi.roleAudit(userId),
  });

  return (
    <Drawer open onClose={onClose} width={480} overline={email} title={t("auditHistory")}>
      {isLoading ? (
        <Skeleton variant="text" />
      ) : !data || data.length === 0 ? (
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("noAuditHistory")}</p>
      ) : (
        <ul className="flex flex-col gap-3">
          {data.map((entry) => (
            <li key={entry.id} className="type-body-s flex items-center gap-3">
              <span className="tabular" style={{ color: "var(--text-3)" }}>{fmt.date(entry.createdAt, "dateTime")}</span>
              <span style={{ fontWeight: 700 }}>{entry.action} {entry.role}</span>
            </li>
          ))}
        </ul>
      )}
    </Drawer>
  );
}
