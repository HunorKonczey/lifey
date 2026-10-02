"use client";

import { useTranslations } from "next-intl";
import { Modal } from "@/components/ds/overlay/Modal";
import { usePageShortcutsStore } from "@/lib/hooks/usePageShortcuts";

export interface ShortcutHelpProps {
  open: boolean;
  onClose: () => void;
}

function Row({ keys, label }: { keys: string; label: string }) {
  return (
    <div className="flex items-center justify-between gap-4 py-1.5">
      <span className="type-body-s" style={{ color: "var(--text-2)" }}>
        {label}
      </span>
      <kbd
        className="type-label shrink-0"
        style={{ background: "var(--nested)", color: "var(--text)", borderRadius: "var(--r-tag)", padding: "3px 8px" }}
      >
        {keys}
      </kbd>
    </div>
  );
}

function Divider() {
  return <div className="my-3" style={{ borderTop: "1px solid var(--hairline)" }} />;
}

/**
 * DS-06's `?` help overlay (D-W0.17): global shortcuts, the table
 * conventions, and — only when the current page registered one via
 * `usePageShortcuts` — its own `N`/`/` targets.
 */
export function ShortcutHelp({ open, onClose }: ShortcutHelpProps) {
  const s = useTranslations("shortcuts");
  const { onNew, newLabel, searchRef } = usePageShortcutsStore();

  return (
    <Modal open={open} onClose={onClose} width={480} aria-label={s("title")}>
      <div className="p-6">
        <h2 className="type-title-l mb-4">{s("title")}</h2>

        {(onNew || searchRef) && (
          <>
            <p className="type-label mb-1" style={{ color: "var(--text-3)" }}>
              {s("pageSection")}
            </p>
            {onNew && <Row keys="N" label={newLabel ?? ""} />}
            {searchRef && <Row keys="/" label={s("search")} />}
            <Divider />
          </>
        )}

        <p className="type-label mb-1" style={{ color: "var(--text-3)" }}>
          {s("globalSection")}
        </p>
        <Row keys="← / →" label={s("dayStep")} />
        <Row keys="T" label={s("jumpToday")} />
        <Row keys="[" label={s("toggleSidebar")} />
        <Row keys="G …" label={s("goToPage")} />
        <Row keys="?" label={s("help")} />

        <Divider />

        <p className="type-label mb-1" style={{ color: "var(--text-3)" }}>
          {s("tableSection")}
        </p>
        <Row keys="↑ / ↓" label={s("tableRow")} />
        <Row keys="Enter" label={s("tableOpen")} />
        <Row keys="Shift+F10" label={s("tableRowMenu")} />
      </div>
    </Modal>
  );
}
