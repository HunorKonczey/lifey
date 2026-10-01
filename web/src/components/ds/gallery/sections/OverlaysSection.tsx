"use client";

import { useState } from "react";
import { Card } from "../../Card";
import { Modal } from "../../overlay/Modal";
import { ConfirmModal } from "../../overlay/ConfirmModal";

/** D-W0.12 — Modal (centred, focus trap, Esc, scroll lock; a Sheet under
 *  768px) and the DS-03 ConfirmModal sample. */
export function OverlaysSection() {
  const [modalOpen, setModalOpen] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [deleted, setDeleted] = useState(false);

  return (
    <Card className="flex flex-wrap gap-3">
      <button
        type="button"
        onClick={() => setModalOpen(true)}
        className="lifey-button px-4 h-10 type-button-dense rounded-[var(--r-control)]"
        style={{ background: "var(--primary)", color: "var(--on-primary)" }}
      >
        Open modal
      </button>
      <Modal open={modalOpen} onClose={() => setModalOpen(false)} width={480} aria-label="Sample modal">
        <div className="p-6 flex flex-col gap-3">
          <h2 className="type-title-l">Sample modal</h2>
          <p className="type-body" style={{ color: "var(--text-2)" }}>
            Focus is trapped in here, Esc closes it, and the page behind doesn&apos;t scroll.
          </p>
          <button
            type="button"
            onClick={() => setModalOpen(false)}
            data-autofocus="true"
            className="lifey-button self-start px-4 h-10 type-button-dense rounded-[var(--r-control)] mt-2"
            style={{ background: "var(--nested)", color: "var(--text)" }}
          >
            Close
          </button>
        </div>
      </Modal>

      <button
        type="button"
        onClick={() => setConfirmOpen(true)}
        className="lifey-button px-4 h-10 type-button-dense rounded-[var(--r-control)]"
        style={{ background: "var(--control)", color: "var(--text)" }}
      >
        Open confirm
      </button>
      <ConfirmModal
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        onConfirm={() => {
          setDeleted(true);
          setConfirmOpen(false);
        }}
        icon="delete"
        title="Delete this entry?"
        body="This can't be undone."
        cancelLabel="Cancel"
        confirmLabel="Delete"
      />
      {deleted && (
        <span className="type-body-s self-center" style={{ color: "var(--text-3)" }}>
          Confirmed.
        </span>
      )}
    </Card>
  );
}
