export interface SuperAdminUserResponse {
  id: number;
  email: string;
  roles: string[];
  createdAt: string;
  hasAvatar: boolean;
  /** Null when the user never filled in their profile. */
  firstName: string | null;
  lastName: string | null;
  /** The display name of a client's active trainer; null for everyone else (or a client without one). */
  trainerName: string | null;
  /** A trainer's number of active clients; null for non-trainers. */
  clientCount: number | null;
}

export type RoleAuditAction = "GRANT" | "REVOKE";

export interface RoleAuditLogResponse {
  id: number;
  actorId: number;
  /** Null when the actor has no profile name. */
  actorName: string | null;
  actorEmail: string | null;
  role: string;
  action: RoleAuditAction;
  createdAt: string;
}

/** One entry of the global role-change feed. */
export interface GlobalRoleAuditResponse {
  id: number;
  actorId: number;
  actorName: string | null;
  actorEmail: string | null;
  targetUserId: number;
  targetName: string | null;
  targetEmail: string | null;
  role: string;
  action: RoleAuditAction;
  createdAt: string;
}

export interface SuperAdminStatsResponse {
  totalUsers: number;
  /** Accounts that signed in or refreshed a session in the last 30 days. */
  activeAccounts30d: number;
  trainers: number;
  clientsWithTrainer: number;
  pendingRequests: number;
  /** When the longest-waiting request was filed; null when none is waiting. */
  oldestPendingRequestAt: string | null;
}
