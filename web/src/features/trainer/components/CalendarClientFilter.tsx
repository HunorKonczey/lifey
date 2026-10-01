"use client";

import { useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Checkbox, Icon, Popover } from "@/components/ds";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";
import type { TrainerClientResponse } from "../types";

interface CalendarClientFilterProps {
  clients: TrainerClientResponse[];
  deselectedClientIds: Set<number>;
  onToggleClient: (clientId: number) => void;
  onToggleAll: () => void;
}

/** "Minden kliens" (W8-A): the multi-select client filter — a DS popover of checkboxes; the choice lives in the calendar, so it holds across Nap · Hét · Hónap. */
export function CalendarClientFilter({ clients, deselectedClientIds, onToggleClient, onToggleAll }: CalendarClientFilterProps) {
  const t = useTranslations("admin.calendar");
  const tAssignments = useTranslations("admin.assignments");
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);

  const selectedCount = clients.filter((c) => !deselectedClientIds.has(c.clientId)).length;
  const allSelected = deselectedClientIds.size === 0;

  return (
    <div data-testid="calendar-client-filter">
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="dialog"
        aria-expanded={open}
        data-testid="calendar-client-filter-trigger"
        className="lifey-button inline-flex items-center gap-2 pl-2.5 pr-2 h-11 md:h-10"
        style={{ borderRadius: "var(--r-control)", background: "var(--control)" }}
      >
        <span className="flex">
          {clients.slice(0, 3).map((c, i) => (
            <span key={c.clientId} style={{ marginLeft: i === 0 ? 0 : -7 }}>
              <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={22} />
            </span>
          ))}
        </span>
        <span className="type-body-s" style={{ fontWeight: 700 }}>
          {allSelected ? tAssignments("allClients") : t("clientsSelected", { selected: selectedCount, total: clients.length })}
        </span>
        <Icon name="arrow_drop_down" size={20} color="var(--text-2)" />
      </button>

      <Popover open={open} onClose={() => setOpen(false)} anchorRef={triggerRef} width={272}>
        <div className="flex flex-col gap-0.5 p-2 max-h-[360px] overflow-y-auto" role="group" aria-label={tAssignments("allClients")}>
          <button type="button" onClick={onToggleAll} data-testid="calendar-client-filter-all" className="lifey-button flex items-center gap-2.5 px-2.5 py-2 text-left" style={{ borderRadius: "var(--r-control)", background: allSelected ? "var(--nested)" : "transparent" }}>
            <Checkbox checked={allSelected} onChange={() => {}} aria-label={tAssignments("allClients")} />
            <span className="flex-1" style={{ fontWeight: 700 }}>{tAssignments("allClients")}</span>
          </button>
          <div className="h-px mx-2 my-1" style={{ background: "var(--hairline)" }} />
          {clients.map((c) => {
            const checked = !deselectedClientIds.has(c.clientId);
            return (
              <button key={c.clientId} type="button" onClick={() => onToggleClient(c.clientId)} data-testid="calendar-client-filter-row" className="lifey-button flex items-center gap-2.5 px-2.5 py-1.5 text-left" style={{ borderRadius: "var(--r-control)" }}>
                <Checkbox checked={checked} onChange={() => {}} aria-label={clientDisplayName(c)} />
                <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={26} />
                <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 600 }}>{clientDisplayName(c)}</span>
              </button>
            );
          })}
        </div>
      </Popover>
    </div>
  );
}
