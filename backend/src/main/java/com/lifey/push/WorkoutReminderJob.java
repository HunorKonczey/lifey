package com.lifey.push;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import com.lifey.workout.session.WorkoutSession;
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
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Sends "you have a workout today" pushes for trainer-scheduled occurrences
 * (docs/30-push-notifications-plan.md, B3). Runs every 15 minutes because
 * "morning" is user-local, not server-local — each tick only fires for users
 * whose local clock has just passed {@link #SEND_TIME}, computed from
 * {@code User#utcOffsetMinutes} the same way {@code StatisticsServiceImpl}
 * and {@code MealServiceImpl} do for day-boundary logic.
 */
@Component
@RequiredArgsConstructor
class WorkoutReminderJob {

    private static final LocalTime SEND_TIME = LocalTime.of(8, 0);
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm");

    private final WorkoutSessionRepository workoutSessionRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;
    private final Clock clock;

    @Scheduled(cron = "0 */15 * * * *")
    @Transactional
    void sendDueReminders() {
        Instant now = clock.instant();
        // Wide UTC-date net: covers every possible utcOffsetMinutes so no user's
        // local "today" falls outside it. The actual decision is per-session below.
        LocalDate from = LocalDate.now(clock).minusDays(1);
        LocalDate to = LocalDate.now(clock).plusDays(1);

        List<WorkoutSession> candidates = workoutSessionRepository.findReminderCandidates(from, to);
        for (WorkoutSession session : candidates) {
            maybeSend(session, now);
        }
    }

    private void maybeSend(WorkoutSession session, Instant now) {
        User user = session.getUser();
        ZoneOffset offset = ZoneOffset.ofTotalSeconds(user.getUtcOffsetMinutes() * 60);
        OffsetDateTime userLocalNow = OffsetDateTime.ofInstant(now, offset);

        if (!session.getScheduledFor().isEqual(userLocalNow.toLocalDate())) {
            // Not yet the user's local day for this occurrence, or it already
            // passed without a send (job downtime) — reminders never carry over.
            return;
        }
        if (userLocalNow.toLocalTime().isBefore(SEND_TIME)) {
            return;
        }

        Optional<UserSettings> settings = userSettingsRepository.findByUserId(user.getId());
        if (!settings.map(UserSettings::isWorkoutReminderEnabled).orElse(true)) {
            // Deliberately not marking reminderSentAt: if the user re-enables the
            // toggle before their local midnight, the reminder should still fire.
            return;
        }

        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);
        session.setReminderSentAt(now);
        pushService.sendToUser(user.getId(), buildMessage(session, hungarian));
    }

    private static PushMessage buildMessage(WorkoutSession session, boolean hungarian) {
        String title = hungarian ? "Edzés van ma" : "Workout today";
        Map<String, String> data = Map.of(
                "type", "scheduled_workout",
                "sessionId", String.valueOf(session.getId()),
                "scheduledFor", session.getScheduledFor().toString()
        );
        return new PushMessage(title, describeSession(session, hungarian), data);
    }

    private static String describeSession(WorkoutSession session, boolean hungarian) {
        String name = session.getTemplateName() != null ? session.getTemplateName() : (hungarian ? "Edzés" : "Workout");
        if (session.getScheduledTime() == null) {
            return name;
        }
        String time = TIME_FORMAT.format(session.getScheduledTime());
        return hungarian ? name + " " + time + "-kor" : name + " at " + time;
    }
}
