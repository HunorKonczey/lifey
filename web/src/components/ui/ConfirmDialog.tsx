"use client";

import { useTranslations } from "next-intl";
import { Dialog } from "./Dialog";

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  body: string;
  confirmLabel: string;
  onConfirm: () => void;
  onCancel: () => void;
  confirming?: boolean;
}

/** Generic yes/no confirmation modal, built on top of {@link Dialog}. */
export function ConfirmDialog({
  open, title, body, confirmLabel, onConfirm, onCancel, confirming,
}: ConfirmDialogProps) {
  const common = useTranslations("common");

  return (
    <Dialog open={open} onClose={onCancel} title={title}>
      <div className="flex flex-col gap-4">
        <p className="text-sm" style={{ color: "var(--on-surface-variant)" }}>{body}</p>
        <div className="flex gap-3">
          <button onClick={onCancel}
            className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm"
            style={{ background: "var(--surface-container)", color: "var(--on-surface)" }}>
            {common("cancel")}
          </button>
          <button onClick={onConfirm} disabled={confirming}
            className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
            style={{ background: "var(--primary)", color: "#1E1F18" }}>
            {confirmLabel}
          </button>
        </div>
      </div>
    </Dialog>
  );
}
