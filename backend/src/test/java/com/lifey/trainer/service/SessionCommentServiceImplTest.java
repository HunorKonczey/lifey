package com.lifey.trainer.service;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SessionCommentServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final Long SESSION_ID = 3L;

    @Mock
    TrainerAccessService trainerAccessService;

    @Mock
    WorkoutSessionRepository workoutSessionRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    PushService pushService;

    @InjectMocks
    SessionCommentServiceImpl sessionCommentService;

    private WorkoutSession session;

    @BeforeEach
    void setUp() {
        User client = new User();
        client.setId(CLIENT_ID);
        session = new WorkoutSession();
        session.setId(SESSION_ID);
        session.setUser(client);
    }

    @Test
    void upsertComment_setsCommentTimestampAndAuthor() {
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));

        WorkoutSessionResponse result = sessionCommentService.upsertComment(
                TRAINER_ID, CLIENT_ID, SESSION_ID, "Nice pace, add weight next time");

        verify(trainerAccessService).requireActiveClient(TRAINER_ID, CLIENT_ID);
        assertThat(session.getTrainerComment()).isEqualTo("Nice pace, add weight next time");
        assertThat(session.getTrainerCommentAt()).isNotNull();
        assertThat(session.getTrainerCommentBy()).isEqualTo(TRAINER_ID);
        assertThat(result.trainerComment()).isEqualTo("Nice pace, add weight next time");
    }

    @Test
    void upsertComment_editingOverwritesThePreviousComment() {
        session.setTrainerComment("old comment");
        session.setTrainerCommentBy(99L);
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));

        sessionCommentService.upsertComment(TRAINER_ID, CLIENT_ID, SESSION_ID, "new comment");

        assertThat(session.getTrainerComment()).isEqualTo("new comment");
        assertThat(session.getTrainerCommentBy()).isEqualTo(TRAINER_ID);
    }

    @Test
    void upsertComment_sessionNotFoundThrows404() {
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> sessionCommentService.upsertComment(TRAINER_ID, CLIENT_ID, SESSION_ID, "hi"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void deleteComment_clearsCommentTimestampAndAuthor() {
        session.setTrainerComment("old comment");
        session.setTrainerCommentBy(TRAINER_ID);
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));

        WorkoutSessionResponse result = sessionCommentService.deleteComment(TRAINER_ID, CLIENT_ID, SESSION_ID);

        assertThat(session.getTrainerComment()).isNull();
        assertThat(session.getTrainerCommentAt()).isNull();
        assertThat(session.getTrainerCommentBy()).isNull();
        assertThat(result.trainerComment()).isNull();
    }

    @Test
    void deleteComment_sessionNotFoundThrows404() {
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> sessionCommentService.deleteComment(TRAINER_ID, CLIENT_ID, SESSION_ID))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void upsertComment_newCommentSendsPushWithSessionNamePrefix() {
        session.setTemplateName("Push day");
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        sessionCommentService.upsertComment(TRAINER_ID, CLIENT_ID, SESSION_ID, "Nice pace, add weight next time");

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(org.mockito.ArgumentMatchers.eq(CLIENT_ID), captor.capture());
        PushMessage message = captor.getValue();
        assertThat(message.title()).isEqualTo("New comment from your trainer");
        assertThat(message.body()).isEqualTo("Push day: Nice pace, add weight next time");
        assertThat(message.data()).containsEntry("type", "trainer_comment");
        assertThat(message.data()).containsEntry("sessionId", SESSION_ID.toString());
    }

    @Test
    void upsertComment_editDoesNotSendAnotherPush() {
        session.setTrainerComment("already commented");
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));

        sessionCommentService.upsertComment(TRAINER_ID, CLIENT_ID, SESSION_ID, "typo fix");

        verify(pushService, never()).sendToUser(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void upsertComment_skipsPushWhenTrainerCommentPushDisabled() {
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));
        UserSettings settings = new UserSettings();
        settings.setTrainerCommentPushEnabled(false);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settings));

        sessionCommentService.upsertComment(TRAINER_ID, CLIENT_ID, SESSION_ID, "hi");

        verify(pushService, never()).sendToUser(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
    }

    @Test
    void upsertComment_sendsPushWithHungarianCopyWhenClientPrefersHungarian() {
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));
        UserSettings settings = new UserSettings();
        settings.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(settings));

        sessionCommentService.upsertComment(TRAINER_ID, CLIENT_ID, SESSION_ID, "hi");

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(org.mockito.ArgumentMatchers.eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Új megjegyzés az edződtől");
    }

    @Test
    void upsertComment_truncatesLongCommentInPushBody() {
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());
        String longComment = "a".repeat(200);

        sessionCommentService.upsertComment(TRAINER_ID, CLIENT_ID, SESSION_ID, longComment);

        ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(org.mockito.ArgumentMatchers.eq(CLIENT_ID), captor.capture());
        assertThat(captor.getValue().body()).hasSize(120);
        assertThat(captor.getValue().body()).endsWith("…");
    }

    @Test
    void deleteComment_neverSendsPush() {
        session.setTrainerComment("old comment");
        when(workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(SESSION_ID, CLIENT_ID))
                .thenReturn(Optional.of(session));

        sessionCommentService.deleteComment(TRAINER_ID, CLIENT_ID, SESSION_ID);

        verify(pushService, never()).sendToUser(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
    }
}
