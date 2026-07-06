import { api, type Page } from "@/lib/api/client";
import type { RoleAuditLogResponse, SuperAdminUserResponse } from "./types";

export const superAdminApi = {
  users: (params: { page: number; size?: number; search?: string }) => {
    const query = new URLSearchParams({
      page: String(params.page),
      size: String(params.size ?? 50),
      ...(params.search ? { search: params.search } : {}),
    });
    return api.get<Page<SuperAdminUserResponse>>(`/superadmin/users?${query}`);
  },
  grantTrainer: (userId: number) =>
    api.post<void>(`/superadmin/users/${userId}/roles`, { role: "ROLE_TRAINER" }),
  revokeTrainer: (userId: number) =>
    api.delete(`/superadmin/users/${userId}/roles/ROLE_TRAINER`),
  roleAudit: (userId: number) =>
    api.get<RoleAuditLogResponse[]>(`/superadmin/users/${userId}/role-audit`),
};
