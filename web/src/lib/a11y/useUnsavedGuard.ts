"use client";

import { useState } from "react";

/**
 * Intercepts a close request while `isDirty` (D-W0.13) — Esc, a scrim
 * click, or the header × all route through `requestClose` instead of
 * calling `onClose` directly, so a dirty `Drawer` asks via a small
 * `ConfirmModal` before discarding unsaved input.
 */
export function useUnsavedGuard(isDirty: boolean, onClose: () => void) {
  const [confirmOpen, setConfirmOpen] = useState(false);

  function requestClose() {
    if (isDirty) {
      setConfirmOpen(true);
    } else {
      onClose();
    }
  }

  function confirmDiscard() {
    setConfirmOpen(false);
    onClose();
  }

  function cancelDiscard() {
    setConfirmOpen(false);
  }

  return { confirmOpen, requestClose, confirmDiscard, cancelDiscard };
}
