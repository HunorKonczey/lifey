"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { Button, Fab, Icon, SegmentedControl, Tabs } from "@/components/ds";
import { SessionsView } from "@/features/workouts/components/SessionsView";
import { TemplatesView } from "@/features/workouts/components/TemplatesView";
import { ExercisesView } from "@/features/workouts/components/ExercisesView";
import { parseWorkoutsTab, workoutsTabHref, type SessionTypeFilter, type WorkoutsTab } from "@/features/workouts/workoutsTab";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { usePageShortcuts } from "@/lib/hooks/usePageShortcuts";

/**
 * The workouts page (W3.1, W3-A): title-less header with the three tabs (in the URL — `?tab=templates` — so
 * links, reloads and the back button keep them), the type filter chips, and "Edzés indítása" with its `N`
 * shortcut, which opens the start dialog (the template picker, W3.5). On a phone the tabs are one segmented
 * control and the start action is the FAB.
 */
export default function WorkoutsPage() {
  const t = useTranslations("workouts");
  const router = useRouter();
  const searchParams = useSearchParams();
  const isMobile = useMediaQuery("(max-width: 767px)");
  const tab = parseWorkoutsTab(searchParams.get("tab"));
  const [filter, setFilter] = useState<SessionTypeFilter>("all");
  const [starting, setStarting] = useState(false);

  // "?start=<templateId>" arrives from the dashboard's recommended-workout
  // card — SessionsView auto-starts it. "?open=<sessionId>" arrives from the
  // dashboard's recent-workouts rows. Both live on the sessions tab.
  const startParam = searchParams.get("start");
  const autoStartTemplateId = startParam ? Number(startParam) : null;
  const openParam = searchParams.get("open");
  const autoOpenSessionId = openParam ? Number(openParam) : null;

  const deepLinked = autoStartTemplateId != null || autoOpenSessionId != null;
  useEffect(() => {
    if (deepLinked && tab !== "sessions") router.replace(workoutsTabHref("sessions"), { scroll: false });
  }, [deepLinked, tab, router]);

  // `N` starts a workout from the sessions tab; on the others it has nothing to add here yet.
  const openStart = useCallback(() => {
    if (tab !== "sessions") router.replace(workoutsTabHref("sessions"), { scroll: false });
    setStarting(true);
  }, [tab, router]);
  usePageShortcuts({ onNew: openStart, newLabel: t("startWorkout") });

  const items = [
    { value: "sessions" as const, label: t("sessions") },
    { value: "templates" as const, label: t("templates") },
    { value: "exercises" as const, label: t("exercises") },
  ];
  const onTabChange = (next: WorkoutsTab) => router.replace(workoutsTabHref(next), { scroll: false });

  const filters: { value: SessionTypeFilter; label: string }[] = [
    { value: "all", label: t("filterAll") },
    { value: "strength", label: t("filterStrength") },
    { value: "cardio", label: t("filterCardio") },
  ];

  return (
    <div className="flex flex-col gap-5">
      {isMobile ? (
        <>
          <SegmentedControl<WorkoutsTab> fullWidth aria-label={t("tabsAria")} options={items} value={tab} onChange={onTabChange} />
          <Fab label={t("fabStart")} aria-label={t("startWorkout")} icon="play_arrow" onClick={openStart} />
        </>
      ) : (
        <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-3">
          <div className="min-w-0 flex-1">
            <Tabs<WorkoutsTab> items={items} value={tab} onChange={onTabChange} aria-label={t("tabsAria")} />
          </div>
          <Button onClick={openStart}>
            <Icon name="play_arrow" size={20} />
            {t("startWorkout")}
            <kbd className="type-label ml-1 opacity-70">N</kbd>
          </Button>
        </div>
      )}

      {tab === "sessions" && (
        <>
          <div role="group" aria-label={t("filterAria")} className="flex flex-wrap gap-2">
            {filters.map((f) => {
              const on = filter === f.value;
              return (
                <button
                  key={f.value}
                  type="button"
                  aria-pressed={on}
                  onClick={() => setFilter(f.value)}
                  className="lifey-button type-body-s"
                  style={{
                    height: 30,
                    padding: "0 14px",
                    borderRadius: "var(--r-pill)",
                    fontWeight: 700,
                    background: on ? "var(--primary)" : "var(--nested)",
                    color: on ? "var(--on-primary)" : "var(--text-2)",
                  }}
                >
                  {f.label}
                </button>
              );
            })}
          </div>
          <SessionsView
            typeFilter={filter}
            starting={starting}
            onStartingChange={setStarting}
            autoStartTemplateId={autoStartTemplateId}
            autoOpenSessionId={autoOpenSessionId}
            onAutoStartHandled={() => router.replace("/workouts")}
          />
        </>
      )}
      {tab === "templates" && <TemplatesView />}
      {tab === "exercises" && <ExercisesView />}
    </div>
  );
}
