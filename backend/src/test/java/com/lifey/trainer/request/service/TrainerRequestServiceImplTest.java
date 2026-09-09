package com.lifey.trainer.request.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.mail.service.MailService;
import com.lifey.superadmin.service.RoleManagementService;
import com.lifey.trainer.request.TrainerRequest;
import com.lifey.trainer.request.TrainerRequestRepository;
import com.lifey.trainer.request.TrainerRequestStatus;
import com.lifey.trainer.request.dto.SuperAdminTrainerRequestResponse;
import com.lifey.trainer.request.dto.TrainerRequestRequest;
import com.lifey.trainer.request.dto.TrainerRequestResponse;
import com.lifey.trainer.request.exception.TrainerRequestAlreadyDecidedException;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TrainerRequestServiceImplTest {

    private static final Long USER_ID = 1L;
    private static final Long ACTOR_ID = 99L;
    private static final Instant NOW = Instant.parse("2026-08-28T09:00:00Z");

    @Mock
    TrainerRequestRepository trainerRequestRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    RoleManagementService roleManagementService;

    @Mock
    MailService mailService;

    @Mock
    CurrentUserProvider currentUserProvider;

    private TrainerRequestServiceImpl service() {
        return new TrainerRequestServiceImpl(trainerRequestRepository, userRepository, roleManagementService,
                mailService, currentUserProvider, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private User user(Long id, Role... roles) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        user.setRoles(new HashSet<>(Set.of(roles)));
        return user;
    }

    // --- submit ------------------------------------------------------------------

    @Test
    void submit_savesAPendingRequest_andNotifiesTheTeamInbox() {
        User user = user(USER_ID, Role.ROLE_USER);
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user));
        when(trainerRequestRepository.existsByUserIdAndStatus(USER_ID, TrainerRequestStatus.PENDING)).thenReturn(false);

        TrainerRequestResponse response = service().submit(USER_ID,
                new TrainerRequestRequest("I have 10 clients on spreadsheets", 10, "landing-hero"));

        ArgumentCaptor<TrainerRequest> captor = ArgumentCaptor.forClass(TrainerRequest.class);
        verify(trainerRequestRepository).save(captor.capture());
        TrainerRequest saved = captor.getValue();
        assertThat(saved.getUser()).isSameAs(user);
        assertThat(saved.getStatus()).isEqualTo(TrainerRequestStatus.PENDING);
        assertThat(saved.getMotivation()).isEqualTo("I have 10 clients on spreadsheets");
        assertThat(saved.getClientCount()).isEqualTo(10);
        assertThat(saved.getSignupSource()).isEqualTo("landing-hero");
        assertThat(saved.getCreatedAt()).isEqualTo(NOW);
        assertThat(response.status()).isEqualTo(TrainerRequestStatus.PENDING);
        verify(mailService).sendTrainerRequestNotification(user, "I have 10 clients on spreadsheets", 10);
    }

    @Test
    void submit_userAlreadyATrainer_throwsDuplicate() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER, Role.ROLE_TRAINER)));

        assertThatThrownBy(() -> service().submit(USER_ID, new TrainerRequestRequest(null, null, null)))
                .isInstanceOf(DuplicateResourceException.class);
        verify(trainerRequestRepository, never()).save(any());
        verify(mailService, never()).sendTrainerRequestNotification(any(), any(), any());
    }

    @Test
    void submit_alreadyHasAnOpenRequest_throwsDuplicate() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(trainerRequestRepository.existsByUserIdAndStatus(USER_ID, TrainerRequestStatus.PENDING)).thenReturn(true);

        assertThatThrownBy(() -> service().submit(USER_ID, new TrainerRequestRequest(null, null, null)))
                .isInstanceOf(DuplicateResourceException.class);
        verify(trainerRequestRepository, never()).save(any());
    }

    @Test
    void submit_unknownUser_throwsNotFound() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service().submit(USER_ID, new TrainerRequestRequest(null, null, null)))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    // --- findMine ------------------------------------------------------------------

    @Test
    void findMine_returnsTheMostRecentRequest() {
        TrainerRequest request = new TrainerRequest();
        request.setId(5L);
        request.setStatus(TrainerRequestStatus.REJECTED);
        when(trainerRequestRepository.findFirstByUserIdOrderByCreatedAtDesc(USER_ID)).thenReturn(Optional.of(request));

        TrainerRequestResponse response = service().findMine(USER_ID);

        assertThat(response.id()).isEqualTo(5L);
        assertThat(response.status()).isEqualTo(TrainerRequestStatus.REJECTED);
    }

    @Test
    void findMine_noneEverSubmitted_throwsNotFound() {
        when(trainerRequestRepository.findFirstByUserIdOrderByCreatedAtDesc(USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service().findMine(USER_ID)).isInstanceOf(ResourceNotFoundException.class);
    }

    // --- findPending ------------------------------------------------------------------

    @Test
    void findPending_mapsToSuperAdminResponses() {
        User requester = user(USER_ID, Role.ROLE_USER);
        TrainerRequest request = new TrainerRequest();
        request.setId(7L);
        request.setUser(requester);
        request.setStatus(TrainerRequestStatus.PENDING);
        Pageable pageable = PageRequest.of(0, 10);
        when(trainerRequestRepository.findByStatus(TrainerRequestStatus.PENDING, pageable))
                .thenReturn(new PageImpl<>(List.of(request)));

        Page<SuperAdminTrainerRequestResponse> page = service().findPending(pageable);

        assertThat(page.getContent()).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(7L);
            assertThat(r.userId()).isEqualTo(USER_ID);
            assertThat(r.userEmail()).isEqualTo(requester.getEmail());
        });
    }

    // --- approve ------------------------------------------------------------------

    @Test
    void approve_grantsRoleTrainer_viaRoleManagementService() {
        User requester = user(USER_ID, Role.ROLE_USER);
        TrainerRequest request = new TrainerRequest();
        request.setId(7L);
        request.setUser(requester);
        request.setStatus(TrainerRequestStatus.PENDING);
        when(trainerRequestRepository.findById(7L)).thenReturn(Optional.of(request));

        service().approve(7L);

        verify(roleManagementService).grant(USER_ID, Role.ROLE_TRAINER);
        // Resolving the row itself is TrainerRequestResolutionListener's job (see its own test).
        verify(trainerRequestRepository, never()).save(any());
    }

    @Test
    void approve_unknownRequest_throwsNotFound() {
        when(trainerRequestRepository.findById(7L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service().approve(7L)).isInstanceOf(ResourceNotFoundException.class);
        verify(roleManagementService, never()).grant(any(), any());
    }

    @Test
    void approve_alreadyDecided_throws() {
        TrainerRequest request = new TrainerRequest();
        request.setId(7L);
        request.setStatus(TrainerRequestStatus.APPROVED);
        when(trainerRequestRepository.findById(7L)).thenReturn(Optional.of(request));

        assertThatThrownBy(() -> service().approve(7L)).isInstanceOf(TrainerRequestAlreadyDecidedException.class);
        verify(roleManagementService, never()).grant(any(), any());
    }

    // --- reject ------------------------------------------------------------------

    @Test
    void reject_marksRejected_withDeciderAndTimestamp() {
        TrainerRequest request = new TrainerRequest();
        request.setId(7L);
        request.setStatus(TrainerRequestStatus.PENDING);
        when(trainerRequestRepository.findById(7L)).thenReturn(Optional.of(request));
        when(currentUserProvider.getUserId()).thenReturn(ACTOR_ID);

        service().reject(7L);

        assertThat(request.getStatus()).isEqualTo(TrainerRequestStatus.REJECTED);
        assertThat(request.getDecidedAt()).isEqualTo(NOW);
        assertThat(request.getDecidedBy()).isEqualTo(ACTOR_ID);
        verify(trainerRequestRepository).save(request);
        verify(roleManagementService, never()).grant(any(), any());
    }

    @Test
    void reject_alreadyDecided_throws() {
        TrainerRequest request = new TrainerRequest();
        request.setId(7L);
        request.setStatus(TrainerRequestStatus.REJECTED);
        when(trainerRequestRepository.findById(7L)).thenReturn(Optional.of(request));

        assertThatThrownBy(() -> service().reject(7L)).isInstanceOf(TrainerRequestAlreadyDecidedException.class);
    }
}
