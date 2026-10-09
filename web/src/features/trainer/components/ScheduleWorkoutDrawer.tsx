"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { addMonths, eachDayOfInterval, format, isAfter, isBefore } from "date-fns";
import { trainerApi } from "../api";
import { templateApi } from "@/features/workouts/api";
import { ApiError } from "@/lib/api/client";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { Button, DateFields, Drawer, Icon, SegmentedControl, TextField, TimeField } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";
import { useTrainerBillingGate } from "@/features/billing/hooks";
import { BillingBlockedDialog } from "@/features/billing/components/BillingBlockedDialog";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";
import { DAYS_OF_WEEK, type DayOfWeek, type Recurrence } from "../types";

const JS_DAY_INDEX: Record<DayOfWeek, number> = {
  MONDAY: 1, TUESDAY: 2, WEDNESDAY: 3, THURSDAY: 4, FRIDAY: 5, SATURDAY: 6, SUNDAY: 0,
};

function todayIso() {
  return format(new Date(), "yyyy-MM-dd");
}

function estimateOccurrenceCount(recurrence: Recurrence, daysOfWeek: DayOfWeek[], startDate: string, endDate: string): number {
  if (!startDate) return 0;
  if (recurrence === "ONCE") return 1;
  if (!endDate || isBefore(new Date(`${endDate}T00:00:00`), new Date(`${startDate}T00:00:00`))) return 0;
  const days = eachDayOfInterval({ start: new Date(`${startDate}T00:00:00`), end: new Date(`${endDate}T00:00:00`) });
  if (recurrence === "DAILY") return days.length;
  const selected = new Set(daysOfWeek.map((d) => JS_DAY_INDEX[d]));
  return days.filter((d) => selected.has(d.getDay())).length;
}

interface ScheduleWorkoutDrawerProps {
  /* Client-detail entry point: the client is fixed, the trainer picks a template. */
  clientId?: number;
  clientName?: string;
  /* "/admin/workouts" template-card entry point: the template is fixed, the trainer picks a client. */
  templateId?: number;
  templateName?: string;
  /* Calendar day-header "+" entry point: preloads the start date instead of defaulting to today. */
  initialStartDate?: string;
  /* Calendar empty-cell entry point: preloads the time of day ("18:00") as well. */
  initialTimeOfDay?: string;
  onClose: () => void;
}

export function ScheduleWorkoutDrawer({
  clientId: fixedClientId, clientName: fixedClientName,
  templateId: fixedTemplateId, templateName: fixedTemplateName,
  initialStartDate,
  initialTimeOfDay,
  onClose,
}: ScheduleWorkoutDrawerProps) {
  const t = useTranslations("admin.schedule");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const gate = useTrainerBillingGate();

  const [templateSearch, setTemplateSearch] = useState("");
  const [clientSearch, setClientSearch] = useState("");
  const [templateId, setTemplateId] = useState<number | null>(fixedTemplateId ?? null);
  const [selectedClientId, setSelectedClientId] = useState<number | null>(fixedClientId ?? null);
  const [recurrence, setRecurrence] = useState<Recurrence>("ONCE");
  const [daysOfWeek, setDaysOfWeek] = useState<DayOfWeek[]>([]);
  const [timeOfDay, setTimeOfDay] = useState(initialTimeOfDay ?? "");
  const [startDate, setStartDate] = useState(initialStartDate ?? todayIso());
  const [endDate, setEndDate] = useState("");

  const templatesQ = useQuery({
    queryKey: queryKeys.workoutTemplates.all(),
    queryFn: templateApi.list,
    enabled: fixedTemplateId == null,
  });
  const clientsQ = useQuery({
    queryKey: queryKeys.trainerClients.all(),
    queryFn: trainerApi.clients,
    enabled: fixedClientId == null,
  });
  const assignedClientIdsQ = useQuery({
    queryKey: queryKeys.trainerAssignments.assignedClients("TEMPLATE", templateId ?? -1),
    queryFn: () => trainerApi.assignedClientIds("TEMPLATE", templateId as number),
    enabled: templateId != null && selectedClientId != null,
  });

  const filteredTemplates = (templatesQ.data ?? []).filter((tpl) =>
    tpl.name.toLowerCase().includes(templateSearch.toLowerCase()),
  );
  const filteredClients = (clientsQ.data ?? []).filter((c) =>
    c.clientEmail.toLowerCase().includes(clientSearch.toLowerCase()) ||
    clientDisplayName(c).toLowerCase().includes(clientSearch.toLowerCase()),
  );
  const alreadyAssigned =
    templateId != null && selectedClientId != null && (assignedClientIdsQ.data ?? []).includes(selectedClientId);

  const clientName =
    fixedClientName ?? (() => { const sel = clientsQ.data?.find((c) => c.clientId === selectedClientId); return sel ? clientDisplayName(sel) : ""; })();

  const maxEndDate = useMemo(() => addMonths(new Date(`${startDate || todayIso()}T00:00:00`), 3), [startDate]);
  const minDate = useMemo(() => new Date(`${todayIso()}T00:00:00`), []);

  const effectiveEndDate = recurrence === "ONCE" ? startDate : endDate;
  const occurrenceCount = estimateOccurrenceCount(recurrence, daysOfWeek, startDate, effectiveEndDate);

  const startValid = !!startDate && !isBefore(new Date(`${startDate}T00:00:00`), minDate);
  const endValid =
    recurrence === "ONCE" ||
    (!!endDate &&
      !isBefore(new Date(`${endDate}T00:00:00`), new Date(`${startDate}T00:00:00`)) &&
      !isAfter(new Date(`${endDate}T00:00:00`), maxEndDate));
  const daysValid = recurrence !== "WEEKLY" || daysOfWeek.length > 0;
  const isValid = templateId != null && selectedClientId != null && startValid && endValid && daysValid;

  const toggleDay = (day: DayOfWeek) => {
    setDaysOfWeek((prev) => (prev.includes(day) ? prev.filter((d) => d !== day) : [...prev, day]));
  };

  const createMutation = useMutation({
    mutationFn: () =>
      trainerApi.createSchedule({
        clientId: selectedClientId as number,
        templateId: templateId as number,
        recurrence,
        daysOfWeek: recurrence === "WEEKLY" ? daysOfWeek : [],
        timeOfDay: timeOfDay || null,
        startDate,
        endDate: effectiveEndDate,
      }),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerSchedules.forClient(selectedClientId as number) });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerTemplates.usage() });
      queryClient.invalidateQueries({ queryKey: ["trainer-calendar"] });
      show(t("scheduled", { count: res.occurrencesCreated, name: clientName }), "success");
      onClose();
    },
    onError: (e) => {
      if (e instanceof ApiError && e.status === 422) {
        show(t("horizonExceeded"), "error");
      } else {
        show(t("createFailed"), "error");
      }
    },
  });

  // D-T5: the trigger button that opens this drawer stays visible and
  // enabled-looking; a blocked trainer sees this dialog the moment it would
  // have opened, instead of filling out a form that can only fail.
  if (gate.state !== "OK") {
    return (
      <BillingBlockedDialog
        open
        onClose={onClose}
        reason={gate.state === "RESTRICTED" ? "restricted" : "overLimit"}
        currentPlan={gate.currentPlan}
        activeClients={gate.activeClients}
        maxClients={gate.maxClients}
      />
    );
  }

  const parseIso = (iso: string) => (iso ? new Date(`${iso}T00:00:00`) : null);
  const toIso = (d: Date | null) => (d ? format(d, "yyyy-MM-dd") : "");
  const dirty = templateId !== (fixedTemplateId ?? null) || selectedClientId !== (fixedClientId ?? null) || recurrence !== "ONCE" || daysOfWeek.length > 0 || timeOfDay !== (initialTimeOfDay ?? "") || endDate !== "" || startDate !== (initialStartDate ?? todayIso());

  const rowStyle = (selected: boolean) => ({
    background: selected ? "var(--primary-tint)" : "var(--nested)",
    boxShadow: selected ? "inset 0 0 0 2px var(--primary)" : undefined,
    borderRadius: "var(--r-control)",
  });
  const sectionLabel = (text: string) => (
    <p className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 800, letterSpacing: "0.06em", textTransform: "uppercase" }}>{text}</p>
  );

  return (
    <Drawer
      open
      onClose={onClose}
      width={480}
      title={fixedClientId != null ? t("drawerTitle", { name: clientName }) : t("drawerTitleGeneric")}
      isDirty={dirty}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>{t("cancel")}</Button>
          <Button onClick={() => createMutation.mutate()} disabled={!isValid || createMutation.isPending} data-testid="schedule-drawer-submit">
            {createMutation.isPending ? t("scheduling") : t("scheduleAction")}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-6" data-testid="schedule-workout-drawer">
        <div className="flex flex-col gap-2">
          {sectionLabel(t("template"))}
          {fixedTemplateId != null ? (
            <div className="flex items-center gap-3 px-3 py-2.5" style={rowStyle(false)}>
              <Icon name="fitness_center" size={20} fill={1} color="var(--role)" />
              <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 700 }}>{fixedTemplateName}</span>
            </div>
          ) : (
            <>
              <TextField size="dense" leadingIcon="search" aria-label={t("template")} placeholder={t("searchTemplatePlaceholder")} value={templateSearch} onChange={(e) => setTemplateSearch(e.target.value)} />
              <div className="flex flex-col gap-1.5 max-h-[220px] overflow-y-auto">
                {templatesQ.isError ? (
                  <ErrorState inline onRetry={() => templatesQ.refetch()} />
                ) : filteredTemplates.length === 0 ? (
                  <p className="type-body-s text-center py-3" style={{ color: "var(--text-3)" }}>{t("noTemplatesFound")}</p>
                ) : (
                  filteredTemplates.map((tpl) => {
                    const selected = tpl.id === templateId;
                    return (
                      <button key={tpl.id} type="button" data-testid="schedule-drawer-template-row" onClick={() => setTemplateId(tpl.id)} aria-pressed={selected} className="lifey-button flex items-center gap-3 px-3 py-2.5 text-left" style={rowStyle(selected)}>
                        <Icon name="fitness_center" size={20} fill={1} color="var(--role)" />
                        <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 700 }}>{tpl.name}</span>
                        {selected && <Icon name="check_circle" size={20} fill={1} color="var(--primary)" />}
                      </button>
                    );
                  })
                )}
              </div>
            </>
          )}
          {alreadyAssigned === false && (
            <div className="flex items-center gap-2 px-3 py-2" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
              <Icon name="info" size={18} color="var(--text-2)" />
              <span className="type-body-s" style={{ color: "var(--text-2)" }}>{t("willCopyTemplate")}</span>
            </div>
          )}
        </div>

        {fixedClientId == null && (
          <div className="flex flex-col gap-2">
            {sectionLabel(t("client"))}
            <TextField size="dense" leadingIcon="search" aria-label={t("client")} placeholder={t("searchClientPlaceholder")} value={clientSearch} onChange={(e) => setClientSearch(e.target.value)} />
            <div className="flex flex-col gap-1.5 max-h-[200px] overflow-y-auto">
              {clientsQ.isError ? (
                <ErrorState inline onRetry={() => clientsQ.refetch()} />
              ) : filteredClients.length === 0 ? (
                <p className="type-body-s text-center py-3" style={{ color: "var(--text-3)" }}>{t("noClientsFound")}</p>
              ) : (
                filteredClients.map((c) => {
                  const selected = c.clientId === selectedClientId;
                  return (
                    <button key={c.clientId} type="button" data-testid="schedule-drawer-client-row" onClick={() => setSelectedClientId(c.clientId)} aria-pressed={selected} className="lifey-button flex items-center gap-3 px-3 py-2.5 text-left" style={rowStyle(selected)}>
                      <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={32} />
                      <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 700 }}>{clientDisplayName(c)}</span>
                      {selected && <Icon name="check_circle" size={20} fill={1} color="var(--primary)" />}
                    </button>
                  );
                })
              )}
            </div>
          </div>
        )}

        <div className="flex flex-col gap-3">
          {sectionLabel(t("recurrence.label"))}
          <SegmentedControl<Recurrence>
            aria-label={t("recurrence.label")}
            options={[
              { value: "ONCE", label: t("recurrence.once") },
              { value: "DAILY", label: t("recurrence.daily") },
              { value: "WEEKLY", label: t("recurrence.weekly") },
            ]}
            value={recurrence}
            onChange={setRecurrence}
          />
          {recurrence === "WEEKLY" && (
            <div className="flex flex-wrap gap-2" role="group" aria-label={t("recurrence.weekly")}>
              {DAYS_OF_WEEK.map((day) => {
                const selected = daysOfWeek.includes(day);
                return (
                  <button
                    key={day}
                    type="button"
                    onClick={() => toggleDay(day)}
                    aria-pressed={selected}
                    className="lifey-button inline-flex items-center justify-center h-10 w-10"
                    style={{ borderRadius: 999, fontWeight: 700, fontSize: 13, background: selected ? "var(--primary)" : "var(--control)", color: selected ? "var(--on-primary)" : "var(--text-2)" }}
                  >
                    {t(`daysShort.${day}`)}
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <div className="flex flex-col gap-4">
          {sectionLabel(t("dates"))}
          <DateFields label={recurrence === "ONCE" ? t("date") : t("startDate")} value={parseIso(startDate)} onChange={(d) => setStartDate(toIso(d))} error={startValid ? undefined : t("dateInvalid")} />
          {recurrence !== "ONCE" && (
            <DateFields label={t("endDate")} value={parseIso(endDate)} onChange={(d) => setEndDate(toIso(d))} error={endDate && !endValid ? t("endDateInvalid") : undefined} hint={t("endDatePlaceholder")} />
          )}
          <TimeField label={t("timeOfDay")} value={timeOfDay} onChange={setTimeOfDay} quickTimes={["07:00", "17:30", "18:00"]} />
        </div>

        {isValid && occurrenceCount > 0 && (
          <div className="p-4" style={{ borderRadius: "var(--r-card)", background: "var(--nested)" }}>
            <p style={{ fontWeight: 700 }}>{t("previewCount", { count: occurrenceCount })}</p>
          </div>
        )}
      </div>
    </Drawer>
  );
}
