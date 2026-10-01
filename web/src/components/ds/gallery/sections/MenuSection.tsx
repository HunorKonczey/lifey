"use client";

import { useRef, useState } from "react";
import { Card } from "../../Card";
import { Menu } from "../../Menu";
import { RowMenuButton } from "../../RowMenuButton";

/** D-W0.11 — a triggered Menu (arrow keys, typeahead, Esc, focus return)
 *  and the row "⋯" trigger, with a destructive last item. */
export function MenuSection() {
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const [lastAction, setLastAction] = useState("—");

  return (
    <Card className="flex items-center gap-8">
      <div>
        <button
          ref={triggerRef}
          type="button"
          onClick={() => setOpen(true)}
          className="lifey-button px-4 h-10 type-button-dense rounded-[var(--r-control)]"
          style={{ background: "var(--control)", color: "var(--text)" }}
        >
          Open menu
        </button>
        <Menu
          open={open}
          onClose={() => setOpen(false)}
          anchorRef={triggerRef}
          items={[
            { label: "Edit", icon: "edit", onSelect: () => setLastAction("Edit") },
            { label: "Duplicate", icon: "content_copy", shortcut: "⌘D", onSelect: () => setLastAction("Duplicate") },
            { label: "Delete", icon: "delete", destructive: true, onSelect: () => setLastAction("Delete") },
          ]}
        />
        <p className="type-body-s mt-2" style={{ color: "var(--text-3)" }}>
          Last action: {lastAction}
        </p>
      </div>

      <div className="flex items-center gap-2">
        <span className="type-body-s">A table row</span>
        <RowMenuButton
          items={[
            { label: "View", icon: "visibility", onSelect: () => {} },
            { label: "Archive", icon: "archive", onSelect: () => {} },
            { label: "Delete", icon: "delete", destructive: true, onSelect: () => {} },
          ]}
        />
      </div>
    </Card>
  );
}
