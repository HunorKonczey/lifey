import type { SuperAdminUserResponse } from "./types";

export type UserRoleKind = "USER" | "TRAINER" | "ADMIN";
export type RoleFilter = "all" | UserRoleKind;
export type BulkRoleAction = "grant" | "revoke";

/** The one role a row shows: superadmin over trainer over plain client. */
export function primaryRole(roles: readonly string[]): UserRoleKind {
  if (roles.includes("ROLE_SUPER_ADMIN") || roles.includes("ROLE_ADMIN")) return "ADMIN";
  if (roles.includes("ROLE_TRAINER")) return "TRAINER";
  return "USER";
}

export function matchesRoleFilter(user: Pick<SuperAdminUserResponse, "roles">, filter: RoleFilter): boolean {
  return filter === "all" || primaryRole(user.roles) === filter;
}

/**
 * Who a bulk grant / revoke of the trainer role actually touches: never the signed-in superadmin, never a user who
 * already is (grant) or is not (revoke) a trainer — the endpoints would reject those.
 */
export function bulkTargets(users: readonly SuperAdminUserResponse[], action: BulkRoleAction, selfId: number | null | undefined): SuperAdminUserResponse[] {
  return users.filter((u) => {
    if (u.id === selfId) return false;
    const isTrainer = u.roles.includes("ROLE_TRAINER");
    return action === "grant" ? !isTrainer : isTrainer;
  });
}

export interface BulkResult {
  done: number;
  failed: number[];
}

/** Runs `run` for every id one after another (the endpoints are one user each), reporting progress; a failure is recorded and the rest continue. */
export async function runBulk(ids: readonly number[], run: (id: number) => Promise<unknown>, onProgress?: (completed: number) => void): Promise<BulkResult> {
  const result: BulkResult = { done: 0, failed: [] };
  for (const id of ids) {
    try {
      await run(id);
      result.done += 1;
    } catch {
      result.failed.push(id);
    }
    onProgress?.(result.done + result.failed.length);
  }
  return result;
}

/** "Szabó Bence" or, without a profile name, the e-mail; null when neither is known (a deleted account). */
export function personLabel(name: string | null | undefined, email: string | null | undefined): string | null {
  return name?.trim() || email || null;
}

export interface AuditEntryLike {
  role: string;
  action: "GRANT" | "REVOKE";
}

export type AuditTransition = { icon: "how_to_reg" | "person_remove" | "shield_person"; tone: "grant" | "revoke" | "neutral"; from: UserRoleKind | null; to: UserRoleKind | null };

/**
 * What a role-audit entry did, for the timeline: a trainer grant is Kliens → Edző (a primary check icon), a revoke
 * Edző → Kliens (a heart person-remove); any other role is a neutral shield with no arrow.
 */
export function auditTransition(entry: AuditEntryLike): AuditTransition {
  if (entry.role !== "ROLE_TRAINER") return { icon: "shield_person", tone: "neutral", from: null, to: null };
  return entry.action === "GRANT"
    ? { icon: "how_to_reg", tone: "grant", from: "USER", to: "TRAINER" }
    : { icon: "person_remove", tone: "revoke", from: "TRAINER", to: "USER" };
}
