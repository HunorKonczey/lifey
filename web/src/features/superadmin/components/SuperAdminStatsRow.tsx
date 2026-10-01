"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { formatDistanceToNowStrict } from "date-fns";
import { useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";
import { useLocale } from "@/lib/hooks/useLocale";
import { DATE_LOCALES } from "@/lib/i18n/format";
import { superAdminApi } from "../api";

function Tile({ label, value, note, href, testId }: { label: string; value: string; note?: string; href?: string; testId: string }) {
  const body = (
    <Card className="flex h-full flex-col gap-1" data-testid={testId}>
      <p className="type-overline" style={{ color: "var(--text-3)" }}>{label}</p>
      <p className="tabular" style={{ fontSize: 28, fontWeight: 800, lineHeight: "34px" }}>{value}</p>
      {note && <p className="type-body-s" style={{ color: "var(--text-2)" }}>{note}</p>}
    </Card>
  );
  return href ? <Link href={href} className="block">{body}</Link> : body;
}

/** The four numbers over the users table (W9-E, W9.b2): active accounts in 30 days, trainers, clients with a trainer, requests waiting. Nothing is shown while loading or if the call fails — the table does not depend on it. */
export function SuperAdminStatsRow() {
  const t = useTranslations("superadmin");
  const locale = useLocale((s) => s.locale);
  const { data } = useQuery({ queryKey: queryKeys.superAdminUsers.stats(), queryFn: superAdminApi.stats });
  if (!data) return null;

  const oldest = data.oldestPendingRequestAt
    ? t("oldestRequest", { age: formatDistanceToNowStrict(new Date(data.oldestPendingRequestAt), { addSuffix: true, locale: DATE_LOCALES[locale] }) })
    : undefined;

  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4" data-testid="superadmin-stats">
      <Tile testId="stat-active" label={t("statActive")} value={String(data.activeAccounts30d)} note={t("statActiveNote", { total: data.totalUsers })} />
      <Tile testId="stat-trainers" label={t("statTrainers")} value={String(data.trainers)} />
      <Tile testId="stat-clients" label={t("statClients")} value={String(data.clientsWithTrainer)} />
      <Tile testId="stat-requests" label={t("statRequests")} value={String(data.pendingRequests)} note={oldest} href="/superadmin/trainer-requests" />
    </div>
  );
}
