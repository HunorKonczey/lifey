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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RoleManagementServiceImplTest {

    private static final Long ACTOR_ID = 1L;
    private static final Long TARGET_ID = 2L;

    @Mock
    UserRepository userRepository;

    @Mock
    RoleAuditLogRepository roleAuditLogRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    RoleManagementServiceImpl service;

    @BeforeEach
    void setUp() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(ACTOR_ID);
    }

    @Test
    void findUsers_noSearch_usesFindAll() {
        Pageable pageable = PageRequest.of(0, 10);
        User user = user(TARGET_ID, "client@example.com", Role.ROLE_USER);
        when(userRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of(user)));

        Page<SuperAdminUserResponse> result = service.findUsers(null, pageable);

        assertThat(result.getContent()).singleElement().satisfies(r -> {
            assertThat(r.email()).isEqualTo("client@example.com");
            assertThat(r.roles()).containsExactly("ROLE_USER");
        });
        verify(userRepository, never()).findByEmailContainingIgnoreCase(any(), any());
    }

    @Test
    void findUsers_withSearch_usesSearchQueryAndTrimsIt() {
        Pageable pageable = PageRequest.of(0, 10);
        User user = user(TARGET_ID, "client@example.com", Role.ROLE_USER);
        when(userRepository.findByEmailContainingIgnoreCase("client", pageable)).thenReturn(new PageImpl<>(List.of(user)));

        Page<SuperAdminUserResponse> result = service.findUsers("  client  ", pageable);

        assertThat(result.getContent()).singleElement().satisfies(r -> assertThat(r.id()).isEqualTo(TARGET_ID));
    }

    @Test
    void grant_addsRoleAndWritesAudit() {
        User target = user(TARGET_ID, "client@example.com", Role.ROLE_USER);
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(target));

        service.grant(TARGET_ID, Role.ROLE_TRAINER);

        assertThat(target.getRoles()).contains(Role.ROLE_TRAINER);
        ArgumentCaptor<RoleAuditLog> captor = ArgumentCaptor.forClass(RoleAuditLog.class);
        verify(roleAuditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getActorId()).isEqualTo(ACTOR_ID);
        assertThat(captor.getValue().getTargetUserId()).isEqualTo(TARGET_ID);
        assertThat(captor.getValue().getRole()).isEqualTo(Role.ROLE_TRAINER);
        assertThat(captor.getValue().getAction()).isEqualTo(RoleAuditAction.GRANT);
    }

    @Test
    void grant_isIdempotentAndSkipsAuditWhenAlreadyGranted() {
        User target = user(TARGET_ID, "client@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(target));

        service.grant(TARGET_ID, Role.ROLE_TRAINER);

        verify(roleAuditLogRepository, never()).save(any());
    }

    @Test
    void grant_throwsForNonManageableRole() {
        assertThatThrownBy(() -> service.grant(TARGET_ID, Role.ROLE_ADMIN))
                .isInstanceOf(RoleNotManageableException.class);
        assertThatThrownBy(() -> service.grant(TARGET_ID, Role.ROLE_SUPER_ADMIN))
                .isInstanceOf(RoleNotManageableException.class);
        verify(userRepository, never()).findById(any());
    }

    @Test
    void grant_throwsWhenTargetingSelf() {
        assertThatThrownBy(() -> service.grant(ACTOR_ID, Role.ROLE_TRAINER))
                .isInstanceOf(CannotModifySelfException.class);
    }

    @Test
    void grant_throwsWhenTargetUserMissing() {
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.grant(TARGET_ID, Role.ROLE_TRAINER))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void revoke_removesRoleAndWritesAudit() {
        User target = user(TARGET_ID, "client@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(target));

        service.revoke(TARGET_ID, Role.ROLE_TRAINER);

        assertThat(target.getRoles()).doesNotContain(Role.ROLE_TRAINER);
        ArgumentCaptor<RoleAuditLog> captor = ArgumentCaptor.forClass(RoleAuditLog.class);
        verify(roleAuditLogRepository).save(captor.capture());
        assertThat(captor.getValue().getAction()).isEqualTo(RoleAuditAction.REVOKE);
    }

    @Test
    void revoke_throwsWhenRoleNotGranted() {
        User target = user(TARGET_ID, "client@example.com", Role.ROLE_USER);
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(target));

        assertThatThrownBy(() -> service.revoke(TARGET_ID, Role.ROLE_TRAINER))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(roleAuditLogRepository, never()).save(any());
    }

    @Test
    void revoke_throwsForNonManageableRole() {
        assertThatThrownBy(() -> service.revoke(TARGET_ID, Role.ROLE_ADMIN))
                .isInstanceOf(RoleNotManageableException.class);
    }

    @Test
    void revoke_throwsWhenTargetingSelf() {
        assertThatThrownBy(() -> service.revoke(ACTOR_ID, Role.ROLE_TRAINER))
                .isInstanceOf(CannotModifySelfException.class);
    }

    @Test
    void findAuditLog_returnsHistoryForExistingUser() {
        when(userRepository.existsById(TARGET_ID)).thenReturn(true);
        RoleAuditLog log = new RoleAuditLog();
        log.setId(5L);
        log.setActorId(ACTOR_ID);
        log.setRole(Role.ROLE_TRAINER);
        log.setAction(RoleAuditAction.GRANT);
        log.setCreatedAt(Instant.parse("2026-06-01T00:00:00Z"));
        when(roleAuditLogRepository.findByTargetUserIdOrderByCreatedAtDesc(TARGET_ID)).thenReturn(List.of(log));

        List<RoleAuditLogResponse> result = service.findAuditLog(TARGET_ID);

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.actorId()).isEqualTo(ACTOR_ID);
            assertThat(r.action()).isEqualTo(RoleAuditAction.GRANT);
        });
    }

    @Test
    void findAuditLog_throwsWhenUserMissing() {
        when(userRepository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> service.findAuditLog(99L)).isInstanceOf(ResourceNotFoundException.class);
    }

    private static User user(Long id, String email, Role... roles) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        user.setCreatedAt(Instant.parse("2026-01-01T00:00:00Z"));
        Set<Role> roleSet = new HashSet<>(List.of(roles));
        user.setRoles(roleSet);
        return user;
    }
}
