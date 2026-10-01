"use client";

import { useCallback, useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, ConfirmModal, Fab, GridItem, Icon, PageGrid, SegmentedControl } from "@/components/ds";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { userDetailsApi } from "@/features/onboarding/api";
import { weightApi } from "@/features/weight/api";
import { LogWeightDrawer } from "@/features/weight/components/LogWeightDrawer";
import { WeightChart } from "@/features/weight/components/WeightChart";
import { WeightHero } from "@/features/weight/components/WeightHero";
import { WeightLogTable } from "@/features/weight/components/WeightLogTable";
import type { WeightResponse } from "@/features/weight/types";
import { buildWeightHero } from "@/features/weight/weightHero";
import { WEIGHT_RANGES, type WeightRange } from "@/features/weight/weightSeries";
import { queryKeys } from "@/lib/api/queryKeys";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { usePageShortcuts } from "@/lib/hooks/usePageShortcuts";
import { TOAST_DURATION_MS } from "@/lib/hooks/useToast";
import { useTopBarCentre } from "@/lib/hooks/useTopBarSlot";
import { useUndoableDelete } from "@/lib/hooks/useUndoableDelete";
import { useFormat } from "@/lib/i18n/format";

/**
 * The weight page (W4, W4-A): the hero, the chart with its range switcher (in the top bar's centre), the log table
 * and the big-number drawer — `N` or "＋ Súly rögzítése" opens it, a row's "Szerkesztés" opens it on that entry.
 */
export default function WeightPage() {
  const t = useTranslations("weight");
  const common = useTranslations("common");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const undoableDelete = useUndoableDelete();
  const phone = useMediaQuery("(max-width: 767px)");
  const [range, setRange] = useState<WeightRange>("30d");
  // `logging`: the drawer's state — a new entry, an entry being edited, or closed; the key remounts it per opening.
  const [logging, setLogging] = useState<{ entry: WeightResponse | null; key: number } | null>(null);
  const [deleting, setDeleting] = useState<WeightResponse | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({ queryKey: queryKeys.weights.all(), queryFn: weightApi.list });
  // 404 = onboarding not done — no goal weight, not an error.
  const { data: userDetails } = useQuery({ queryKey: queryKeys.userDetails.all(), queryFn: userDetailsApi.get, retry: false });
  const goalKg = userDetails?.targetWeightKg ?? null;
  const weights = useMemo(() => data ?? [], [data]);

  const openNew = useCallback(() => setLogging({ entry: null, key: Date.now() }), []);
  usePageShortcuts({ onNew: openNew, newLabel: t("logTitle") });

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

  // Delete = confirm → the entry leaves the table and a toast offers Undo; the DELETE goes out when the window closes.
  const setCached = (update: (list: WeightResponse[]) => WeightResponse[]) =>
    queryClient.setQueryData<WeightResponse[]>(queryKeys.weights.all(), (old) => update(old ?? []));
  const deleteEntry = (entry: WeightResponse) =>
    undoableDelete({
      message: t("entryDeletedUndo", { weight: fmt.number(entry.weight, 1, 1) }),
      path: `/weights/${entry.id}`,
      remove: () => setCached((list) => list.filter((w) => w.id !== entry.id)),
      restore: () => setCached((list) => (list.some((w) => w.id === entry.id) ? list : [...list, entry])),
      errorMessage: t("removeFailed"),
    });

  const hero = buildWeightHero(weights, goalKg, new Date());

  return (
    <div className="flex flex-col gap-5">
      {!phone && (
        <div className="flex justify-end">
          <Button onClick={openNew}>
            <Icon name="add" size={20} />
            {t("logTitle")}
            <kbd className="type-label ml-1 opacity-70">N</kbd>
          </Button>
        </div>
      )}
      {phone && <Fab label={t("fabLog")} aria-label={t("logTitle")} onClick={openNew} />}

      {isLoading ? (
        <PageGrid>
          <GridItem span={{ base: 4, md: 8, xl: 4 }}>
            <Skeleton variant="card" className="h-96" />
          </GridItem>
          <GridItem span={{ base: 4, md: 8, xl: 8 }}>
            <Skeleton variant="chart" />
          </GridItem>
        </PageGrid>
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : weights.length === 0 ? (
        <EmptyState
          icon="monitor_weight"
          color="var(--m-weight)"
          title={t("noEntries")}
          body={t("noEntriesBody")}
          action={
            <Button onClick={openNew}>
              <Icon name="add" size={20} />
              {t("logTitle")}
            </Button>
          }
        />
      ) : (
        <PageGrid>
          <GridItem span={{ base: 4, md: 8, xl: 4 }} className="xl:row-span-2">
            {hero && <WeightHero hero={hero} />}
          </GridItem>
          <GridItem span={{ base: 4, md: 8, xl: 8 }} className="flex flex-col gap-3">
            {phone && switcher}
            <WeightChart weights={weights} range={range} goalKg={goalKg} />
          </GridItem>
          <GridItem span={{ base: 4, md: 8, xl: 8 }}>
            <WeightLogTable weights={weights} goalKg={goalKg} onEdit={(entry) => setLogging({ entry, key: Date.now() })} onDelete={setDeleting} />
          </GridItem>
        </PageGrid>
      )}

      {logging && <LogWeightDrawer key={logging.key} weights={weights} editing={logging.entry} onClose={() => setLogging(null)} />}

      <ConfirmModal
        open={deleting != null}
        onClose={() => setDeleting(null)}
        onConfirm={() => {
          if (deleting) deleteEntry(deleting);
          setDeleting(null);
        }}
        icon="delete"
        title={deleting ? t("deleteTitle", { weight: `${fmt.number(deleting.weight, 1, 1)} kg` }) : ""}
        body={t("deleteBody", { seconds: TOAST_DURATION_MS / 1000 })}
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />
    </div>
  );
}
