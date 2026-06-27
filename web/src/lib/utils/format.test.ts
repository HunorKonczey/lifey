import { describe, it, expect } from "vitest";
import { humanizeEnum } from "./format";

describe("humanizeEnum", () => {
  it("capitalizes single words", () => {
    expect(humanizeEnum("CHEST")).toBe("Chest");
  });
  it("replaces underscores and lowercases the rest", () => {
    expect(humanizeEnum("FULL_BODY")).toBe("Full body");
    expect(humanizeEnum("SMITH_MACHINE")).toBe("Smith machine");
  });
  it("returns em-dash for null/undefined", () => {
    expect(humanizeEnum(null)).toBe("—");
    expect(humanizeEnum(undefined)).toBe("—");
  });
});
