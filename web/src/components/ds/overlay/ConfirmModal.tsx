import { Button } from "../Button";
import { Icon } from "../Icon";
import { Modal } from "./Modal";

export interface ConfirmModalProps {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  body: string;
  icon?: string;
  /** Tint for the icon holder — heart for a destructive confirmation (the default). */
  tint?: string;
  cancelLabel?: string;
  confirmLabel: string;
  /** Renders the confirm action in the danger variant. Default true. */
  destructive?: boolean;
  /** `data-testid` of the confirm button, for specs that have several dialogs to tell apart. */
  confirmTestId?: string;
}

/**
 * The DS-03 confirmation sample (D-W0.12): a 48px tinted icon holder, a
 * 22/800 title, body copy, "Mégse" + the action — initial focus on the
 * *safe* button (`data-autofocus`, `useFocusTrap`), never the destructive
 * one. Buttons stack instead of clipping when they don't fit side by side
 * (HU at 200% zoom).
 */
export function ConfirmModal({
  open,
  onClose,
  onConfirm,
  title,
  body,
  icon = "help",
  tint = "var(--heart)",
  cancelLabel = "Cancel",
  confirmLabel,
  destructive = true,
  confirmTestId,
}: ConfirmModalProps) {
  return (
    <Modal open={open} onClose={onClose} width={480} aria-label={title}>
      <div className="p-6 flex flex-col items-center gap-3 text-center">
        <span
          className="inline-flex items-center justify-center rounded-full shrink-0"
          style={{ width: 48, height: 48, background: `color-mix(in srgb, ${tint} var(--chip-tint), transparent)` }}
        >
          <Icon name={icon} size={24} color={tint} />
        </span>
        <h2 className="type-title-l">{title}</h2>
        <p className="type-body" style={{ color: "var(--text-2)" }}>
          {body}
        </p>
        <div className="flex flex-wrap gap-3 justify-center w-full mt-2">
          <Button variant="secondary" onClick={onClose} data-autofocus="true" className="flex-1 min-w-[140px]">
            {cancelLabel}
          </Button>
          <Button variant={destructive ? "danger" : "primary"} onClick={onConfirm} data-testid={confirmTestId} className="flex-1 min-w-[140px]">
            {confirmLabel}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
