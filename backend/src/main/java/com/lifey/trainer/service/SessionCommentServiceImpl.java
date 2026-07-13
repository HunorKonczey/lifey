package com.lifey.trainer.service;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionMapper;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Transactional
public class SessionCommentServiceImpl implements SessionCommentService {

    private static final int PUSH_BODY_MAX_LENGTH = 120;

    private final TrainerAccessService trainerAccessService;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;

    @Override
    public WorkoutSessionResponse upsertComment(Long trainerId, Long clientId, Long sessionId, String comment) {
        WorkoutSession session = getOwnedSession(trainerId, clientId, sessionId);
        boolean isNewComment = session.getTrainerComment() == null;
        session.setTrainerComment(comment);
        session.setTrainerCommentAt(Instant.now());
        session.setTrainerCommentBy(trainerId);
        if (isNewComment) {
            sendCommentPush(session);
        }
        return WorkoutSessionMapper.toResponse(session);
    }

    @Override
    public WorkoutSessionResponse deleteComment(Long trainerId, Long clientId, Long sessionId) {
        WorkoutSession session = getOwnedSession(trainerId, clientId, sessionId);
        session.setTrainerComment(null);
        session.setTrainerCommentAt(null);
        session.setTrainerCommentBy(null);
        return WorkoutSessionMapper.toResponse(session);
    }

    private WorkoutSession getOwnedSession(Long trainerId, Long clientId, Long sessionId) {
        trainerAccessService.requireActiveClient(trainerId, clientId);
        return workoutSessionRepository.findByIdAndUserIdAndDeletedAtIsNull(sessionId, clientId)
                .orElseThrow(() -> new ResourceNotFoundException("Workout session not found: " + sessionId));
    }

    private void sendCommentPush(WorkoutSession session) {
        Long clientId = session.getUser().getId();
        Optional<UserSettings> settings = userSettingsRepository.findByUserId(clientId);
        if (!settings.map(UserSettings::isTrainerCommentPushEnabled).orElse(true)) {
            return;
        }
        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);
        pushService.sendToUser(clientId, buildMessage(session, hungarian));
    }

    private static PushMessage buildMessage(WorkoutSession session, boolean hungarian) {
        String title = hungarian ? "Új megjegyzés az edződtől" : "New comment from your trainer";
        String body = truncate(session.getTrainerComment());
        if (session.getTemplateName() != null) {
            body = session.getTemplateName() + ": " + body;
        }
        Map<String, String> data = Map.of(
                "type", "trainer_comment",
                "sessionId", String.valueOf(session.getId())
        );
        return new PushMessage(title, body, data);
    }

    private static String truncate(String comment) {
        return comment.length() > PUSH_BODY_MAX_LENGTH
                ? comment.substring(0, PUSH_BODY_MAX_LENGTH - 1) + "…"
                : comment;
    }
}
