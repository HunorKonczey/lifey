import { describe, expect, it } from "vitest";
import { bulkTargets, matchesRoleFilter, primaryRole, runBulk } from "./userRoles";
import type { SuperAdminUserResponse } from "./types";

const user = (id: number, ...roles: string[]) => ({ id, email: `u${id}@x.hu`, roles, createdAt: "2026-01-01T00:00:00Z", hasAvatar: false }) as SuperAdminUserResponse;

describe("primaryRole / filter", () => {
  it("ranks superadmin over trainer over client", () => {
    expect(primaryRole(["ROLE_USER", "ROLE_TRAINER", "ROLE_SUPER_ADMIN"])).toBe("ADMIN");
    expect(primaryRole(["ROLE_USER", "ROLE_TRAINER"])).toBe("TRAINER");
    expect(primaryRole(["ROLE_USER"])).toBe("USER");
  });
  it("filters by the primary role", () => {
    expect(matchesRoleFilter(user(1, "ROLE_USER", "ROLE_TRAINER"), "TRAINER")).toBe(true);
    expect(matchesRoleFilter(user(1, "ROLE_USER", "ROLE_TRAINER"), "USER")).toBe(false);
    expect(matchesRoleFilter(user(1, "ROLE_USER"), "all")).toBe(true);
  });
});

describe("bulkTargets", () => {
  const users = [user(1, "ROLE_USER"), user(2, "ROLE_USER", "ROLE_TRAINER"), user(3, "ROLE_USER")];
  it("grant skips trainers and yourself; revoke only takes trainers", () => {
    expect(bulkTargets(users, "grant", 3).map((u) => u.id)).toEqual([1]);
    expect(bulkTargets(users, "revoke", 9).map((u) => u.id)).toEqual([2]);
  });
});

describe("runBulk", () => {
  it("continues past a failure and reports it with progress", async () => {
    const seen: number[] = [];
    const result = await runBulk([1, 2, 3], async (id) => { if (id === 2) throw new Error("no"); }, (n) => seen.push(n));
    expect(result).toEqual({ done: 2, failed: [2] });
    expect(seen).toEqual([1, 2, 3]);
  });
});
