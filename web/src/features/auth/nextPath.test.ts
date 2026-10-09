import { describe, expect, it } from "vitest";
import { safeNextPath, withNext } from "./nextPath";

describe("safeNextPath", () => {
  it("keeps a relative path of this site", () => {
    expect(safeNextPath("/join/abc123")).toBe("/join/abc123");
    expect(safeNextPath("/admin/pending")).toBe("/admin/pending");
  });

  it("refuses anything that could leave the site or is not a path", () => {
    expect(safeNextPath(null)).toBeNull();
    expect(safeNextPath("")).toBeNull();
    expect(safeNextPath("https://evil.example")).toBeNull();
    expect(safeNextPath("//evil.example")).toBeNull();
    expect(safeNextPath("/\\evil.example")).toBeNull();
    expect(safeNextPath("join/abc")).toBeNull();
  });
});

describe("withNext", () => {
  it("appends an encoded, safe destination to a path", () => {
    expect(withNext("/login", "/join/abc")).toBe("/login?next=%2Fjoin%2Fabc");
  });

  it("leaves the path alone when there is no safe destination", () => {
    expect(withNext("/login", null)).toBe("/login");
    expect(withNext("/login", "https://evil.example")).toBe("/login");
  });
});
