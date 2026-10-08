import { describe, expect, it, vi } from "vitest";
import { clearQueryCache, registerQueryCacheClearer } from "./queryCacheClearer";

describe("clearQueryCache", () => {
  it("does nothing, without failing, while no query cache is registered (the marketing pages)", () => {
    expect(() => clearQueryCache()).not.toThrow();
  });

  it("calls the registered clearer, and only the latest one", () => {
    const first = vi.fn();
    const second = vi.fn();
    registerQueryCacheClearer(first);
    registerQueryCacheClearer(second);
    clearQueryCache();
    expect(first).not.toHaveBeenCalled();
    expect(second).toHaveBeenCalledOnce();
  });

  it("empties the app's real query cache once lib/queryClient is loaded", async () => {
    const { queryClient } = await import("./queryClient");
    queryClient.setQueryData(["who"], "previous account");
    clearQueryCache();
    expect(queryClient.getQueryData(["who"])).toBeUndefined();
  });
});
