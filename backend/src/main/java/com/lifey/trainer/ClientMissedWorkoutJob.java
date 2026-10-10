package com.lifey.trainer;

import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.workout.session.WorkoutSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Tells a trainer that a client missed a scheduled workout (docs/85-trainer-push-plan.md): once per occurrence, at 08:00 of
 * the trainer's local day after it, folded into one push per trainer per tick. Runs every 15 minutes because "08:00" is the
 * trainer's local time, taken from {@code User#utcOffsetMinutes} like {@code WorkoutReminderJob}.
 *
 * <p>An occurrence the job first meets more than {@link #MAX_AGE_DAYS} days late (downtime, a schedule created backwards) is
 * left alone: a stale "missed" is noise. One announced - or skipped because the trainer switched the push off - is marked
 * {@code missedNotifiedAt} and never looked at again.
 */
@Component
@RequiredArgsConstructor
class ClientMissedWorkoutJob {

    static final LocalTime SEND_TIME = LocalTime.of(8, 0);
    static final int MAX_AGE_DAYS = 3;

    private final WorkoutScheduleRepository workoutScheduleRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;
    private final Clock clock;

    @Scheduled(cron = "${lifey.jobs.client-missed-workout.cron}")
    @Transactional
    void announceDueMisses() {
        Instant now = clock.instant();
        // Wide UTC-date net, like WorkoutReminderJob: every offset's "yesterday" falls inside it.
        LocalDate today = LocalDate.now(clock);
        List<MissedOccurrence> candidates =
                workoutScheduleRepository.findMissedOccurrenceCandidates(today.minusDays(MAX_AGE_DAYS + 2), today.plusDays(1));

        Map<Long, List<MissedOccurrence>> dueByTrainer = new LinkedHashMap<>();
        for (MissedOccurrence occurrence : candidates) {
            if (isDue(occurrence, now)) {
                dueByTrainer.computeIfAbsent(occurrence.trainerId(), id -> new ArrayList<>()).add(occurrence);
            }
        }
        dueByTrainer.forEach((trainerId, due) -> announce(trainerId, due, now));
    }

    static boolean isDue(MissedOccurrence occurrence, Instant now) {
        ZoneOffset offset = ZoneOffset.ofTotalSeconds(occurrence.trainerUtcOffsetMinutes() * 60);
        OffsetDateTime trainerLocalNow = OffsetDateTime.ofInstant(now, offset);
        long daysLate = ChronoUnit.DAYS.between(occurrence.scheduledFor(), trainerLocalNow.toLocalDate());
        if (daysLate < 1 || daysLate > MAX_AGE_DAYS) {
            return false;
        }
        return daysLate > 1 || !trainerLocalNow.toLocalTime().isBefore(SEND_TIME);
    }

    private void announce(Long trainerId, List<MissedOccurrence> due, Instant now) {
        workoutSessionRepository.markMissedNotified(due.stream().map(MissedOccurrence::sessionId).toList(), now);

        Optional<UserSettings> settings = userSettingsRepository.findByUserId(trainerId);
        if (!settings.map(UserSettings::isClientMissedWorkoutPushEnabled).orElse(true)) {
            // Marked above on purpose: switching the push back on must not announce yesterday's backlog.
            return;
        }
        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);
        pushService.sendToUser(trainerId, MissedWorkoutPush.build(due, hungarian));
    }
}
