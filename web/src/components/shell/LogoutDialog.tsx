"use client";

import { useTranslations } from "next-intl";
import { ConfirmModal } from "@/components/ds/overlay/ConfirmModal";

export interface LogoutDialogProps {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
}

/**
 * D-W0.20's honest logout: no local outbox on web, so leaving is never a
 * data-loss warning — a primary confirm (not `danger`) and a `--primary`
 * icon tint, unlike the destructive default `ConfirmModal` reaches for.
 * Shared by the account menu (W0.20) and Settings (W6.12).
 */
export function LogoutDialog({ open, onClose, onConfirm }: LogoutDialogProps) {
  const common = useTranslations("common");

  return (
    <ConfirmModal
      open={open}
      onClose={onClose}
      onConfirm={onConfirm}
      title={common("signOutConfirmTitle")}
      body={common("signOutConfirmBody")}
      icon="logout"
      tint="var(--primary)"
      cancelLabel={common("cancel")}
      confirmLabel={common("signOut")}
      destructive={false}
    />
  );
}
