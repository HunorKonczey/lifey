"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { addDays, format, startOfWeek } from "date-fns";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys, invalidationMap } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { ClientCard } from "@/features/trainer/components/ClientCard";
import { ClientRows } from "@/features/trainer/components/ClientRows";
import { ClientsTable } from "@/features/trainer/components/ClientsTable";
import { ClientSortControl, type ClientView } from "@/features/trainer/components/ClientSortControl";
import { AttentionStrip } from "@/features/trainer/components/AttentionStrip";
import { PendingInvitesCard } from "@/features/trainer/components/PendingInvitesCard";
import { clientDisplayName } from "@/features/trainer/components/ClientAvatar";
import {
  attentionItems,
  sortForList,
  weekSummary,
  type ClientListSort,
  type UnreadThread,
} from "@/features/trainer/clientSignals";
import { useConversations } from "@/features/chat/hooks";
import { useTrainerBillingGate } from "@/features/billing/hooks";
import { TrainerOnboardingChecklist } from "@/features/billing/components/TrainerOnboardingChecklist";
import { Button, Icon, TextField } from "@/components/ds";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";

const SORT_KEY = "lifey-admin-client-sort";
const VIEW_KEY = "lifey-admin-client-view";

function readStored<T extends string>(key: string, allowed: readonly T[], fallback: T): T {
  try {
    const v = localStorage.getItem(key);
    return allowed.includes(v as T) ? (v as T) : fallback;
  } catch {
    return fallback;
  }
}

function store(key: string, value: string) {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* a private window: the choice just is not remembered */
  }
}

/**
 * The trainer's clients page (W7-A): who needs the trainer today at the top, then everyone with real numbers — grid or
 * table, three sorts, a search that "/" focuses. No "your clients" modal on arrival any more.
 */
export default function AdminClientsPage() {
  const t = useTranslations("admin.dashboard");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const gate = useTrainerBillingGate();
  const searchRef = useRef<HTMLInputElement>(null);
  const phone = useMediaQuery("(max-width: 767px)");
  const [query, setQuery] = useState("");
  // Read after mount so the server and the first client render agree; the stored choice then applies.
  const [sort, setSort] = useState<ClientListSort>("attention");
  const [view, setView] = useState<ClientView>("grid");
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setSort(readStored(SORT_KEY, ["attention", "name", "activity"] as const, "attention"));
    setView(readStored(VIEW_KEY, ["grid", "table"] as const, "grid"));
  }, []);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key !== "/" || e.metaKey || e.ctrlKey || e.altKey) return;
      const el = e.target as HTMLElement;
      if (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.isContentEditable) return;
      e.preventDefault();
      searchRef.current?.focus();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  const { data: clients, isLoading, isError, refetch } = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });
  const { data: invites } = useQuery({ queryKey: queryKeys.trainerInvites.all(), queryFn: trainerApi.pendingInvites });
  const { data: conversations } = useConversations();

  const today = useMemo(() => new Date(), []);
  const weekStart = format(startOfWeek(today, { weekStartsOn: 1 }), "yyyy-MM-dd");
  const todayIso = format(today, "yyyy-MM-dd");
  const rangeEnd = format(addDays(new Date(weekStart + "T00:00:00"), 20), "yyyy-MM-dd");
  const { data: sessions } = useQuery({
    queryKey: queryKeys.trainerCalendar.range(weekStart, rangeEnd),
    queryFn: () => trainerApi.calendarSessions(weekStart, rangeEnd),
  });

  const threads: UnreadThread[] = useMemo(
    () => (conversations ?? []).map((c) => ({ clientId: c.peer.userId, unreadCount: c.unreadCount, lastMessage: c.lastMessage?.body ?? null })),
    [conversations],
  );
  const weeks = useMemo(() => {
    const map = new Map<number, ReturnType<typeof weekSummary>>();
    if (!sessions || !clients) return map;
    for (const c of clients) map.set(c.clientId, weekSummary(sessions, c.clientId, weekStart, todayIso));
    return map;
  }, [sessions, clients, weekStart, todayIso]);

  const items = useMemo(() => (clients ? attentionItems(clients, threads) : []), [clients, threads]);
  const visible = useMemo(() => {
    if (!clients) return [];
    const q = query.trim().toLocaleLowerCase();
    const filtered = q ? clients.filter((c) => clientDisplayName(c).toLocaleLowerCase().includes(q) || c.clientEmail.toLocaleLowerCase().includes(q)) : clients;
    return sortForList(filtered, sort, threads);
  }, [clients, query, sort, threads]);

  const revokeMutation = useMutation({
    mutationFn: (clientId: number) => trainerApi.revokeClient(clientId),
    onSuccess: () => {
      // Ending a relationship frees a seat — the entitlement's activeClients count (and so OVER_LIMIT) can change (64 §4.3).
      invalidationMap.trainerClient.forEach((key) => queryClient.invalidateQueries({ queryKey: key }));
      show(t("relationshipEnded"), "success");
    },
    onError: () => show(t("relationshipEndFailed"), "error"),
  });

  const changeSort = (s: ClientListSort) => {
    setSort(s);
    store(SORT_KEY, s);
  };
  const changeView = (v: ClientView) => {
    setView(v);
    store(VIEW_KEY, v);
  };

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="type-body" style={{ color: "var(--text-2)" }}>
            {t("subtitle", { active: clients?.length ?? 0, pending: invites?.length ?? 0 })}
          </p>
        </div>
        <div className="flex items-center gap-3 w-full sm:w-auto">
          <TextField
            ref={searchRef}
            size="dense"
            leadingIcon="search"
            aria-label={t("searchLabel")}
            placeholder={t("searchPlaceholder")}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="flex-1 sm:w-[260px]"
          />
          <Link href="/admin/invites" aria-label={t("inviteClient")} className="shrink-0">
            <Button>
              <Icon name="person_add" size={20} />
              <span className="hidden sm:inline">{t("inviteClient")}</span>
            </Button>
          </Link>
        </div>
      </header>

      <TrainerOnboardingChecklist />

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} variant="card" className="h-[220px]" />
          ))}
        </div>
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : !clients || clients.length === 0 ? (
        <div className="flex flex-col items-center gap-3 p-10 text-center" style={{ borderRadius: "var(--r-card)", background: "var(--card)" }}>
          <Icon name="group" size={36} color="var(--text-3)" />
          <p style={{ fontSize: 18, fontWeight: 800 }}>{t("noClientsTitle")}</p>
          <p className="type-body" style={{ color: "var(--text-2)" }}>{t("noClientsBody")}</p>
          <Link href="/admin/invites">
            <Button>
              <Icon name="person_add" size={20} />
              {t("inviteFirst")}
            </Button>
          </Link>
        </div>
      ) : (
        <>
          <AttentionStrip items={items} clients={clients} conversations={conversations} compact={phone} />

          <div className={`grid grid-cols-1 gap-6 items-start ${invites && invites.length > 0 ? "xl:grid-cols-[minmax(0,1fr)_300px]" : ""}`}>
            <section aria-labelledby="all-clients-title" className="flex flex-col gap-4 min-w-0">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <h2 id="all-clients-title" className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 800, letterSpacing: "0.06em", textTransform: "uppercase" }}>
                  {t("allClients")}
                </h2>
                <ClientSortControl sort={sort} onSort={changeSort} view={view} onView={changeView} showView={!phone} />
              </div>

              {visible.length === 0 ? (
                <p className="type-body p-6 text-center" style={{ color: "var(--text-2)", borderRadius: "var(--r-card)", background: "var(--card)" }}>
                  {t("noMatches")}
                </p>
              ) : phone ? (
                <ClientRows clients={visible} weeks={weeks} />
              ) : view === "table" ? (
                <ClientsTable clients={visible} weeks={weeks} />
              ) : (
                <div className="grid gap-4" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(min(100%, 320px), 1fr))" }}>
                  {visible.map((c) => (
                    <ClientCard
                      key={c.clientId}
                      client={c}
                      week={weeks.get(c.clientId) ?? null}
                      onRevoke={(id) => revokeMutation.mutate(id)}
                      revoking={revokeMutation.isPending}
                      overLimit={gate.state === "OVER_LIMIT"}
                    />
                  ))}
                </div>
              )}
            </section>
            <PendingInvitesCard invites={invites ?? []} />
          </div>
        </>
      )}
    </div>
  );
}
