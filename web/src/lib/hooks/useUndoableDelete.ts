import { keepaliveDelete } from "@/lib/api/client";
import { useToast } from "./useToast";

export interface UndoableDeleteOptions {
  /** The undo toast's own copy, already translated by the caller. */
  message: string;
  /** The DELETE endpoint — only sent once the undo window elapses (D-W0.16). */
  path?: string;
  /** What to send instead of `DELETE path` — for a removal that is really an edit (dropping one
   *  item from a meal is a PUT of the rest). Runs only once the undo window elapses, like the DELETE. */
  commit?: () => Promise<unknown>;
  /** Removes the item from the caller's own cache/state, optimistically. */
  remove: () => void;
  /** Puts the item back — on Undo, or if the deferred DELETE fails. */
  restore: () => void;
  /** Shown as an error toast if the deferred DELETE fails. */
  errorMessage: string;
}

/**
 * The actual D-W0.16 orchestration, kept as a plain function (not a hook)
 * so it can be unit-tested directly with fake timers — see
 * `useUndoableDelete.test.ts`. `useUndoableDelete` below is the hook call
 * sites use; it holds no state of its own; the undo window itself lives in
 * the `useToast` store (one 6 s timer drives both the toast's own bar and
 * this delete's grace period).
 */
export function undoableDelete({ message, path, commit, remove, restore, errorMessage }: UndoableDeleteOptions) {
  remove();
  useToast.getState().showUndo(message, restore, () => {
    (commit ? commit() : keepaliveDelete(path ?? "")).catch(() => {
      restore();
      useToast.getState().show(errorMessage, "error");
    });
  });
}

export function useUndoableDelete() {
  return undoableDelete;
}
