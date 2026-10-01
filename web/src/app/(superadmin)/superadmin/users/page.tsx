"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Checkbox, ConfirmModal, DataTable, SegmentedControl, type DataTableColumn } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { useSessionStore } from "@/features/auth/store";
import { superAdminApi } from "@/features/superadmin/api";
import { BulkRoleBar } from "@/features/superadmin/components/BulkRoleBar";
import { RoleChip } from "@/features/superadmin/components/RoleChip";
import { RoleHistoryDrawer } from "@/features/superadmin/components/RoleHistoryDrawer";
import { UserAvatar } from "@/features/superadmin/components/UserAvatar";
import type { SuperAdminUserResponse } from "@/features/superadmin/types";
import { bulkTargets, matchesRoleFilter, primaryRole, runBulk, type BulkRoleAction, type RoleFilter } from "@/features/superadmin/userRoles";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/i18n/format";
import { useToast } from "@/lib/hooks/useToast";

/** The users the table can show at once; a search goes to the server, so a longer list is still reachable. */
const LIMIT = 500;

interface PendingChange {
  action: BulkRoleAction;
  users: SuperAdminUserResponse[];
}

/**
 * Superadmin users (W9-E): a DS `DataTable` — avatar and e-mail, the role in words (Kliens · Edző · Superadmin, never
 * `ROLE_`), registered date — with a role filter, search (server side), row ticks with a bulk "Szerepkör…" bar (trainer
 * grant / revoke, one request per user in turn with progress, failures reported) and a "⋯" with the role action and the
 * per-user history drawer. Names, the trainer column and the KPI row need the optional W9.b1 / b2 endpoints.
 */
export default function SuperAdminUsersPage() {
  const t = useTranslations("superadmin");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const me = useSessionStore((s) => s.user);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState<RoleFilter>("all");
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [confirm, setConfirm] = useState<PendingChange | null>(null);
  const [history, setHistory] = useState<SuperAdminUserResponse | null>(null);
  const [progress, setProgress] = useState<{ completed: number; total: number } | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.superAdminUsers.page({ page: 0, size: LIMIT, search: search || undefined }),
    queryFn: () => superAdminApi.users({ page: 0, size: LIMIT, search: search || undefined }),
    placeholderData: keepPreviousData,
  });

  const users = useMemo(() => data?.content ?? [], [data]);
  const rows = useMemo(() => users.filter((u) => matchesRoleFilter(u, roleFilter)), [users, roleFilter]);
  const truncated = data != null && data.totalElements > users.length;
  const trainers = users.filter((u) => primaryRole(u.roles) === "TRAINER").length;
  const selectedUsers = users.filter((u) => selected.has(u.id));
  const allVisibleSelected = rows.length > 0 && rows.every((u) => selected.has(u.id));

  const toggle = (id: number) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (!next.delete(id)) next.add(id);
      return next;
    });

  const apply = useMutation({
    mutationFn: async ({ action, users: targets }: PendingChange) => {
      const run = action === "grant" ? superAdminApi.grantTrainer : superAdminApi.revokeTrainer;
      setProgress({ completed: 0, total: targets.length });
      try {
        return await runBulk(targets.map((u) => u.id), (id) => run(id), (completed) => setProgress({ completed, total: targets.length }));
      } finally {
        setProgress(null);
      }
    },
    onSuccess: (result, { action, users: targets }) => {
      queryClient.invalidateQueries({ queryKey: ["superadmin-users"] });
      setSelected(new Set());
      if (result.failed.length === 0) {
        show(targets.length === 1 ? t(action === "grant" ? "granted" : "revoked") : t("bulkDone", { count: result.done }), "success");
      } else {
        show(t("bulkPartial", { done: result.done, failed: result.failed.length }), "error");
      }
    },
  });

  const ask = (action: BulkRoleAction, from: SuperAdminUserResponse[]) => {
    const targets = bulkTargets(from, action, me?.id);
    if (targets.length === 0) {
      show(t("bulkNothing"), "error");
      return;
    }
    setConfirm({ action, users: targets });
  };

  const columns: DataTableColumn<SuperAdminUserResponse>[] = [
    {
      key: "select",
      header: "",
      width: 32,
      render: (u) => (
        <span onClick={(e) => e.stopPropagation()}>
          <Checkbox checked={selected.has(u.id)} onChange={() => toggle(u.id)} aria-label={t("selectUser", { email: u.email })} />
        </span>
      ),
    },
    {
      key: "user",
      header: t("colUser"),
      sort: (u) => u.email,
      render: (u) => (
        <span className="flex min-w-0 items-center gap-3">
          <UserAvatar userId={u.id} email={u.email} hasAvatar={u.hasAvatar} size={32} />
          <span className="type-body truncate" style={{ fontWeight: 700 }}>
            {u.email}
            {u.id === me?.id && <span className="type-body-s ml-1.5" style={{ color: "var(--text-3)", fontWeight: 600 }}>{t("self")}</span>}
          </span>
        </span>
      ),
    },
    { key: "role", header: t("colRole"), sort: (u) => primaryRole(u.roles), render: (u) => <RoleChip roles={u.roles} /> },
    {
      key: "registered",
      header: t("colRegistered"),
      sort: (u) => u.createdAt,
      render: (u) => <span className="type-body-s tabular" style={{ color: "var(--text-2)" }}>{fmt.date(u.createdAt, "dayYear")}</span>,
    },
  ];

  const confirmUsers = confirm?.users ?? [];
  const grant = confirm?.action === "grant";

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h2 className="type-title">{t("usersTitle")}</h2>
        <p className="type-body-s" style={{ color: "var(--text-2)" }} data-testid="users-summary">
          {truncated ? t("usersCount", { count: data?.totalElements ?? 0 }) : t("usersSummary", { count: users.length, trainers })}
        </p>
      </div>

      {selected.size > 0 && (
        <BulkRoleBar
          selectedCount={selected.size}
          progress={progress}
          onGrant={() => ask("grant", selectedUsers)}
          onRevoke={() => ask("revoke", selectedUsers)}
          onClear={() => setSelected(new Set())}
        />
      )}

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : (
        <>
          <DataTable
            aria-label={t("usersTitle")}
            columns={columns}
            rows={rows}
            rowKey={(u) => u.id}
            pageSize={20}
            search={{ value: search, onChange: setSearch, placeholder: t("searchPlaceholder") }}
            filters={
              <div className="flex flex-wrap items-center gap-3">
                <SegmentedControl
                  size="sm"
                  aria-label={t("colRole")}
                  value={roleFilter}
                  onChange={setRoleFilter}
                  options={[
                    { value: "all", label: t("filterAll") },
                    { value: "USER", label: t("role.USER") },
                    { value: "TRAINER", label: t("role.TRAINER") },
                    { value: "ADMIN", label: t("role.ADMIN") },
                  ]}
                />
                <Checkbox
                  checked={allVisibleSelected}
                  onChange={(on) => setSelected(on ? new Set(rows.map((u) => u.id)) : new Set())}
                  label={t("selectAllShown")}
                />
              </div>
            }
            totalLabel={(n) => t("usersCount", { count: n })}
            rowMenuLabel={(u) => t("rowMenuAria", { email: u.email })}
            rowMenu={(u) => [
              u.roles.includes("ROLE_TRAINER")
                ? { label: t("revokeTrainer"), icon: "remove_moderator", onSelect: () => ask("revoke", [u]) }
                : { label: t("makeTrainer"), icon: "add_moderator", onSelect: () => ask("grant", [u]) },
              { label: t("auditHistory"), icon: "history", onSelect: () => setHistory(u) },
            ]}
            renderCardRow={(u) => ({ title: u.email, meta: fmt.date(u.createdAt, "dayYear"), value: <RoleChip roles={u.roles} /> })}
          />
          {data && data.totalElements > users.length && (
            <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("limitNote", { shown: users.length, total: data.totalElements })}</p>
          )}
        </>
      )}

      <ConfirmModal
        open={confirm !== null}
        onClose={() => setConfirm(null)}
        onConfirm={() => {
          if (confirm) apply.mutate(confirm);
          setConfirm(null);
        }}
        icon={grant ? "add_moderator" : "remove_moderator"}
        tint={grant ? "var(--role)" : "var(--heart)"}
        destructive={!grant}
        title={confirmUsers.length > 1 ? t(grant ? "bulkMakeTitle" : "bulkRevokeTitle", { count: confirmUsers.length }) : t(grant ? "confirmMakeTitle" : "confirmRevokeTitle")}
        body={
          confirmUsers.length > 1
            ? t(grant ? "bulkMakeBody" : "bulkRevokeBody", { count: confirmUsers.length })
            : `${confirmUsers[0]?.email ?? ""} ${t(grant ? "confirmMakeBody" : "confirmRevokeBody")}`
        }
        cancelLabel={t("cancel")}
        confirmLabel={t(grant ? "confirmMakeConfirm" : "confirmRevokeConfirm")}
      />

      {history && <RoleHistoryDrawer userId={history.id} email={history.email} onClose={() => setHistory(null)} />}
    </div>
  );
}
