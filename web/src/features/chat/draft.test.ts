import { describe, expect, it } from "vitest";
import { chatDraftHref, greetingName } from "./draft";
import type { ConversationResponse } from "./types";

const conv = (id: number, userId: number) => ({ id, peer: { userId } }) as unknown as ConversationResponse;

describe("chatDraftHref", () => {
  it("points at the client's conversation with the encoded draft", () => {
    expect(chatDraftHref([conv(7, 42)], 42, "Szia Dóra! 🏆")).toBe(`/admin/chat?c=7&draft=${encodeURIComponent("Szia Dóra! 🏆")}`);
  });
  it("is null with no conversation for that client", () => {
    expect(chatDraftHref([conv(7, 42)], 43, "x")).toBeNull();
    expect(chatDraftHref(undefined, 42, "x")).toBeNull();
  });
});

describe("greetingName", () => {
  it("prefers the first name and falls back to the first word", () => {
    expect(greetingName("Kata", "Nagy Kata")).toBe("Kata");
    expect(greetingName(null, "Nagy Kata")).toBe("Nagy");
    expect(greetingName("  ", "Kata")).toBe("Kata");
  });
});
