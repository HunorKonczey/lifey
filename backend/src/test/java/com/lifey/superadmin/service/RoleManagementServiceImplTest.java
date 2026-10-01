package com.lifey.superadmin.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.superadmin.RoleAuditAction;
import com.lifey.superadmin.RoleAuditLog;
import com.lifey.superadmin.RoleAuditLogRepository;
import com.lifey.superadmin.TrainerRoleGrantedEvent;
import com.lifey.superadmin.dto.RoleAuditLogResponse;
import com.lifey.superadmin.dto.SuperAdminUserResponse;
import com.lifey.superadmin.exception.CannotModifySelfException;
import com.lifey.superadmin.exception.RoleNotManageableException;
import com.lifey.superadmin.dto.GlobalRoleAuditResponse;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserAvatar;
import com.lifey.user.UserAvatarRepository;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
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
import static org.mockito.ArgumentMatchers.eq;
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
    UserAvatarRepository userAvatarRepository;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    ApplicationEventPublisher eventPublisher;

    @InjectMocks
    RoleManagementServiceImpl service;

    @BeforeEach
    void setUp() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(ACTOR_ID);
        lenient().when(userAvatarRepository.findUserIdsWithAvatar(any())).thenReturn(Set.of());
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
            assertThat(r.hasAvatar()).isFalse();
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
    void findUsers_marksUsersWithAvatar() {
        Pageable pageable = PageRequest.of(0, 10);
        User user = user(TARGET_ID, "client@example.com", Role.ROLE_USER);
        when(userRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of(user)));
        when(userAvatarRepository.findUserIdsWithAvatar(any())).thenReturn(Set.of(TARGET_ID));

        Page<SuperAdminUserResponse> result = service.findUsers(null, pageable);

        assertThat(result.getContent()).singleElement().satisfies(r -> assertThat(r.hasAvatar()).isTrue());
    }

    @Test
    void findUsers_namesTheTrainerOfAClientAndCountsTheClientsOfATrainer() {
        Pageable pageable = PageRequest.of(0, 10);
        User trainer = user(10L, "bence@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        trainer.setFirstName("Bence");
        trainer.setLastName("Edzo");
        User client = user(11L, "anna@example.com", Role.ROLE_USER);
        client.setFirstName("Anna");
        client.setLastName("Kiss");
        User loner = user(12L, "solo@example.com", Role.ROLE_USER);
        when(userRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of(trainer, client, loner)));
        TrainerClient link = new TrainerClient();
        link.setTrainer(trainer);
        link.setClient(client);
        when(trainerClientRepository.findWithTrainerByClientIds(any(), eq(TrainerClientStatus.ACTIVE))).thenReturn(List.of(link));
        TrainerClientRepository.TrainerClientCount count = mock(TrainerClientRepository.TrainerClientCount.class);
        when(count.getTrainerId()).thenReturn(10L);
        when(count.getClientCount()).thenReturn(3L);
        when(trainerClientRepository.countByTrainerIds(any(), eq(TrainerClientStatus.ACTIVE))).thenReturn(List.of(count));

        List<SuperAdminUserResponse> rows = service.findUsers(null, pageable).getContent();

        assertThat(rows.get(0).clientCount()).isEqualTo(3);
        assertThat(rows.get(0).trainerName()).isNull();
        assertThat(rows.get(1).trainerName()).isEqualTo("Bence Edzo");
        assertThat(rows.get(1).firstName()).isEqualTo("Anna");
        assertThat(rows.get(1).clientCount()).isNull();
        assertThat(rows.get(2).trainerName()).isNull();
        assertThat(rows.get(2).clientCount()).isNull();
    }

    @Test
    void findUsers_aTrainerWithoutClientsHasACountOfZero_andAnUnnamedTrainerShowsTheEmail() {
        Pageable pageable = PageRequest.of(0, 10);
        User trainer = user(10L, "bence@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        User client = user(11L, "anna@example.com", Role.ROLE_USER);
        when(userRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of(trainer, client)));
        TrainerClient link = new TrainerClient();
        link.setTrainer(trainer);
        link.setClient(client);
        when(trainerClientRepository.findWithTrainerByClientIds(any(), eq(TrainerClientStatus.ACTIVE))).thenReturn(List.of(link));
        when(trainerClientRepository.countByTrainerIds(any(), eq(TrainerClientStatus.ACTIVE))).thenReturn(List.of());

        List<SuperAdminUserResponse> rows = service.findUsers(null, pageable).getContent();

        assertThat(rows.get(0).clientCount()).isZero();
        assertThat(rows.get(1).trainerName()).isEqualTo("bence@example.com");
    }

    @Test
    void findAuditLog_namesTheActor() {
        User actor = user(ACTOR_ID, "admin@example.com", Role.ROLE_SUPER_ADMIN);
        actor.setFirstName("Admin");
        actor.setLastName("Aranka");
        when(userRepository.existsById(TARGET_ID)).thenReturn(true);
        when(userRepository.findAllById(any())).thenReturn(List.of(actor));
        RoleAuditLog entry = auditLog(5L, ACTOR_ID, TARGET_ID, RoleAuditAction.GRANT);
        when(roleAuditLogRepository.findByTargetUserIdOrderByCreatedAtDesc(TARGET_ID)).thenReturn(List.of(entry));

        List<RoleAuditLogResponse> result = service.findAuditLog(TARGET_ID);

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.actorName()).isEqualTo("Admin Aranka");
            assertThat(r.actorEmail()).isEqualTo("admin@example.com");
        });
    }

    @Test
    void findGlobalAuditLog_namesActorAndTarget_andSurvivesADeletedUser() {
        Pageable pageable = PageRequest.of(0, 30);
        User actor = user(ACTOR_ID, "admin@example.com", Role.ROLE_SUPER_ADMIN);
        actor.setFirstName("Admin");
        User target = user(TARGET_ID, "anna@example.com", Role.ROLE_USER);
        RoleAuditLog first = auditLog(6L, ACTOR_ID, TARGET_ID, RoleAuditAction.REVOKE);
        RoleAuditLog orphan = auditLog(5L, ACTOR_ID, 99L, RoleAuditAction.GRANT);
        when(roleAuditLogRepository.findAllByOrderByCreatedAtDescIdDesc(pageable)).thenReturn(new PageImpl<>(List.of(first, orphan)));
        when(userRepository.findAllById(any())).thenReturn(List.of(actor, target));

        List<GlobalRoleAuditResponse> result = service.findGlobalAuditLog(pageable).getContent();

        assertThat(result.get(0).actorName()).isEqualTo("Admin");
        assertThat(result.get(0).targetEmail()).isEqualTo("anna@example.com");
        assertThat(result.get(0).targetName()).isNull();
        assertThat(result.get(0).action()).isEqualTo(RoleAuditAction.REVOKE);
        assertThat(result.get(1).targetEmail()).isNull();
    }

    @Test
    void findAvatar_returnsAvatarWhenPresent() {
        UserAvatar avatar = new UserAvatar();
        when(userAvatarRepository.findByUserId(TARGET_ID)).thenReturn(Optional.of(avatar));

        assertThat(service.findAvatar(TARGET_ID)).isSameAs(avatar);
    }

    @Test
    void findAvatar_throwsWhenMissing() {
        when(userAvatarRepository.findByUserId(TARGET_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findAvatar(TARGET_ID)).isInstanceOf(ResourceNotFoundException.class);
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
    void grant_publishesTrainerRoleGrantedEvent_soTheTrialCanStart() {
        // 64 §4.1: the trial starts at grant, not registration.
        User target = user(TARGET_ID, "client@example.com", Role.ROLE_USER);
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(target));

        service.grant(TARGET_ID, Role.ROLE_TRAINER);

        verify(eventPublisher).publishEvent(new TrainerRoleGrantedEvent(TARGET_ID, ACTOR_ID));
    }

    @Test
    void grant_isIdempotentAndSkipsAuditWhenAlreadyGranted() {
        User target = user(TARGET_ID, "client@example.com", Role.ROLE_USER, Role.ROLE_TRAINER);
        when(userRepository.findById(TARGET_ID)).thenReturn(Optional.of(target));

        service.grant(TARGET_ID, Role.ROLE_TRAINER);

        verify(roleAuditLogRepository, never()).save(any());
        verify(eventPublisher, never()).publishEvent(any());
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

    private static RoleAuditLog auditLog(Long id, Long actorId, Long targetId, RoleAuditAction action) {
        RoleAuditLog log = new RoleAuditLog();
        log.setId(id);
        log.setActorId(actorId);
        log.setTargetUserId(targetId);
        log.setRole(Role.ROLE_TRAINER);
        log.setAction(action);
        log.setCreatedAt(Instant.parse("2026-08-12T10:00:00Z"));
        return log;
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
