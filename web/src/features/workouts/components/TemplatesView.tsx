"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, Card, Icon } from "@/components/ds";
import { ConfirmModal } from "@/components/ds/overlay/ConfirmModal";
import { Drawer } from "@/components/ds/overlay/Drawer";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { queryKeys } from "@/lib/api/queryKeys";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useToast } from "@/lib/hooks/useToast";
import { exerciseApi, templateApi, workoutSessionApi } from "../api";
import { recommendedTemplate } from "../recommendation";
import { pickerTemplates } from "../templatePicker";
import { templateUsage } from "../templateUsage";
import type { WorkoutTemplateResponse } from "../types";
import { TemplateEditorPanel } from "./TemplateEditorPanel";
import { TemplateTile } from "./TemplateTile";

interface TemplatesViewProps {
  /** When provided, admin nav renders a "Kiosztás" button on every row — absent in the own view. */
  onAssign?: (template: WorkoutTemplateResponse) => void;
  /** When provided, admin nav renders a "schedule for a client" button on every row. */
  onSchedule?: (template: WorkoutTemplateResponse) => void;
}

/**
 * The Templates tab (W3.11, W3-F): the picker's tiles as a list — exercise count, estimated time, last used, the
 * recommended one marked — with the selected template's editor in a 440 px panel on the right (a drawer below
 * 1280 px). With nothing selected the panel shows how often each template was used over the last four weeks.
 * The trainer's own templates page embeds the same view with its Assign / Schedule row actions.
 */
export function TemplatesView({ onAssign, onSchedule }: TemplatesViewProps = {}) {
  const t = useTranslations("workouts");
  const admin = useTranslations("admin.assignDrawer");
  const schedule = useTranslations("admin.schedule");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const sidePanel = useMediaQuery("(min-width: 1280px)");
  const [selectedId, setSelectedId] = useState<number | "new" | null>(null);
  const [duplicating, setDuplicating] = useState<WorkoutTemplateResponse | null>(null);
  const [editorDirty, setEditorDirty] = useState(false);

  const { data, isLoading, isError, refetch } = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });
  const { data: exercises } = useQuery({ queryKey: queryKeys.exercises.all(), queryFn: exerciseApi.list });
  const { data: sessions } = useQuery({ queryKey: queryKeys.workoutSessions.all(), queryFn: workoutSessionApi.list });

  const templates = data ?? [];
  const sessionsDesc = (sessions ?? []).slice().sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());
  const now = new Date();
  const recommended = recommendedTemplate(sessionsDesc, templates);
  const items = pickerTemplates(templates, sessionsDesc, recommended?.id ?? null, now, false);
  const selected = typeof selectedId === "number" ? templates.find((x) => x.id === selectedId) ?? null : null;

  const duplicateMutation = useMutation({
    mutationFn: (tpl: WorkoutTemplateResponse) =>
      templateApi.create({ name: t("copyOf", { name: tpl.name }), exercises: tpl.exercises.map((e) => ({ exerciseId: e.exerciseId, targetSets: e.targetSets })) }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.workoutTemplates.all() });
      show(t("templateDuplicated"), "success");
      setDuplicating(null);
    },
    onError: () => show(t("duplicateTemplateFailed"), "error"),
  });

  const closeEditor = () => {
    setSelectedId(null);
    setEditorDirty(false);
  };

  const editor =
    selectedId != null ? (
      <TemplateEditorPanel
        key={selectedId}
        template={selected}
        exercises={exercises ?? []}
        bare={!sidePanel}
        onDirtyChange={setEditorDirty}
        onSaved={(id) => setSelectedId(id)}
        onDeleted={closeEditor}
      />
    ) : null;

  return (
    <div className={sidePanel ? "grid items-start gap-6" : undefined} style={sidePanel ? { gridTemplateColumns: "minmax(0, 1fr) 440px" } : undefined}>
      <div className="flex min-w-0 flex-col gap-3">
        <div className="flex justify-end">
          <Button variant="secondary" onClick={() => setSelectedId("new")}>
            <Icon name="add" size={20} />
            {t("newTemplate")}
          </Button>
        </div>

        {isLoading ? (
          <Skeleton variant="table" />
        ) : isError ? (
          <ErrorState onRetry={refetch} />
        ) : items.length === 0 ? (
          <EmptyState icon="list_alt" title={t("noTemplates")} body={t("createTemplate")} />
        ) : (
          <div className="flex flex-col gap-2">
            {items.map((item) => {
              const tpl = item.template;
              return (
                <div key={tpl.id} data-testid="template-row">
                  <TemplateTile
                    item={item}
                    selected={selectedId === tpl.id}
                    onClick={() => setSelectedId(tpl.id)}
                    footer={
                      <div className="flex items-center gap-1.5">
                        {onSchedule && (
                          <button
                            onClick={() => onSchedule(tpl)}
                            data-testid="schedule-template"
                            className="lifey-button flex h-7 w-7 shrink-0 items-center justify-center rounded-lg"
                            style={{ background: "var(--card)", color: "var(--text-2)" }}
                            aria-label={schedule("scheduleForClientAria")}
                          >
                            <Icon name="calendar_month" size={18} />
                          </button>
                        )}
                        <button
                          onClick={() => setDuplicating(tpl)}
                          disabled={duplicateMutation.isPending}
                          className="lifey-button flex h-7 w-7 shrink-0 items-center justify-center rounded-lg disabled:opacity-50"
                          style={{ background: "var(--card)", color: "var(--text-2)" }}
                          aria-label={t("duplicateTemplateAria")}
                        >
                          <Icon name="content_copy" size={18} />
                        </button>
                        {onAssign && (
                          <button
                            onClick={() => onAssign(tpl)}
                            data-testid="assign-template"
                            className="lifey-button ml-auto flex h-7 shrink-0 items-center gap-1 rounded-lg px-2.5 text-[11px] font-extrabold"
                            style={{ background: "rgba(110,154,106,.18)", color: "var(--tertiary)" }}
                          >
                            <Icon name="person_add" size={16} /> {admin("assignAction")}
                          </button>
                        )}
                      </div>
                    }
                  />
                </div>
              );
            })}
          </div>
        )}
      </div>

      {sidePanel && (
        <aside className="sticky top-4" aria-label={t("templatePanelAria")}>
          <Card>{editor ?? <UsagePanel templates={templates} sessions={sessions ?? []} now={now} />}</Card>
        </aside>
      )}
      {!sidePanel && editor && (
        <Drawer open onClose={closeEditor} width={520} title={selected ? t("editTemplate") : t("newTemplate")} isDirty={editorDirty}>
          {editor}
        </Drawer>
      )}

      <ConfirmModal
        open={duplicating !== null}
        onClose={() => setDuplicating(null)}
        onConfirm={() => duplicating && duplicateMutation.mutate(duplicating)}
        icon="content_copy"
        tint="var(--primary)"
        destructive={false}
        title={t("duplicateTemplateConfirmTitle")}
        body={t("duplicateTemplateConfirmBody")}
        cancelLabel={common("cancel")}
        confirmLabel={t("duplicateTemplateConfirmAction")}
      />
    </div>
  );
}

/** Nothing selected: per template, four little bars (one per week, this week last) and the total of the four weeks. */
function UsagePanel({ templates, sessions, now }: { templates: WorkoutTemplateResponse[]; sessions: Parameters<typeof templateUsage>[1]; now: Date }) {
  const t = useTranslations("workouts");
  const usage = templateUsage(templates, sessions, now, 4);
  const peak = Math.max(1, ...usage.flatMap((u) => u.perWeek));

  return (
    <div className="flex flex-col gap-4" data-testid="template-usage">
      <div>
        <h2 className="type-title">{t("usageTitle")}</h2>
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>
          {t("usageBody")}
        </p>
      </div>
      {usage.length === 0 ? (
        <p className="type-body-s" style={{ color: "var(--text-3)" }}>
          {t("selectOrCreate")}
        </p>
      ) : (
        <ul className="flex flex-col gap-3">
          {usage.map((u) => (
            <li key={u.templateId} data-testid="usage-row" className="flex items-center gap-3">
              <span className="type-body-s min-w-0 flex-1 truncate" style={{ fontWeight: 700 }}>
                {u.name}
              </span>
              <span className="flex h-8 items-end gap-1" aria-hidden>
                {u.perWeek.map((n, i) => (
                  <span
                    key={i}
                    data-testid="usage-bar"
                    style={{ width: 10, height: `${Math.max(12, (n / peak) * 100)}%`, borderRadius: 3, background: n > 0 ? "var(--primary)" : "var(--nested)" }}
                  />
                ))}
              </span>
              <span className="type-body-s tabular w-10 text-right" style={{ color: u.total > 0 ? "var(--text)" : "var(--text-3)", fontWeight: 700 }}>
                {t("usageTotal", { count: u.total })}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
