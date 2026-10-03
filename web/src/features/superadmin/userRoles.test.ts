import { describe, expect, it } from "vitest";
import { auditTransition, bulkTargets, personLabel, roleFilterParam, primaryRole, runBulk } from "./userRoles";
import type { SuperAdminUserResponse } from "./types";

const user = (id: number, ...roles: string[]) => ({ id, email: `u${id}@x.hu`, roles, createdAt: "2026-01-01T00:00:00Z", hasAvatar: false }) as SuperAdminUserResponse;

describe("primaryRole / filter", () => {
  it("ranks superadmin over trainer over client", () => {
    expect(primaryRole(["ROLE_USER", "ROLE_TRAINER", "ROLE_SUPER_ADMIN"])).toBe("ADMIN");
    expect(primaryRole(["ROLE_USER", "ROLE_TRAINER"])).toBe("TRAINER");
    expect(primaryRole(["ROLE_USER"])).toBe("USER");
  });
  it("sends the role kind the server filters by, and nothing for \"all\"", () => {
    expect(roleFilterParam("all")).toBeUndefined();
    expect(roleFilterParam("TRAINER")).toBe("TRAINER");
    expect(roleFilterParam("USER")).toBe("USER");
    expect(roleFilterParam("ADMIN")).toBe("ADMIN");
  });
  it("uses the same kinds the server does: a user who is both admin and trainer is one ADMIN row", () => {
    expect(primaryRole(["ROLE_USER", "ROLE_TRAINER", "ROLE_ADMIN"])).toBe("ADMIN");
    expect(primaryRole(["ROLE_USER", "ROLE_TRAINER"])).toBe("TRAINER");
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

describe("auditTransition / personLabel", () => {
  it("maps a trainer grant and revoke to the role change and a neutral shield for anything else", () => {
    expect(auditTransition({ role: "ROLE_TRAINER", action: "GRANT" })).toMatchObject({ icon: "how_to_reg", from: "USER", to: "TRAINER" });
    expect(auditTransition({ role: "ROLE_TRAINER", action: "REVOKE" })).toMatchObject({ icon: "person_remove", from: "TRAINER", to: "USER" });
    expect(auditTransition({ role: "ROLE_ADMIN", action: "GRANT" })).toMatchObject({ icon: "shield_person", from: null });
  });
  it("labels a person by name, else e-mail, else nothing", () => {
    expect(personLabel("Szabó Bence", "b@x.hu")).toBe("Szabó Bence");
    expect(personLabel(null, "b@x.hu")).toBe("b@x.hu");
    expect(personLabel(" ", null)).toBeNull();
  });
});
