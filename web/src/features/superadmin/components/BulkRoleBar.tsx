"use client";

import { useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Icon, Menu, type MenuItemDef } from "@/components/ds";

interface Props {
  selectedCount: number;
  /** While a bulk run is going: "2 / 5". */
  progress: { completed: number; total: number } | null;
  onGrant: () => void;
  onRevoke: () => void;
  onClear: () => void;
}

/** "3 kijelölve · Szerepkör…" — appears over the table once rows are ticked; the menu offers the trainer grant / revoke. */
export function BulkRoleBar({ selectedCount, progress, onGrant, onRevoke, onClear }: Props) {
  const t = useTranslations("superadmin");
  const [open, setOpen] = useState(false);
  const anchorRef = useRef<HTMLSpanElement>(null);
  const items: MenuItemDef[] = [
    { label: t("makeTrainer"), icon: "add_moderator", onSelect: onGrant },
    { label: t("revokeTrainer"), icon: "remove_moderator", onSelect: onRevoke },
  ];

  return (
    <div
      className="flex flex-wrap items-center gap-3 px-4 py-2.5"
      style={{ borderRadius: "var(--r-control)", background: "color-mix(in srgb, var(--primary) 12%, var(--nested))" }}
      data-testid="bulk-role-bar"
      role="status"
    >
      <span className="type-body-s tabular" style={{ fontWeight: 700 }}>
        {progress ? t("bulkProgress", { completed: progress.completed, total: progress.total }) : t("selectedCount", { count: selectedCount })}
      </span>
      <span ref={anchorRef} className="inline-flex">
        <Button variant="secondary" onClick={() => setOpen(true)} disabled={progress !== null}>
          {t("roleAction")}
          <Icon name="expand_more" size={18} />
        </Button>
      </span>
      <Menu open={open} onClose={() => setOpen(false)} anchorRef={anchorRef} items={items} />
      <button type="button" onClick={onClear} disabled={progress !== null} className="lifey-button type-body-s ml-auto px-2 py-1" style={{ color: "var(--text-2)" }}>
        {t("clearSelection")}
      </button>
    </div>
  );
}
