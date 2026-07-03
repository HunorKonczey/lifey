package com.lifey.superadmin.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.superadmin.RoleAuditAction;
import com.lifey.superadmin.RoleAuditLog;
import com.lifey.superadmin.RoleAuditLogRepository;
import com.lifey.superadmin.dto.RoleAuditLogResponse;
import com.lifey.superadmin.dto.SuperAdminUserResponse;
import com.lifey.superadmin.exception.CannotModifySelfException;
import com.lifey.superadmin.exception.RoleNotManageableException;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Role grant/revoke rules (docs/personal_trainer/03-backend-terv.md,
 * "RoleManagementService szabályai"). {@code ROLE_SUPER_ADMIN} itself is
 * bootstrapped once by hand via direct SQL (see V43__role_audit_log.sql) and
 * is deliberately unreachable from here, along with {@code ROLE_ADMIN} — this
 * whitelist is what actually enforces "API-ból kizárólag ROLE_TRAINER
 * kezelhető", not just documentation.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class RoleManagementServiceImpl implements RoleManagementService {

    private static final Set<Role> MANAGEABLE_ROLES = EnumSet.of(Role.ROLE_TRAINER);

    private final UserRepository userRepository;
    private final RoleAuditLogRepository roleAuditLogRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public Page<SuperAdminUserResponse> findUsers(String search, Pageable pageable) {
        Page<User> page = (search == null || search.isBlank())
                ? userRepository.findAll(pageable)
                : userRepository.findByEmailContainingIgnoreCase(search.trim(), pageable);
        return page.map(RoleManagementServiceImpl::toUserResponse);
    }

    @Override
    public void grant(Long targetUserId, Role role) {
        requireManageable(role);
        Long actorId = requireNotSelf(targetUserId);
        User target = getOrThrow(targetUserId);

        if (target.getRoles().contains(role)) {
            return; // already granted — idempotent, no-op, no audit noise
        }
        target.getRoles().add(role);
        writeAudit(actorId, targetUserId, role, RoleAuditAction.GRANT);
    }

    @Override
    public void revoke(Long targetUserId, Role role) {
        requireManageable(role);
        Long actorId = requireNotSelf(targetUserId);
        User target = getOrThrow(targetUserId);

        if (!target.getRoles().contains(role)) {
            throw new ResourceNotFoundException("User " + targetUserId + " does not have role " + role);
        }
        target.getRoles().remove(role);
        writeAudit(actorId, targetUserId, role, RoleAuditAction.REVOKE);
    }

    @Override
    @Transactional(readOnly = true)
    public List<RoleAuditLogResponse> findAuditLog(Long targetUserId) {
        if (!userRepository.existsById(targetUserId)) {
            throw new ResourceNotFoundException("User not found: " + targetUserId);
        }
        return roleAuditLogRepository.findByTargetUserIdOrderByCreatedAtDesc(targetUserId).stream()
                .map(log -> new RoleAuditLogResponse(log.getId(), log.getActorId(), log.getRole(), log.getAction(), log.getCreatedAt()))
                .toList();
    }

    private void requireManageable(Role role) {
        if (!MANAGEABLE_ROLES.contains(role)) {
            throw new RoleNotManageableException(role + " cannot be managed through the API");
        }
    }

    private Long requireNotSelf(Long targetUserId) {
        Long actorId = currentUserProvider.getUserId();
        if (actorId.equals(targetUserId)) {
            throw new CannotModifySelfException("A super admin cannot change their own roles");
        }
        return actorId;
    }

    private User getOrThrow(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));
    }

    private void writeAudit(Long actorId, Long targetUserId, Role role, RoleAuditAction action) {
        RoleAuditLog log = new RoleAuditLog();
        log.setActorId(actorId);
        log.setTargetUserId(targetUserId);
        log.setRole(role);
        log.setAction(action);
        log.setCreatedAt(Instant.now());
        roleAuditLogRepository.save(log);
    }

    private static SuperAdminUserResponse toUserResponse(User user) {
        Set<String> roleNames = user.getRoles().stream().map(Enum::name).collect(Collectors.toUnmodifiableSet());
        return new SuperAdminUserResponse(user.getId(), user.getEmail(), roleNames, user.getCreatedAt());
    }
}
