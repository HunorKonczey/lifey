"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import type { TrainerClientResponse } from "../types";

interface CalendarClientFilterProps {
  clients: TrainerClientResponse[];
  deselectedClientIds: Set<number>;
  onToggleClient: (clientId: number) => void;
  onToggleAll: () => void;
}

/** Multi-select client filter for the trainer calendar toolbar (design: A frame, top-right dropdown). */
export function CalendarClientFilter({ clients, deselectedClientIds, onToggleClient, onToggleAll }: CalendarClientFilterProps) {
  const t = useTranslations("admin.calendar");
  const tAssignments = useTranslations("admin.assignments");
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  const selectedCount = clients.filter((c) => !deselectedClientIds.has(c.clientId)).length;
  const allSelected = deselectedClientIds.size === 0;

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("mousedown", onPointerDown);
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("mousedown", onPointerDown);
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  return (
    <div ref={rootRef} className="relative" data-testid="calendar-client-filter">
      <button
        onClick={() => setOpen((o) => !o)}
        data-testid="calendar-client-filter-trigger"
        className="flex items-center gap-2 rounded-[11px] pl-2 pr-2.5 py-1.5"
        style={{ background: "var(--bg)" }}
      >
        <div className="flex">
          {clients.slice(0, 3).map((c, i) => (
            <div key={c.clientId} style={{ marginLeft: i === 0 ? 0 : -7 }}>
              <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={22} />
            </div>
          ))}
        </div>
        <span className="text-[12.5px] font-bold" style={{ color: "var(--on-surface)" }}>
          {allSelected ? tAssignments("allClients") : t("clientsSelected", { selected: selectedCount, total: clients.length })}
        </span>
        <span className="material-symbols-rounded text-lg" style={{ color: "var(--on-surface-variant)" }}>
          arrow_drop_down
        </span>
      </button>

      {open && (
        <div
          className="absolute right-0 top-[calc(100%+6px)] w-[252px] rounded-2xl p-[7px] z-30"
          style={{ background: "var(--surface-highest)", boxShadow: "0 18px 44px rgba(0,0,0,.55)" }}
        >
          <button
            onClick={onToggleAll}
            data-testid="calendar-client-filter-all"
            className="w-full flex items-center gap-2.5 rounded-[11px] px-2.5 py-2"
            style={{ background: allSelected ? "var(--outline)" : "transparent" }}
          >
            <Checkbox checked={allSelected} />
            <span className="flex-1 text-[13px] font-bold text-left" style={{ color: "var(--on-surface)" }}>
              {tAssignments("allClients")}
            </span>
          </button>
          <div className="h-px mx-2 my-1.5" style={{ background: "var(--outline)" }} />
          {clients.map((c) => {
            const checked = !deselectedClientIds.has(c.clientId);
            return (
              <button
                key={c.clientId}
                onClick={() => onToggleClient(c.clientId)}
                data-testid="calendar-client-filter-row"
                className="w-full flex items-center gap-2.5 rounded-[11px] px-2.5 py-1.5"
              >
                <Checkbox checked={checked} />
                <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={26} />
                <span className="flex-1 text-[13px] font-semibold text-left truncate" style={{ color: "var(--on-surface)" }}>
                  {nameFor(c.clientEmail)}
                </span>
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

function Checkbox({ checked }: { checked: boolean }) {
  return (
    <span
      className="w-[18px] h-[18px] rounded-[6px] flex items-center justify-center shrink-0"
      style={{ background: checked ? "var(--tertiary)" : "transparent", border: checked ? "none" : "1.5px solid var(--outline)" }}
    >
      {checked && (
        <span className="material-symbols-rounded text-[13px]" style={{ color: "#161611" }}>
          check
        </span>
      )}
    </span>
  );
}
