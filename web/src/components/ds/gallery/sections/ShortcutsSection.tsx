"use client";

import { useCallback, useMemo, useRef, useState } from "react";
import { ShortcutHelp } from "@/components/shell/ShortcutHelp";
import { useHotkeys } from "@/lib/hooks/useHotkeys";
import { usePageShortcuts } from "@/lib/hooks/usePageShortcuts";

/** Stand-ins for a role's nav items — the real ones navigate away from the
 *  gallery, so these only change the hash (which is all the spec asserts). */
const DEMO_ITEMS = [
  { href: "/dev/design#go-dashboard", shortcut: "D" },
  { href: "/dev/design#go-workouts", shortcut: "W" },
];

/**
 * D-W0.17's shortcut layer, standalone — `AppShell` owns it in the real app,
 * but the gallery has no shell, so this mounts the same `useHotkeys` +
 * `ShortcutHelp` pair together with a fake page that registers `N` and `/`.
 */
export function ShortcutsSection() {
  const [helpOpen, setHelpOpen] = useState(false);
  const [newCount, setNewCount] = useState(0);
  const searchRef = useRef<HTMLInputElement>(null);
  const openHelp = useCallback(() => setHelpOpen(true), []);
  const onNew = useCallback(() => setNewCount((c) => c + 1), []);
  const items = useMemo(() => DEMO_ITEMS, []);

  useHotkeys({ goToItems: items, onHelp: openHelp, suppressed: helpOpen });
  usePageShortcuts({ onNew, newLabel: "Add a demo entry", searchRef });

  return (
    <div className="flex flex-col gap-3 p-6" style={{ background: "var(--card)", borderRadius: "var(--r-card)" }}>
      <p className="type-body-s" style={{ color: "var(--text-2)" }}>
        Press <kbd>?</kbd> for the shortcut list, <kbd>N</kbd> to add, <kbd>/</kbd> to search, <kbd>G</kbd> then <kbd>D</kbd> or{" "}
        <kbd>W</kbd> to jump.
      </p>
      <input
        ref={searchRef}
        aria-label="Demo search"
        placeholder="Search…"
        className="type-body h-10 px-3"
        style={{ background: "var(--nested)", borderRadius: "var(--r-field)" }}
      />
      <p className="type-body-s" data-testid="new-count">
        Entries added: {newCount}
      </p>
      <ShortcutHelp open={helpOpen} onClose={() => setHelpOpen(false)} />
    </div>
  );
}
