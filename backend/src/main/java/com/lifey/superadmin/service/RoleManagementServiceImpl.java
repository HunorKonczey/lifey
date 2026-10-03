package com.lifey.superadmin.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.superadmin.RoleAuditAction;
import com.lifey.superadmin.RoleAuditLog;
import com.lifey.superadmin.RoleAuditLogRepository;
import com.lifey.superadmin.TrainerRoleGrantedEvent;
import com.lifey.superadmin.UserRoleKind;
import com.lifey.superadmin.dto.GlobalRoleAuditResponse;
import com.lifey.superadmin.dto.RoleAuditLogResponse;
import com.lifey.superadmin.dto.SuperAdminUserResponse;
import com.lifey.superadmin.exception.CannotModifySelfException;
import com.lifey.superadmin.exception.RoleNotManageableException;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserAvatar;
import com.lifey.user.UserAvatarRepository;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
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
    private final UserAvatarRepository userAvatarRepository;
    private final TrainerClientRepository trainerClientRepository;
    private final CurrentUserProvider currentUserProvider;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional(readOnly = true)
    public Page<SuperAdminUserResponse> findUsers(String search, UserRoleKind role, Pageable pageable) {
        boolean searching = search != null && !search.isBlank();
        Page<User> page;
        if (role != null) {
            // The kind is filtered in SQL (not on the loaded page), so the filter stays correct past the page size.
            page = userRepository.findByRoleKind(searching ? search.trim() : "", role.name(), pageable);
        } else {
            page = searching
                    ? userRepository.findByEmailContainingIgnoreCase(search.trim(), pageable)
                    : userRepository.findAll(pageable);
        }
        Set<Long> userIds = page.getContent().stream().map(User::getId).collect(Collectors.toSet());
        Set<Long> withAvatar = userAvatarRepository.findUserIdsWithAvatar(userIds);

        // Two read-only lookups for the whole page (not one per row): the trainer of each client, the client count of each trainer.
        Map<Long, String> trainerNameByClient = new HashMap<>();
        if (!userIds.isEmpty()) {
            for (TrainerClient link : trainerClientRepository.findWithTrainerByClientIds(userIds, TrainerClientStatus.ACTIVE)) {
                trainerNameByClient.put(link.getClient().getId(), displayName(link.getTrainer()));
            }
        }
        Set<Long> trainerIds = page.getContent().stream()
                .filter(user -> user.getRoles().contains(Role.ROLE_TRAINER))
                .map(User::getId)
                .collect(Collectors.toSet());
        Map<Long, Integer> clientCountByTrainer = new HashMap<>();
        if (!trainerIds.isEmpty()) {
            for (TrainerClientRepository.TrainerClientCount count : trainerClientRepository.countByTrainerIds(trainerIds, TrainerClientStatus.ACTIVE)) {
                clientCountByTrainer.put(count.getTrainerId(), count.getClientCount().intValue());
            }
        }
        return page.map(user -> toUserResponse(user, withAvatar.contains(user.getId()),
                trainerNameByClient.get(user.getId()),
                user.getRoles().contains(Role.ROLE_TRAINER) ? clientCountByTrainer.getOrDefault(user.getId(), 0) : null));
    }

    @Override
    @Transactional(readOnly = true)
    public UserAvatar findAvatar(Long targetUserId) {
        return userAvatarRepository.findByUserId(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("No profile picture set"));
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
        // Trial starts at grant, not registration (64 §4.1) — guarded on the
        // role itself, not just MANAGEABLE_ROLES, so growing that whitelist
        // later can't accidentally start a trial for an unrelated role.
        if (role == Role.ROLE_TRAINER) {
            eventPublisher.publishEvent(new TrainerRoleGrantedEvent(targetUserId, actorId));
        }
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
        List<RoleAuditLog> logs = roleAuditLogRepository.findByTargetUserIdOrderByCreatedAtDesc(targetUserId);
        Map<Long, User> actors = usersById(logs.stream().map(RoleAuditLog::getActorId).collect(Collectors.toSet()));
        return logs.stream()
                .map(log -> {
                    User actor = actors.get(log.getActorId());
                    return new RoleAuditLogResponse(log.getId(), log.getActorId(), fullName(actor), actor == null ? null : actor.getEmail(),
                            log.getRole(), log.getAction(), log.getCreatedAt());
                })
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<GlobalRoleAuditResponse> findGlobalAuditLog(Pageable pageable) {
        Page<RoleAuditLog> page = roleAuditLogRepository.findAllByOrderByCreatedAtDescIdDesc(pageable);
        Set<Long> ids = new HashSet<>();
        page.getContent().forEach(log -> {
            ids.add(log.getActorId());
            ids.add(log.getTargetUserId());
        });
        Map<Long, User> users = usersById(ids);
        return page.map(log -> {
            User actor = users.get(log.getActorId());
            User target = users.get(log.getTargetUserId());
            return new GlobalRoleAuditResponse(log.getId(), log.getActorId(), fullName(actor), actor == null ? null : actor.getEmail(),
                    log.getTargetUserId(), fullName(target), target == null ? null : target.getEmail(),
                    log.getRole(), log.getAction(), log.getCreatedAt());
        });
    }

    private Map<Long, User> usersById(Set<Long> ids) {
        Map<Long, User> result = new HashMap<>();
        if (ids.isEmpty()) {
            return result;
        }
        userRepository.findAllById(ids).forEach(user -> result.put(user.getId(), user));
        return result;
    }

    /** "First Last", or null when the user has no profile name (or does not exist any more). */
    private static String fullName(User user) {
        if (user == null) {
            return null;
        }
        String name = ((user.getFirstName() == null ? "" : user.getFirstName()) + " "
                + (user.getLastName() == null ? "" : user.getLastName())).trim();
        return name.isEmpty() ? null : name;
    }

    /** The name shown for a trainer next to a client: the full name, else the e-mail. */
    private static String displayName(User user) {
        String name = fullName(user);
        return name != null ? name : user.getEmail();
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

    private static SuperAdminUserResponse toUserResponse(User user, boolean hasAvatar, String trainerName, Integer clientCount) {
        Set<String> roleNames = user.getRoles().stream().map(Enum::name).collect(Collectors.toUnmodifiableSet());
        return new SuperAdminUserResponse(user.getId(), user.getEmail(), roleNames, user.getCreatedAt(), hasAvatar,
                user.getFirstName(), user.getLastName(), trainerName, clientCount, user.getLastActiveAt());
    }
}
