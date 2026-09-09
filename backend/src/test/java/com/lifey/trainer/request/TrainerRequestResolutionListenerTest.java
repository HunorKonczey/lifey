package com.lifey.trainer.request;

import com.lifey.mail.service.MailService;
import com.lifey.superadmin.TrainerRoleGrantedEvent;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * docs/landing_page/66-trainer-billing-web-plan.md §2 — "the super admin's
 * existing grant action also resolves the request." This listener is what
 * makes that true regardless of which endpoint published {@link TrainerRoleGrantedEvent}.
 */
@ExtendWith(MockitoExtension.class)
class TrainerRequestResolutionListenerTest {

    private static final Long USER_ID = 1L;
    private static final Long ACTOR_ID = 99L;
    private static final Instant NOW = Instant.parse("2026-08-28T09:00:00Z");

    @Mock
    TrainerRequestRepository trainerRequestRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    MailService mailService;

    private TrainerRequestResolutionListener listener() {
        return new TrainerRequestResolutionListener(trainerRequestRepository, userRepository, mailService,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private TrainerRequest pendingRequest() {
        TrainerRequest request = new TrainerRequest();
        request.setId(7L);
        User user = new User();
        user.setId(USER_ID);
        request.setUser(user);
        request.setStatus(TrainerRequestStatus.PENDING);
        return request;
    }

    @Test
    void onTrainerRoleGranted_resolvesThePendingRequest_andSendsTheApprovalEmail() {
        TrainerRequest request = pendingRequest();
        when(trainerRequestRepository.findFirstByUserIdAndStatus(USER_ID, TrainerRequestStatus.PENDING))
                .thenReturn(Optional.of(request));
        User freshlyLoadedUser = new User();
        freshlyLoadedUser.setId(USER_ID);
        freshlyLoadedUser.setEmail("trainer@example.com");
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(freshlyLoadedUser));

        listener().onTrainerRoleGranted(new TrainerRoleGrantedEvent(USER_ID, ACTOR_ID));

        assertThat(request.getStatus()).isEqualTo(TrainerRequestStatus.APPROVED);
        assertThat(request.getDecidedAt()).isEqualTo(NOW);
        assertThat(request.getDecidedBy()).isEqualTo(ACTOR_ID);
        verify(trainerRequestRepository).save(request);
        verify(mailService).sendTrainerRequestApproved(freshlyLoadedUser);
    }

    @Test
    void onTrainerRoleGranted_noPendingRequest_doesNothing() {
        when(trainerRequestRepository.findFirstByUserIdAndStatus(USER_ID, TrainerRequestStatus.PENDING))
                .thenReturn(Optional.empty());

        listener().onTrainerRoleGranted(new TrainerRoleGrantedEvent(USER_ID, ACTOR_ID));

        verify(trainerRequestRepository, never()).save(any());
        verify(mailService, never()).sendTrainerRequestApproved(any());
    }

    @Test
    void onTrainerRoleGranted_userMissingAfterResolve_skipsTheEmail_withoutThrowing() {
        TrainerRequest request = pendingRequest();
        when(trainerRequestRepository.findFirstByUserIdAndStatus(USER_ID, TrainerRequestStatus.PENDING))
                .thenReturn(Optional.of(request));
        when(userRepository.findById(USER_ID)).thenReturn(Optional.empty());

        listener().onTrainerRoleGranted(new TrainerRoleGrantedEvent(USER_ID, ACTOR_ID));

        assertThat(request.getStatus()).isEqualTo(TrainerRequestStatus.APPROVED);
        verify(mailService, never()).sendTrainerRequestApproved(any());
    }
}
