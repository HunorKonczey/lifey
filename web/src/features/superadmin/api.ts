import { api, ApiError, type Page } from "@/lib/api/client";
import type { UserRoleKind } from "./userRoles";
import type { GlobalRoleAuditResponse, RoleAuditLogResponse, SuperAdminStatsResponse, SuperAdminUserResponse } from "./types";

export const superAdminApi = {
  users: (params: { page: number; size?: number; search?: string; role?: UserRoleKind }) => {
    const query = new URLSearchParams({
      page: String(params.page),
      size: String(params.size ?? 50),
      ...(params.search ? { search: params.search } : {}),
      // Filtered on the server (docs/redesign-web/82 §2.1), so it stays correct past the page size.
      ...(params.role ? { role: params.role } : {}),
    });
    return api.get<Page<SuperAdminUserResponse>>(`/superadmin/users?${query}`);
  },
  grantTrainer: (userId: number) =>
    api.post<void>(`/superadmin/users/${userId}/roles`, { role: "ROLE_TRAINER" }),
  revokeTrainer: (userId: number) =>
    api.delete(`/superadmin/users/${userId}/roles/ROLE_TRAINER`),
  roleAudit: (userId: number) =>
    api.get<RoleAuditLogResponse[]>(`/superadmin/users/${userId}/role-audit`),
  stats: () => api.get<SuperAdminStatsResponse>("/superadmin/stats"),
  /** The global role-change feed, newest first. */
  globalRoleAudit: (params: { page: number; size?: number }) =>
    api.get<Page<GlobalRoleAuditResponse>>(`/superadmin/role-audit?page=${params.page}&size=${params.size ?? 30}`),
  /** Returns null (not an error) when the user has no profile picture set. */
  userAvatar: async (userId: number): Promise<Blob | null> => {
    try {
      return await api.getBlob(`/superadmin/users/${userId}/avatar`);
    } catch (e) {
      if (e instanceof ApiError && e.status === 404) return null;
      throw e;
    }
  },
};
