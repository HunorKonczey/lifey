import { describe, it, expect } from "vitest";
import { MAX_COMMENT_LENGTH, trimCommentForSave, isCommentSaveable } from "./sessionComment";

describe("trimCommentForSave", () => {
  it("trims surrounding whitespace", () => {
    expect(trimCommentForSave("  Nice pace  ")).toBe("Nice pace");
  });

  it("returns null for blank input", () => {
    expect(trimCommentForSave("   ")).toBeNull();
    expect(trimCommentForSave("")).toBeNull();
  });
});

describe("isCommentSaveable", () => {
  it("rejects blank input", () => {
    expect(isCommentSaveable("   ")).toBe(false);
  });

  it("accepts input at the cap", () => {
    expect(isCommentSaveable("a".repeat(MAX_COMMENT_LENGTH))).toBe(true);
  });

  it("rejects input over the cap", () => {
    expect(isCommentSaveable("a".repeat(MAX_COMMENT_LENGTH + 1))).toBe(false);
  });
});
