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
