"use client";

import { useState } from "react";
import { useDraggable } from "@dnd-kit/core";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { Card, Icon, TextField } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";

export interface RailTemplate {
  id: number;
  name: string;
  exercises: unknown[];
}

interface ProgramTemplateRailProps {
  templates: RailTemplate[];
  error: boolean;
  onRetry: () => void;
  /** The template waiting to be placed — click a cell (or press Enter on it) to put it there. */
  selectedId: number | null;
  onSelect: (id: number | null) => void;
}

/**
 * "Sablonok" (W8-B): the left rail of the program editor — a search and every workout template as a row (grip, name,
 * "6 gyakorlat"). A row is picked with a click or Space and then placed with a click or Enter on a cell — the keyboard
 * alternative to dragging — and the same rows are the drag sources (W8.5). "+ Új sablon" goes to the templates page.
 */
export function ProgramTemplateRail({ templates, error, onRetry, selectedId, onSelect }: ProgramTemplateRailProps) {
  const t = useTranslations("admin.programs");
  const [search, setSearch] = useState("");
  const filtered = templates.filter((tpl) => tpl.name.toLowerCase().includes(search.trim().toLowerCase()));

  return (
    <Card variant="card" className="flex flex-col gap-3 lg:sticky lg:top-24 lg:max-h-[calc(100vh-8rem)]" data-testid="program-template-rail">
      <h2 style={{ fontSize: 18, fontWeight: 800 }}>{t("templatesTitle")}</h2>
      <TextField size="dense" leadingIcon="search" aria-label={t("templatesTitle")} placeholder={t("searchTemplatePlaceholder")} value={search} onChange={(e) => setSearch(e.target.value)} />
      <div className="flex flex-col gap-1.5 min-h-0 overflow-y-auto" role="listbox" aria-label={t("templatesTitle")}>
        {error ? (
          <ErrorState inline onRetry={onRetry} />
        ) : filtered.length === 0 ? (
          <p className="type-body-s text-center py-3" style={{ color: "var(--text-3)" }}>{t("noTemplatesFound")}</p>
        ) : (
          filtered.map((tpl) => <RailRow key={tpl.id} tpl={tpl} selected={tpl.id === selectedId} onSelect={onSelect} />)
        )}
      </div>
      {selectedId != null && <p className="type-body-s" style={{ color: "var(--primary)", fontWeight: 600 }}>{t("placeHint")}</p>}
      <Link href="/admin/workouts" className="type-body-s inline-flex items-center gap-1" style={{ color: "var(--primary)", fontWeight: 700 }}>
        <Icon name="add" size={16} />
        {t("newTemplate")}
      </Link>
    </Card>
  );
}

/**
 * One template row: the row itself picks (click / Space) for the click-to-place path, and its grip is the drag handle —
 * a separate button, so Space on the row never starts a drag and the drag keeps its own keyboard sensor.
 */
function RailRow({ tpl, selected, onSelect }: { tpl: RailTemplate; selected: boolean; onSelect: (id: number | null) => void }) {
  const t = useTranslations("admin.programs");
  const { attributes, listeners, setNodeRef, isDragging } = useDraggable({ id: `tpl-${tpl.id}`, data: { kind: "template", templateId: tpl.id } });
  return (
    <div
      ref={setNodeRef}
      className="flex items-stretch gap-0.5"
      style={{ borderRadius: "var(--r-control)", background: selected ? "var(--primary-tint)" : "var(--nested)", boxShadow: selected ? "inset 0 0 0 2px var(--primary)" : undefined, opacity: isDragging ? 0.45 : 1 }}
    >
      <button
        type="button"
        {...attributes}
        {...listeners}
        aria-label={t("dragTemplate", { name: tpl.name })}
        data-testid="program-rail-grip"
        className="lifey-button inline-flex w-9 items-center justify-center touch-none cursor-grab"
        style={{ borderRadius: "var(--r-control)", color: "var(--text-3)" }}
      >
        <Icon name="drag_indicator" size={20} />
      </button>
      <button
        type="button"
        role="option"
        aria-selected={selected}
        data-testid="program-rail-template"
        data-template-id={tpl.id}
        onClick={() => onSelect(selected ? null : tpl.id)}
        className="lifey-button flex flex-1 min-w-0 flex-col py-2.5 pr-2.5 text-left"
        style={{ borderRadius: "var(--r-control)" }}
      >
        <span className="truncate" style={{ fontWeight: 700 }}>{tpl.name}</span>
        <span className="type-body-s" style={{ color: "var(--text-2)" }}>{t("exerciseCount", { count: tpl.exercises.length })}</span>
      </button>
    </div>
  );
}
