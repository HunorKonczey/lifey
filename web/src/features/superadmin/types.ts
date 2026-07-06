export interface SuperAdminUserResponse {
  id: number;
  email: string;
  roles: string[];
  createdAt: string;
  hasAvatar: boolean;
}

export type RoleAuditAction = "GRANT" | "REVOKE";

export interface RoleAuditLogResponse {
  id: number;
  actorId: number;
  role: string;
  action: RoleAuditAction;
  createdAt: string;
}
