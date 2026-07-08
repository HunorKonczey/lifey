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
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { DatePicker } from "@/components/ui/DatePicker";
import { TimePicker } from "@/components/ui/TimePicker";
import { ErrorState } from "@/components/status/ErrorState";
import { ClientAvatar, nameFor } from "./ClientAvatar";
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
  onClose: () => void;
}

export function ScheduleWorkoutDrawer({
  clientId: fixedClientId, clientName: fixedClientName,
  templateId: fixedTemplateId, templateName: fixedTemplateName,
  initialStartDate,
  onClose,
}: ScheduleWorkoutDrawerProps) {
  const t = useTranslations("admin.schedule");
  const queryClient = useQueryClient();
  const { show } = useToast();

  const [templateSearch, setTemplateSearch] = useState("");
  const [clientSearch, setClientSearch] = useState("");
  const [templateId, setTemplateId] = useState<number | null>(fixedTemplateId ?? null);
  const [selectedClientId, setSelectedClientId] = useState<number | null>(fixedClientId ?? null);
  const [recurrence, setRecurrence] = useState<Recurrence>("ONCE");
  const [daysOfWeek, setDaysOfWeek] = useState<DayOfWeek[]>([]);
  const [timeOfDay, setTimeOfDay] = useState("");
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
    nameFor(c.clientEmail).toLowerCase().includes(clientSearch.toLowerCase()),
  );
  const alreadyAssigned =
    templateId != null && selectedClientId != null && (assignedClientIdsQ.data ?? []).includes(selectedClientId);

  const clientName =
    fixedClientName ?? nameFor(clientsQ.data?.find((c) => c.clientId === selectedClientId)?.clientEmail ?? "");

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

  return (
    <div className="fixed inset-0 z-50 flex justify-end" data-testid="schedule-workout-drawer">
      <div className="absolute inset-0" style={{ background: "rgba(8,9,6,.45)" }} onClick={onClose} />
      <div
        className="relative w-full max-w-[420px] h-full flex flex-col gap-4 p-5.5 overflow-y-auto"
        style={{ background: "var(--surface-container)", boxShadow: "-20px 0 50px rgba(0,0,0,.45)" }}
      >
        <div className="flex items-center justify-between">
          <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
            {fixedClientId != null ? t("drawerTitle", { name: clientName }) : t("drawerTitleGeneric")}
          </p>
          <button onClick={onClose} style={{ color: "var(--on-surface-variant)" }} aria-label={t("close")}>
            <span className="material-symbols-rounded text-xl">close</span>
          </button>
        </div>

        <div className="flex flex-col gap-2">
          <p className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
            {t("template")}
          </p>
          {fixedTemplateId != null ? (
            <div className="flex items-center gap-3 rounded-2xl px-3 py-2.5" style={{ background: "var(--surface)" }}>
              <span
                className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                style={{ background: "var(--surface-high)", color: "var(--tertiary)" }}
              >
                <span className="material-symbols-rounded text-lg">fitness_center</span>
              </span>
              <span className="flex-1 min-w-0 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                {fixedTemplateName}
              </span>
            </div>
          ) : (
            <>
              <div className="rounded-2xl h-11 flex items-center gap-2.5 px-4" style={{ background: "var(--surface)" }} data-ring-frame>
                <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>search</span>
                <input
                  value={templateSearch}
                  onChange={(e) => setTemplateSearch(e.target.value)}
                  placeholder={t("searchTemplatePlaceholder")}
                  className="flex-1 bg-transparent outline-none text-sm"
                  style={{ color: "var(--on-surface)" }}
                />
              </div>
              <div className="flex flex-col gap-1.5 max-h-[180px] overflow-y-auto">
                {templatesQ.isError ? (
                  <ErrorState inline onRetry={() => templatesQ.refetch()} />
                ) : filteredTemplates.length === 0 ? (
                  <p className="text-xs text-center py-3" style={{ color: "var(--muted)" }}>{t("noTemplatesFound")}</p>
                ) : (
                  filteredTemplates.map((tpl) => {
                    const selected = tpl.id === templateId;
                    return (
                      <button
                        key={tpl.id}
                        data-testid="schedule-drawer-template-row"
                        onClick={() => setTemplateId(tpl.id)}
                        className="flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors text-left"
                        style={{
                          background: selected ? "rgba(110,154,106,.14)" : "transparent",
                          border: selected ? "1.5px solid var(--tertiary)" : "1.5px solid transparent",
                        }}
                      >
                        <span
                          className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                          style={{ background: "var(--surface-high)", color: "var(--tertiary)" }}
                        >
                          <span className="material-symbols-rounded text-lg">fitness_center</span>
                        </span>
                        <span className="flex-1 min-w-0 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                          {tpl.name}
                        </span>
                        {selected && (
                          <span className="material-symbols-rounded text-xl" style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}>
                            check_circle
                          </span>
                        )}
                      </button>
                    );
                  })
                )}
              </div>
            </>
          )}
          {alreadyAssigned === false && (
            <div className="flex items-center gap-2 rounded-xl px-3 py-2" style={{ background: "var(--surface)" }}>
              <span className="material-symbols-rounded text-base" style={{ color: "var(--on-surface-variant)" }}>info</span>
              <span className="text-[11.5px]" style={{ color: "var(--on-surface-variant)" }}>{t("willCopyTemplate")}</span>
            </div>
          )}
        </div>

        {fixedClientId == null && (
          <div className="flex flex-col gap-2">
            <p className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
              {t("client")}
            </p>
            <div className="rounded-2xl h-11 flex items-center gap-2.5 px-4" style={{ background: "var(--surface)" }} data-ring-frame>
              <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>search</span>
              <input
                value={clientSearch}
                onChange={(e) => setClientSearch(e.target.value)}
                placeholder={t("searchClientPlaceholder")}
                className="flex-1 bg-transparent outline-none text-sm"
                style={{ color: "var(--on-surface)" }}
              />
            </div>
            <div className="flex flex-col gap-1.5 max-h-[180px] overflow-y-auto">
              {clientsQ.isError ? (
                <ErrorState inline onRetry={() => clientsQ.refetch()} />
              ) : filteredClients.length === 0 ? (
                <p className="text-xs text-center py-3" style={{ color: "var(--muted)" }}>{t("noClientsFound")}</p>
              ) : (
                filteredClients.map((c) => {
                  const selected = c.clientId === selectedClientId;
                  return (
                    <button
                      key={c.clientId}
                      data-testid="schedule-drawer-client-row"
                      onClick={() => setSelectedClientId(c.clientId)}
                      className="flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors text-left"
                      style={{
                        background: selected ? "rgba(110,154,106,.14)" : "transparent",
                        border: selected ? "1.5px solid var(--tertiary)" : "1.5px solid transparent",
                      }}
                    >
                      <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={32} />
                      <span className="flex-1 min-w-0 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                        {nameFor(c.clientEmail)}
                      </span>
                      {selected && (
                        <span className="material-symbols-rounded text-xl" style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}>
                          check_circle
                        </span>
                      )}
                    </button>
                  );
                })
              )}
            </div>
          </div>
        )}

        <div className="flex flex-col gap-2">
          <p className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
            {t("recurrence.label")}
          </p>
          <SegmentedControl
            options={[
              { value: "ONCE", label: t("recurrence.once") },
              { value: "DAILY", label: t("recurrence.daily") },
              { value: "WEEKLY", label: t("recurrence.weekly") },
            ]}
            value={recurrence}
            onChange={setRecurrence}
            activeBackground="var(--tertiary)"
            activeColor="#161611"
          />
          {recurrence === "WEEKLY" && (
            <div className="flex flex-wrap gap-1.5 mt-1">
              {DAYS_OF_WEEK.map((day) => {
                const selected = daysOfWeek.includes(day);
                return (
                  <button
                    key={day}
                    onClick={() => toggleDay(day)}
                    className="w-9 h-9 rounded-full text-xs font-bold transition-colors"
                    style={{
                      background: selected ? "var(--tertiary)" : "var(--surface)",
                      color: selected ? "#161611" : "var(--on-surface-variant)",
                    }}
                  >
                    {t(`daysShort.${day}`)}
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <div className="flex flex-col gap-2">
          <p className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
            {t("dates")}
          </p>
          <DatePicker value={startDate} onChange={setStartDate} min={minDate} hasError={!startValid} />
          {recurrence !== "ONCE" && (
            <DatePicker
              value={endDate}
              onChange={setEndDate}
              min={new Date(`${startDate || todayIso()}T00:00:00`)}
              max={maxEndDate}
              placeholder={t("endDatePlaceholder")}
              hasError={!endValid}
            />
          )}
          <div className="flex flex-col gap-1">
            <label className="text-[11px] font-semibold" style={{ color: "var(--muted)" }}>{t("timeOfDay")}</label>
            <TimePicker value={timeOfDay} onChange={setTimeOfDay} />
          </div>
        </div>

        {isValid && occurrenceCount > 0 && (
          <div className="rounded-2xl p-4" style={{ background: "var(--surface)" }}>
            <p className="text-[13px] font-bold" style={{ color: "var(--on-surface)" }}>
              {t("previewCount", { count: occurrenceCount })}
            </p>
          </div>
        )}

        <div className="mt-auto flex gap-2.5 pt-2">
          <button onClick={onClose} className="flex-1 text-center text-[13.5px] font-bold py-3 rounded-2xl" style={{ color: "var(--on-surface-variant)" }}>
            {t("cancel")}
          </button>
          <button
            onClick={() => createMutation.mutate()}
            disabled={!isValid || createMutation.isPending}
            data-testid="schedule-drawer-submit"
            className="flex-[2] text-center rounded-2xl py-3 text-[13.5px] font-extrabold disabled:opacity-40"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            {createMutation.isPending ? t("scheduling") : t("scheduleAction")}
          </button>
        </div>
      </div>
    </div>
  );
}
