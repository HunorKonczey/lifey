import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { useToast } from "./useToast";

vi.mock("@/lib/api/client", () => ({
  keepaliveDelete: vi.fn(() => Promise.resolve()),
}));

import { keepaliveDelete } from "@/lib/api/client";
import { undoableDelete } from "./useUndoableDelete";

beforeEach(() => {
  vi.useFakeTimers();
  useToast.getState().dismiss(); // clears any timer/pendingCommit left from a prior test, too
  vi.mocked(keepaliveDelete).mockClear();
  vi.mocked(keepaliveDelete).mockResolvedValue(undefined);
});

afterEach(() => {
  vi.useRealTimers();
});

describe("useToast's undo/commit lifecycle", () => {
  it("commits after the 6s window elapses", () => {
    const onCommit = vi.fn();
    useToast.getState().showUndo("Deleted", vi.fn(), onCommit);
    expect(onCommit).not.toHaveBeenCalled();
    vi.advanceTimersByTime(6000);
    expect(onCommit).toHaveBeenCalledTimes(1);
    expect(useToast.getState().toast).toBeNull();
  });

  it("sends no commit when undone", () => {
    const onUndo = vi.fn();
    const onCommit = vi.fn();
    useToast.getState().showUndo("Deleted", onUndo, onCommit);
    useToast.getState().undo();
    expect(onUndo).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(6000);
    expect(onCommit).not.toHaveBeenCalled();
  });

  it("flushes the pending commit immediately when a second delete replaces it", () => {
    const firstCommit = vi.fn();
    const secondCommit = vi.fn();
    useToast.getState().showUndo("First", vi.fn(), firstCommit);
    vi.advanceTimersByTime(2000);
    useToast.getState().showUndo("Second", vi.fn(), secondCommit);
    expect(firstCommit).toHaveBeenCalledTimes(1);
    expect(secondCommit).not.toHaveBeenCalled();
    vi.advanceTimersByTime(6000);
    expect(secondCommit).toHaveBeenCalledTimes(1);
  });

  it("a plain (non-undo) toast also flushes a pending undo commit", () => {
    const onCommit = vi.fn();
    useToast.getState().showUndo("Deleted", vi.fn(), onCommit);
    useToast.getState().show("Saved", "success");
    expect(onCommit).toHaveBeenCalledTimes(1);
  });

  it("pausing (hover/focus) freezes the window instead of resetting or ignoring it", () => {
    const onCommit = vi.fn();
    useToast.getState().showUndo("Deleted", vi.fn(), onCommit);
    vi.advanceTimersByTime(4000);
    useToast.getState().pause();
    vi.advanceTimersByTime(10_000); // long past the original 6s — must not fire while paused
    expect(onCommit).not.toHaveBeenCalled();
    useToast.getState().resume();
    vi.advanceTimersByTime(1999); // just under the ~2s that was left
    expect(onCommit).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);
    expect(onCommit).toHaveBeenCalledTimes(1);
  });

  it("an error toast is sticky and never auto-commits", () => {
    useToast.getState().show("Something broke", "error");
    expect(useToast.getState().toast?.sticky).toBe(true);
    vi.advanceTimersByTime(60_000);
    expect(useToast.getState().toast).not.toBeNull();
  });
});

describe("undoableDelete with a custom commit", () => {
  it("sends that instead of a DELETE, and only after the window", () => {
    const commit = vi.fn(() => Promise.resolve());
    undoableDelete({ message: "Item removed", commit, remove: vi.fn(), restore: vi.fn(), errorMessage: "err" });
    expect(commit).not.toHaveBeenCalled();
    vi.advanceTimersByTime(6000);
    expect(commit).toHaveBeenCalledTimes(1);
    expect(keepaliveDelete).not.toHaveBeenCalled();
  });

  it("undo means the commit is never sent", () => {
    const commit = vi.fn(() => Promise.resolve());
    const restore = vi.fn();
    undoableDelete({ message: "Item removed", commit, remove: vi.fn(), restore, errorMessage: "err" });
    useToast.getState().undo();
    vi.advanceTimersByTime(6000);
    expect(restore).toHaveBeenCalledTimes(1);
    expect(commit).not.toHaveBeenCalled();
  });

  it("a failing commit restores and shows the error toast", async () => {
    const commit = vi.fn(() => Promise.reject(new Error("network")));
    const restore = vi.fn();
    undoableDelete({ message: "Item removed", commit, remove: vi.fn(), restore, errorMessage: "Couldn't remove" });
    await vi.advanceTimersByTimeAsync(6000);
    expect(restore).toHaveBeenCalledTimes(1);
    expect(useToast.getState().toast).toMatchObject({ message: "Couldn't remove", variant: "error" });
  });
});

describe("undoableDelete", () => {
  it("removes optimistically and only calls the DELETE once the undo window elapses", () => {
    const remove = vi.fn();
    const restore = vi.fn();
    undoableDelete({ message: "Recipe deleted", path: "/recipes/1", remove, restore, errorMessage: "Couldn't delete" });
    expect(remove).toHaveBeenCalledTimes(1);
    expect(keepaliveDelete).not.toHaveBeenCalled();
    vi.advanceTimersByTime(6000);
    expect(keepaliveDelete).toHaveBeenCalledWith("/recipes/1");
  });

  it("restores instead of deleting when undone", () => {
    const remove = vi.fn();
    const restore = vi.fn();
    undoableDelete({ message: "Recipe deleted", path: "/recipes/1", remove, restore, errorMessage: "Couldn't delete" });
    useToast.getState().undo();
    expect(restore).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(6000);
    expect(keepaliveDelete).not.toHaveBeenCalled();
  });

  it("restores and shows an error toast when the deferred DELETE fails", async () => {
    vi.mocked(keepaliveDelete).mockRejectedValueOnce(new Error("network"));
    const remove = vi.fn();
    const restore = vi.fn();
    undoableDelete({ message: "Recipe deleted", path: "/recipes/1", remove, restore, errorMessage: "Couldn't delete" });
    await vi.advanceTimersByTimeAsync(6000);
    expect(restore).toHaveBeenCalledTimes(1);
    expect(useToast.getState().toast).toMatchObject({ message: "Couldn't delete", variant: "error" });
  });

  it("a second delete flushes (sends) the first one immediately instead of dropping it", () => {
    const removeA = vi.fn();
    const restoreA = vi.fn();
    const removeB = vi.fn();
    const restoreB = vi.fn();
    undoableDelete({ message: "A deleted", path: "/a", remove: removeA, restore: restoreA, errorMessage: "err" });
    undoableDelete({ message: "B deleted", path: "/b", remove: removeB, restore: restoreB, errorMessage: "err" });
    expect(keepaliveDelete).toHaveBeenCalledWith("/a");
    expect(keepaliveDelete).not.toHaveBeenCalledWith("/b");
  });
});
