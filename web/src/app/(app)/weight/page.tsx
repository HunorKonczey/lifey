"use client";

import { useMemo, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { weightApi } from "@/features/weight/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import type { WeightResponse } from "@/features/weight/types";
import { useFormat } from "@/lib/i18n/format";
import { GridItem, PageGrid, SegmentedControl } from "@/components/ds";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useTopBarCentre } from "@/lib/hooks/useTopBarSlot";
import { WeightChart } from "@/features/weight/components/WeightChart";
import { WEIGHT_RANGES, type WeightRange } from "@/features/weight/weightSeries";
import { userDetailsApi } from "@/features/onboarding/api";
import { WeightHero } from "@/features/weight/components/WeightHero";
import { buildWeightHero } from "@/features/weight/weightHero";
import { DatePicker } from "@/components/ui/DatePicker";

export default function WeightPage() {
  const t = useTranslations("weight");
  const fmt = useFormat();
  const nav = useTranslations("nav");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [range, setRange] = useState<WeightRange>("30d");
  const phone = useMediaQuery("(max-width: 767px)");

  // The range switcher lives in the top bar's centre (W4.2); on a phone there is no top bar, so it sits above the chart.
  const switcher = useMemo(
    () => (
      <SegmentedControl<WeightRange>
        aria-label={t("rangeAria")}
        options={WEIGHT_RANGES.map((r) => ({ value: r, label: t(`range_${r}`) }))}
        value={range}
        onChange={setRange}
        fullWidth={phone}
      />
    ),
    [range, phone, t],
  );
  useTopBarCentre(phone ? null : switcher);
  const [adding, setAdding] = useState(false);
  const [newDate, setNewDate] = useState(format(new Date(), "yyyy-MM-dd"));
  const [newWeight, setNewWeight] = useState("");

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.weights.all(),
    queryFn: weightApi.list,
  });

  // 404 = onboarding not done — no goal weight, not an error.
  const { data: userDetails } = useQuery({ queryKey: queryKeys.userDetails.all(), queryFn: userDetailsApi.get, retry: false });
  const goalKg = userDetails?.targetWeightKg ?? null;

  const createMutation = useMutation({
    mutationFn: () => weightApi.create({ date: newDate, weight: Number(newWeight) }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.weights.all() });
      show(t("logged"), "success");
      setAdding(false); setNewWeight("");
    },
    onError: () => show(t("saveFailed"), "error"),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => weightApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.weights.all() });
      show(t("entryRemoved"), "success");
    },
    onError: () => show(t("removeFailed"), "error"),
  });

  const sorted = (data ?? []).slice().sort((a, b) => a.date.localeCompare(b.date));

  const hero = buildWeightHero(data ?? [], goalKg, new Date());

  // History newest-first with delta vs previous chronological entry
  const history = sorted.slice().reverse();

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="material-symbols-rounded text-2xl" style={{ color: "var(--metric-weight)" }}>monitor_weight</span>
          <h1 className="text-xl font-bold">{nav("weight")}</h1>
        </div>
        <button onClick={() => setAdding((a) => !a)}
          className="flex items-center gap-1 px-4 h-9 rounded-[var(--r-input)] font-semibold text-sm"
          style={{ background: "var(--primary)", color: "var(--bg)" }}>
          <span className="material-symbols-rounded text-lg">add</span> {t("newEntry")}
        </button>
      </div>

      {adding && (
        <div className="flex flex-wrap items-end gap-3 p-4 rounded-[var(--r-card)]" style={{ background: "var(--surface)" }}>
          <div className="flex flex-col gap-1">
            <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("date")}</label>
            <DatePicker value={newDate} onChange={setNewDate} max={new Date()} />
          </div>
          <div className="flex flex-col gap-1">
            <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{t("weightKg")}</label>
            <input type="number" step="0.1" value={newWeight} autoFocus
              onChange={(e) => setNewWeight(e.target.value)}
              className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular w-32"
              style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }} />
          </div>
          <button onClick={() => createMutation.mutate()} disabled={!newWeight || createMutation.isPending}
            className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-50"
            style={{ background: "var(--primary)", color: "var(--bg)" }}>
            {common("save")}
          </button>
        </div>
      )}

      {isLoading ? (
        <div className="flex flex-col lg:flex-row gap-6">
          <Skeleton variant="chart" className="flex-1" />
          <Skeleton variant="card" className="w-full lg:w-[300px] h-72" />
        </div>
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : sorted.length === 0 ? (
        <EmptyState icon="monitor_weight" title={t("noEntries")}
          body={t("noEntriesBody")} />
      ) : (
        <PageGrid>
          <GridItem span={{ base: 4, md: 8, xl: 4 }} className="xl:row-span-2">
            {hero && <WeightHero hero={hero} />}
          </GridItem>
          {/* Chart */}
          <GridItem span={{ base: 4, md: 8, xl: 8 }} className="flex flex-col gap-3">
            {phone && switcher}
            <WeightChart weights={data ?? []} range={range} goalKg={goalKg} />
          </GridItem>

          {/* History */}
          <GridItem span={{ base: 4, md: 8, xl: 8 }}>
          <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
            <p className="text-sm font-bold mb-3">{t("history")}</p>
            <div className="flex flex-col">
              {history.map((w, idx) => {
                // delta vs the next older entry (history is newest-first)
                const older = history[idx + 1] as WeightResponse | undefined;
                const delta = older ? w.weight - older.weight : null;
                return (
                  <div key={w.id} className="flex items-center justify-between py-2 group"
                    style={{ borderBottom: "1px solid var(--outline)" }}>
                    <span className="text-sm tabular" style={{ color: "var(--on-surface-variant)" }}>
                      {fmt.date(w.date, "dayYear")}
                    </span>
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-semibold tabular">{fmt.number(w.weight, 1, 1)} kg</span>
                      {delta != null && delta !== 0 && (
                        <span className="text-xs tabular font-semibold"
                          style={{ color: delta < 0 ? "var(--goal-positive)" : "var(--goal-negative)" }}>
                          {delta > 0 ? "+" : ""}{fmt.number(delta, 1, 1)}
                        </span>
                      )}
                      <button onClick={() => deleteMutation.mutate(w.id)}
                        className="opacity-0 group-hover:opacity-100 transition-opacity" style={{ color: "var(--muted)" }}
                        aria-label={t("deleteEntryAria")}>
                        <span className="material-symbols-rounded text-base">close</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
          </GridItem>
        </PageGrid>
      )}
    </div>
  );
}
