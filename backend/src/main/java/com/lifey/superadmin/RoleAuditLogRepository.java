package com.lifey.superadmin;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RoleAuditLogRepository extends JpaRepository<RoleAuditLog, Long> {

    List<RoleAuditLog> findByTargetUserIdOrderByCreatedAtDesc(Long targetUserId);
}
