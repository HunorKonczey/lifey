"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { waterApi } from "@/features/water/api";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { useToast } from "@/lib/hooks/useToast";
import { logTimestampFor } from "@/lib/utils/logTime";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";

const SEGMENTS = 10;
const QUICK_AMOUNTS = [0.25, 0.5, 1.0];

export default function WaterPage() {
  const t = useTranslations("water");
  const nav = useTranslations("nav");
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const dateStr = format(date, "yyyy-MM-dd");
  const [managing, setManaging] = useState(false);
  const [newName, setNewName] = useState("");
  const [newVol, setNewVol] = useState("");
  const [customInput, setCustomInput] = useState("");

  const entriesQ = useQuery({ queryKey: queryKeys.waterEntries.all(), queryFn: waterApi.entries.list });
  const sourcesQ = useQuery({ queryKey: queryKeys.waterSources.all(), queryFn: waterApi.sources.list });
  const settingsQ = useQuery({ queryKey: queryKeys.settings.all(), queryFn: settingsApi.get, staleTime: 5 * 60_000 });

  const todayEntries = (entriesQ.data ?? []).filter(
    (e) => format(new Date(e.consumedAt), "yyyy-MM-dd") === dateStr,
  );
  const total = todayEntries.reduce((s, e) => s + e.volumeLiters, 0);
  const goal = settingsQ.data?.dailyWaterGoalLiters ?? 2.5;
  const filledSegments = Math.round(Math.min(total / goal, 1) * SEGMENTS);

  const addMutation = useMutation({
    mutationFn: ({ volumeLiters, sourceId }: { volumeLiters: number; sourceId?: number | null }) =>
      waterApi.entries.create({ consumedAt: logTimestampFor(date), volumeLiters, sourceId }),
    onMutate: async ({ volumeLiters }) => {
      await queryClient.cancelQueries({ queryKey: queryKeys.waterEntries.all() });
      const prev = queryClient.getQueryData(queryKeys.waterEntries.all());
      queryClient.setQueryData(queryKeys.waterEntries.all(), (old: unknown[] = []) => [
        ...old,
        { id: Date.now(), consumedAt: logTimestampFor(date), volumeLiters, sourceId: null, sourceName: null },
      ]);
      return { prev };
    },
    onError: (_e, _v, ctx) => {
      if (ctx?.prev !== undefined) queryClient.setQueryData(queryKeys.waterEntries.all(), ctx.prev);
      show(t("addFailed"), "error");
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: queryKeys.waterEntries.all() }),
  });

  const deleteEntry = useMutation({
    mutationFn: (id: number) => waterApi.entries.delete(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: queryKeys.waterEntries.all() }),
  });

  const createSource = useMutation({
    mutationFn: () => waterApi.sources.create({ name: newName, volumeLiters: Number(newVol) }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.waterSources.all() });
      show(t("sourceAdded"), "success"); setNewName(""); setNewVol("");
    },
    onError: () => show(t("addSourceFailed"), "error"),
  });

  const deleteSource = useMutation({
    mutationFn: (id: number) => waterApi.sources.delete(id),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: queryKeys.waterSources.all() }); show(t("sourceRemoved"), "success"); },
    onError: () => show(t("removeFailed"), "error"),
  });

  const quickSources = (sourcesQ.data ?? []).length > 0
    ? sourcesQ.data!
    : [
        { id: -1, name: t("defaultGlass"), volumeLiters: 0.25 },
        { id: -2, name: t("defaultBottle"), volumeLiters: 0.5 },
        { id: -3, name: t("defaultCan"), volumeLiters: 0.33 },
      ];

  function handleCustomAdd() {
    const parsed = parseFloat(customInput.replace(",", "."));
    if (isNaN(parsed) || parsed <= 0) {
      show(t("invalidAmount"), "error");
      return;
    }
    addMutation.mutate({ volumeLiters: parsed, sourceId: null });
    setCustomInput("");
  }

  if (entriesQ.isLoading || sourcesQ.isLoading) {
    return <div className="flex gap-6"><Skeleton variant="card" className="flex-1 h-80" /><Skeleton variant="card" className="w-[300px] h-80" /></div>;
  }
  if (entriesQ.isError) return <ErrorState onRetry={() => entriesQ.refetch()} />;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center gap-2">
        <span className="material-symbols-rounded text-2xl" style={{ color: "var(--metric-water)" }}>water_drop</span>
        <h1 className="text-xl font-bold">{nav("water")}</h1>
      </div>

      <div className="flex flex-col lg:flex-row gap-6">
        {/* Summary + quick add */}
        <div className="flex-1 min-w-0 flex flex-col gap-5 rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
          <div className="flex items-end gap-2">
            <span className="text-4xl font-extrabold tabular" style={{ color: "var(--on-surface)" }}>{total.toFixed(2)}</span>
            <span className="text-base font-semibold mb-1.5" style={{ color: "var(--on-surface-variant)" }}>/ {goal.toFixed(1)} L</span>
          </div>

          <div className="flex items-end gap-1.5">
            {Array.from({ length: SEGMENTS }).map((_, i) => (
              <div key={i} className="flex-1 rounded-[var(--r-sm)] transition-all duration-[var(--dur-base)]"
                style={{ height: 40 + (i / SEGMENTS) * 12, background: i < filledSegments ? "var(--metric-water)" : "var(--surface-highest)" }} />
            ))}
          </div>

          {/* Saved sources */}
          <div className="flex flex-wrap gap-2">
            {quickSources.map((src) => (
              <button key={src.id}
                onClick={() => addMutation.mutate({ volumeLiters: src.volumeLiters, sourceId: src.id > 0 ? src.id : null })}
                disabled={addMutation.isPending}
                className="flex items-center gap-1 px-4 py-2 rounded-[var(--r-input)] text-sm font-semibold transition-opacity disabled:opacity-50"
                style={{ background: "var(--surface-container)", color: "var(--metric-water)", border: "1px solid var(--outline)" }}>
                <span className="material-symbols-rounded text-lg">add</span>
                {src.volumeLiters >= 1 ? `${src.volumeLiters}L` : `${Math.round(src.volumeLiters * 1000)}ml`} {src.name}
              </button>
            ))}
          </div>

          {/* Custom amount */}
          <div className="flex flex-col gap-2 pt-3" style={{ borderTop: "1px solid var(--outline)" }}>
            <p className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("customAmount")}</p>
            <div className="flex flex-wrap gap-2">
              {QUICK_AMOUNTS.map((amount) => (
                <button key={amount}
                  onClick={() => addMutation.mutate({ volumeLiters: amount, sourceId: null })}
                  disabled={addMutation.isPending}
                  className="flex items-center gap-1 px-3 py-1.5 rounded-[var(--r-input)] text-sm font-semibold transition-opacity disabled:opacity-50"
                  style={{ background: "var(--surface-container)", color: "var(--metric-water)", border: "1px solid var(--outline)" }}>
                  <span className="material-symbols-rounded text-base">add</span>
                  {amount >= 1 ? `${amount}L` : `${Math.round(amount * 1000)}ml`}
                </button>
              ))}
            </div>
            <div className="flex gap-2">
              <input
                type="number"
                step="0.05"
                min="0"
                value={customInput}
                onChange={(e) => setCustomInput(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleCustomAdd()}
                placeholder={t("amountPlaceholder")}
                className="flex-1 px-3 h-9 rounded-[var(--r-md)] outline-none text-sm tabular"
                style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
              />
              <span className="self-center text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>L</span>
              <button
                onClick={handleCustomAdd}
                disabled={addMutation.isPending || !customInput}
                className="px-4 h-9 rounded-[var(--r-md)] text-sm font-semibold transition-opacity disabled:opacity-50"
                style={{ background: "var(--primary)", color: "var(--on-primary)" }}>
                {t("add")}
              </button>
            </div>
          </div>

          {/* Today's entries */}
          {todayEntries.length > 0 && (
            <div className="flex flex-col gap-1 pt-2" style={{ borderTop: "1px solid var(--outline)" }}>
              {todayEntries.map((e) => (
                <div key={e.id} className="flex items-center justify-between py-1.5 group">
                  <span className="text-sm" style={{ color: "var(--on-surface-variant)" }}>
                    {e.sourceName ?? t("entryLabel")} · {format(new Date(e.consumedAt), "HH:mm")}
                  </span>
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-semibold tabular">{(e.volumeLiters * 1000).toFixed(0)} ml</span>
                    <button onClick={() => deleteEntry.mutate(e.id)}
                      className="opacity-0 group-hover:opacity-100 transition-opacity" style={{ color: "var(--muted)" }}
                      aria-label={t("removeEntryAria")}>
                      <span className="material-symbols-rounded text-base">close</span>
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Sources management */}
        <div className="w-full lg:w-[300px] shrink-0 rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
          <div className="flex items-center justify-between mb-3">
            <p className="text-sm font-bold">{t("sources")}</p>
            <button onClick={() => setManaging((m) => !m)} className="text-xs font-semibold" style={{ color: "var(--primary)" }}>
              {managing ? t("done") : t("manage")}
            </button>
          </div>

          <div className="flex flex-col gap-2">
            {(sourcesQ.data ?? []).map((s) => (
              <div key={s.id} className="flex items-center justify-between px-3 py-2 rounded-[var(--r-md)]"
                style={{ background: "var(--surface-container)" }}>
                <span className="text-sm font-semibold">{s.name}</span>
                <div className="flex items-center gap-2">
                  <span className="text-xs tabular" style={{ color: "var(--muted)" }}>
                    {s.volumeLiters >= 1 ? `${s.volumeLiters}L` : `${Math.round(s.volumeLiters * 1000)}ml`}
                  </span>
                  {managing && (
                    <button onClick={() => deleteSource.mutate(s.id)} style={{ color: "var(--muted)" }} aria-label={t("deleteSourceAria")}>
                      <span className="material-symbols-rounded text-base">close</span>
                    </button>
                  )}
                </div>
              </div>
            ))}
            {(sourcesQ.data ?? []).length === 0 && (
              <p className="text-xs" style={{ color: "var(--muted)" }}>{t("noCustomSources")}</p>
            )}
          </div>

          {managing && (
            <div className="flex flex-col gap-2 mt-3 pt-3" style={{ borderTop: "1px solid var(--outline)" }}>
              <input value={newName} onChange={(e) => setNewName(e.target.value)} placeholder={t("namePlaceholder")}
                className="px-3 h-9 rounded-[var(--r-md)] outline-none text-sm"
                style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
              <input type="number" step="0.05" value={newVol} onChange={(e) => setNewVol(e.target.value)} placeholder={t("litersPlaceholder")}
                className="px-3 h-9 rounded-[var(--r-md)] outline-none text-sm tabular"
                style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
              <button onClick={() => createSource.mutate()} disabled={!newName || !newVol || createSource.isPending}
                className="h-9 rounded-[var(--r-md)] font-semibold text-sm transition-opacity disabled:opacity-50"
                style={{ background: "var(--primary)", color: "#1E1F18" }}>
                {t("addSource")}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
