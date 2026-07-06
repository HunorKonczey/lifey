"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { superAdminApi } from "@/features/superadmin/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useSessionStore } from "@/features/auth/store";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { UserAvatar } from "@/features/superadmin/components/UserAvatar";
import type { SuperAdminUserResponse } from "@/features/superadmin/types";

const PAGE_SIZE = 20;

function RoleBadge({ role }: { role: string }) {
  if (role === "ROLE_TRAINER") {
    return (
      <span
        className="rounded-[var(--r-pill)] text-[10.5px] font-extrabold tracking-wide px-2.5 py-1"
        style={{ background: "var(--tertiary-container)", color: "var(--on-tertiary-container)" }}
      >
        TRAINER
      </span>
    );
  }
  if (role === "ROLE_ADMIN" || role === "ROLE_SUPER_ADMIN") {
    return (
      <span
        className="rounded-[var(--r-pill)] text-[10.5px] font-extrabold tracking-wide px-2.5 py-1"
        style={{ border: "1.5px solid var(--on-surface-variant)", color: "var(--on-surface)" }}
      >
        {role.replace("ROLE_", "")}
      </span>
    );
  }
  return (
    <span
      className="rounded-[var(--r-pill)] text-[10.5px] font-bold tracking-wide px-2.5 py-1"
      style={{ border: "1px solid var(--outline)", color: "var(--on-surface-variant)" }}
    >
      USER
    </span>
  );
}

function AuditHistory({ userId }: { userId: number }) {
  const t = useTranslations("superadmin");
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.superAdminUsers.roleAudit(userId),
    queryFn: () => superAdminApi.roleAudit(userId),
  });

  return (
    <div className="pl-[62px] pr-4 pb-3.5 flex flex-col gap-1.5">
      <p className="text-[10.5px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
        {t("auditHistory")}
      </p>
      {isLoading ? (
        <Skeleton variant="text" />
      ) : !data || data.length === 0 ? (
        <p className="text-xs" style={{ color: "var(--muted)" }}>
          {t("noAuditHistory")}
        </p>
      ) : (
        data.map((entry) => (
          <div key={entry.id} className="flex items-center gap-2.5 text-xs">
            <span className="font-mono" style={{ color: "var(--on-surface-variant)" }}>
              {format(new Date(entry.createdAt), "yyyy-MM-dd HH:mm")}
            </span>
            <span className="font-bold" style={{ color: "var(--on-surface)" }}>
              {entry.action} {entry.role}
            </span>
          </div>
        ))
      )}
    </div>
  );
}

export default function SuperAdminUsersPage() {
  const t = useTranslations("superadmin");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const { user: me } = useSessionStore();
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(0);
  const [expandedId, setExpandedId] = useState<number | null>(null);
  const [confirmTarget, setConfirmTarget] = useState<{ user: SuperAdminUserResponse; grant: boolean } | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.superAdminUsers.page({ page, size: PAGE_SIZE, search: search || undefined }),
    queryFn: () => superAdminApi.users({ page, size: PAGE_SIZE, search: search || undefined }),
  });

  const grantMutation = useMutation({
    mutationFn: (userId: number) => superAdminApi.grantTrainer(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["superadmin-users"] });
      show(t("granted"), "success");
    },
    onError: () => show(t("grantFailed"), "error"),
  });

  const revokeMutation = useMutation({
    mutationFn: (userId: number) => superAdminApi.revokeTrainer(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["superadmin-users"] });
      show(t("revoked"), "success");
    },
    onError: () => show(t("revokeFailed"), "error"),
  });

  return (
    <div className="flex flex-col gap-3.5 max-w-4xl mx-auto">
      <div className="flex items-center justify-between">
        <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
          {t("usersTitle")}
        </p>
        <div
          className="rounded-2xl h-12 w-80 flex items-center gap-2.5 px-4.5"
          style={{ background: "var(--surface)" }}
        >
          <span className="material-symbols-rounded text-xl" style={{ color: "var(--muted)" }}>
            search
          </span>
          <input
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(0);
            }}
            placeholder={t("searchPlaceholder")}
            className="flex-1 bg-transparent outline-none text-sm"
            style={{ color: "var(--on-surface)" }}
          />
        </div>
      </div>

      {isLoading ? (
        <Skeleton variant="table" />
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : !data || data.content.length === 0 ? (
        <p className="text-sm text-center py-10" style={{ color: "var(--on-surface-variant)" }}>
          {t("noResults")}
        </p>
      ) : (
        <>
          <div className="rounded-[var(--r-lg)] p-2 flex flex-col gap-1" style={{ background: "var(--surface)" }}>
            {data.content.map((u) => {
              const isSelf = u.id === me?.id;
              const isTrainer = u.roles.includes("ROLE_TRAINER");
              const expanded = expandedId === u.id;
              return (
                <div key={u.id} className="rounded-[13px]" style={{ background: expanded ? "var(--surface-container)" : "transparent" }}>
                  <div className="flex items-center gap-3.5 px-3.5 py-3">
                    <button
                      onClick={() => setExpandedId(expanded ? null : u.id)}
                      className="shrink-0"
                      style={{ color: "var(--on-surface-variant)" }}
                      aria-label={t("auditHistory")}
                    >
                      <span className="material-symbols-rounded text-xl">
                        {expanded ? "expand_more" : "chevron_right"}
                      </span>
                    </button>
                    <UserAvatar userId={u.id} email={u.email} hasAvatar={u.hasAvatar} />
                    <span className="flex-1 min-w-0 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                      {u.email}
                      {isSelf && <span className="ml-1.5 text-[11px] font-semibold" style={{ color: "var(--muted)" }}>{t("self")}</span>}
                    </span>
                    <div className="flex gap-1.5 shrink-0">
                      {u.roles.map((r) => (
                        <RoleBadge key={r} role={r} />
                      ))}
                    </div>
                    <div className="w-[170px] flex justify-end shrink-0">
                      {isSelf ? (
                        <span className="text-sm font-bold" style={{ color: "var(--muted)" }}>—</span>
                      ) : isTrainer ? (
                        <button
                          onClick={() => setConfirmTarget({ user: u, grant: false })}
                          className="flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-extrabold"
                          style={{ border: "1.5px solid rgba(207,102,121,.5)", color: "var(--error)" }}
                        >
                          <span className="material-symbols-rounded text-base">remove_moderator</span>
                          {t("revokeTrainer")}
                        </button>
                      ) : (
                        <button
                          onClick={() => setConfirmTarget({ user: u, grant: true })}
                          className="flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-extrabold"
                          style={{ background: "var(--primary)", color: "#161611" }}
                        >
                          <span className="material-symbols-rounded text-base">add_moderator</span>
                          {t("makeTrainer")}
                        </button>
                      )}
                    </div>
                  </div>
                  {expanded && <AuditHistory userId={u.id} />}
                </div>
              );
            })}
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
              {confirmTarget.grant ? t("confirmMakeTitle") : t("confirmRevokeTitle")}
            </p>
            <p className="text-[12.5px] leading-relaxed mb-4.5" style={{ color: "var(--on-surface-variant)" }}>
              <span style={{ color: "var(--on-surface)", fontWeight: 800 }}>{confirmTarget.user.email}</span>{" "}
              {confirmTarget.grant ? t("confirmMakeBody") : t("confirmRevokeBody")}
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
                onClick={() => {
                  if (confirmTarget.grant) grantMutation.mutate(confirmTarget.user.id);
                  else revokeMutation.mutate(confirmTarget.user.id);
                  setConfirmTarget(null);
                }}
                className="rounded-xl px-4.5 py-2.5 text-sm font-extrabold"
                style={{
                  background: confirmTarget.grant ? "var(--primary)" : "var(--error)",
                  color: "#161611",
                }}
              >
                {confirmTarget.grant ? t("confirmMakeConfirm") : t("confirmRevokeConfirm")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
