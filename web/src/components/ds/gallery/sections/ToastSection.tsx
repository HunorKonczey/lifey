"use client";

import { useState } from "react";
import { Button } from "../../Button";
import { Card } from "../../Card";
import { useToast } from "@/lib/hooks/useToast";

const INITIAL_ITEMS = ["Chicken breast", "Brown rice", "Broccoli"];

/** D-W0.14 — Toast (bottom-centre, inverse surface, one at a time, a 6s bar
 *  that pauses on hover/focus, sticky errors with a close button) and the
 *  undo pattern it drives for D-W0.16: deleting below removes optimistically
 *  and only "commits" once the toast's own window elapses without Undo. */
export function ToastSection() {
  const show = useToast((s) => s.show);
  const showUndo = useToast((s) => s.showUndo);
  const [items, setItems] = useState(INITIAL_ITEMS);

  function deleteItem(item: string) {
    setItems((prev) => prev.filter((i) => i !== item));
    showUndo(
      `"${item}" deleted`,
      () => setItems((prev) => (prev.includes(item) ? prev : [...prev, item])),
      () => {}, // the gallery demo has nothing to actually send
    );
  }

  return (
    <Card className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-3">
        <Button variant="secondary" onClick={() => show("Saved")}>
          Show default
        </Button>
        <Button variant="secondary" onClick={() => show("Workout logged", "success")}>
          Show success
        </Button>
        <Button variant="secondary" onClick={() => show("Something broke", "error")}>
          Show error
        </Button>
      </div>
      <div className="flex flex-col gap-2 max-w-xs">
        {items.length === 0 && (
          <p className="type-body-s" style={{ color: "var(--text-3)" }}>
            All items deleted.
          </p>
        )}
        {items.map((item) => (
          <div
            key={item}
            className="flex items-center justify-between gap-3 px-3 h-11 rounded-[var(--r-control)]"
            style={{ background: "var(--control)" }}
          >
            <span className="type-body-s">{item}</span>
            <button
              type="button"
              onClick={() => deleteItem(item)}
              aria-label={`Delete ${item}`}
              className="lifey-button type-button-dense px-2 h-8 rounded-[var(--r-tag)]"
              style={{ color: "var(--heart)" }}
            >
              Delete
            </button>
          </div>
        ))}
      </div>
    </Card>
  );
}
