"use client";

import { useState } from "react";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Card, Icon } from "@/components/ds";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { superAdminApi } from "@/features/superadmin/api";
import { RoleHistoryTimeline } from "@/features/superadmin/components/RoleHistoryTimeline";
import { queryKeys } from "@/lib/api/queryKeys";

const PAGE_SIZE = 30;

/** Role history (W9-G, W9.b3): every trainer grant and revoke across all users, newest first, as the same icon timeline the per-user drawer uses. */
export default function SuperAdminRoleHistoryPage() {
  const t = useTranslations("superadmin");
  const common = useTranslations("common");
  const [page, setPage] = useState(0);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.superAdminUsers.globalAudit({ page, size: PAGE_SIZE }),
    queryFn: () => superAdminApi.globalRoleAudit({ page, size: PAGE_SIZE }),
    placeholderData: keepPreviousData,
  });

  return (
    <div className="flex max-w-2xl flex-col gap-4">
      <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("roleHistorySubtitle")}</p>

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : !data || data.content.length === 0 ? (
        <EmptyState icon="history" title={t("noAuditHistory")} body={t("roleHistoryEmptyBody")} />
      ) : (
        <Card>
          <RoleHistoryTimeline entries={data.content} />
          {data.totalPages > 1 && (
            <div className="flex items-center justify-center gap-1.5 pt-2">
              <button onClick={() => setPage((p) => Math.max(0, p - 1))} disabled={data.number === 0} className="lifey-button p-1.5 disabled:opacity-30" aria-label={common("previousPage")}>
                <Icon name="chevron_left" size={22} />
              </button>
              <span className="type-body-s tabular px-2" style={{ fontWeight: 700 }}>
                {data.number + 1} / {Math.max(1, data.totalPages)}
              </span>
              <button onClick={() => setPage((p) => (data.last ? p : p + 1))} disabled={data.last} className="lifey-button p-1.5 disabled:opacity-30" aria-label={common("nextPage")}>
                <Icon name="chevron_right" size={22} />
              </button>
            </div>
          )}
        </Card>
      )}
    </div>
  );
}
