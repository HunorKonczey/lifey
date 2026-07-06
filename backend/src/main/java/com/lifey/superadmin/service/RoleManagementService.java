package com.lifey.superadmin.service;

import com.lifey.superadmin.dto.RoleAuditLogResponse;
import com.lifey.superadmin.dto.SuperAdminUserResponse;
import com.lifey.user.Role;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface RoleManagementService {

    Page<SuperAdminUserResponse> findUsers(String search, Pageable pageable);

    void grant(Long targetUserId, Role role);

    void revoke(Long targetUserId, Role role);

    List<RoleAuditLogResponse> findAuditLog(Long targetUserId);
}
