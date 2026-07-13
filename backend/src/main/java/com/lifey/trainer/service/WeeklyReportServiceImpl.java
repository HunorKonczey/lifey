package com.lifey.trainer.service;

import com.lifey.mail.WeeklyTrainerReport;
import com.lifey.mail.service.MailService;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.workout.session.WorkoutSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

/**
 * Aggregates each trainer's active clients into a {@link WeeklyTrainerReport}
 * and hands it to {@link MailService} (docs/33-weekly-trainer-report-plan.md).
 * Activity metrics use each client's own {@code utcOffsetMinutes} for day/week
 * boundaries — the same convention {@code StatisticsServiceImpl} and
 * {@code WorkoutReminderJob} follow.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WeeklyReportServiceImpl implements WeeklyReportService {

    private final TrainerClientRepository trainerClientRepository;
    private final UserRepository userRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final MealRepository mealRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final WeightEntryRepository weightEntryRepository;
    private final MailService mailService;

    @Override
    public void sendWeeklyReports(LocalDate weekStart) {
        LocalDate weekEnd = weekStart.plusDays(6);
        LocalDate weekEndExclusive = weekStart.plusDays(7);

        for (Long trainerId : trainerClientRepository.findTrainerIdsWithActiveClients()) {
            if (!isReportEnabled(trainerId)) {
                continue;
            }
            List<TrainerClient> clients = trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(
                    trainerId, TrainerClientStatus.ACTIVE);
            if (clients.isEmpty()) {
                continue;
            }

            List<WeeklyTrainerReport.ClientWeekSummary> summaries = clients.stream()
                    .map(tc -> summarize(trainerId, tc.getClient(), weekStart, weekEnd, weekEndExclusive))
                    .toList();

            userRepository.findById(trainerId).ifPresent(trainer ->
                    mailService.sendWeeklyTrainerReport(trainer, new WeeklyTrainerReport(weekStart, weekEnd, summaries)));
        }
    }

    private boolean isReportEnabled(Long trainerId) {
        return userSettingsRepository.findByUserId(trainerId)
                .map(UserSettings::isWeeklyReportEmailEnabled)
                .orElse(true);
    }

    private WeeklyTrainerReport.ClientWeekSummary summarize(
            Long trainerId, User client, LocalDate weekStart, LocalDate weekEnd, LocalDate weekEndExclusive) {
        Long clientId = client.getId();
        ZoneOffset zone = ZoneOffset.ofTotalSeconds(client.getUtcOffsetMinutes() * 60);

        int completedWorkouts = (int) workoutSessionRepository
                .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNull(
                        clientId, weekStart.atStartOfDay(zone).toInstant(), weekEndExclusive.atStartOfDay(zone).toInstant());
        int missedWorkouts = (int) workoutSessionRepository.countMissedOccurrences(
                trainerId, clientId, weekStart, weekEndExclusive);

        Integer calorieGoal = userSettingsRepository.findByUserId(clientId)
                .map(UserSettings::getDailyCalorieGoal)
                .orElse(null);

        int daysLogged = 0;
        int daysWithinGoal = 0;
        double totalCalories = 0;
        for (LocalDate day = weekStart; !day.isAfter(weekEnd); day = day.plusDays(1)) {
            Instant dayStart = day.atStartOfDay(zone).toInstant();
            Instant dayEnd = day.plusDays(1).atStartOfDay(zone).toInstant();
            double calories = mealRepository.sumCaloriesBetween(clientId, dayStart, dayEnd);
            if (calories > 0) {
                daysLogged++;
                totalCalories += calories;
                if (calorieGoal != null && calories <= calorieGoal) {
                    daysWithinGoal++;
                }
            }
        }
        Integer avgCalories = daysLogged == 0 ? null : (int) Math.round(totalCalories / daysLogged);
        Integer daysWithinGoalResult = calorieGoal == null ? null : daysWithinGoal;

        // Newest-first within the week; "current" is the first element.
        List<WeightEntry> weekEntries = weightEntryRepository
                .findByUserIdAndDeletedAtIsNullAndDateRange(clientId, weekStart, weekEnd);
        Double weightKg = null;
        Double weightChangeKg = null;
        if (!weekEntries.isEmpty()) {
            weightKg = weekEntries.getFirst().getWeight();
            Optional<WeightEntry> baseline = weightEntryRepository
                    .findFirstByUserIdAndDeletedAtIsNullAndDateLessThanOrderByDateDescRecordedAtDesc(clientId, weekStart);
            if (baseline.isPresent()) {
                weightChangeKg = round1(weightKg - baseline.get().getWeight());
            } else if (weekEntries.size() > 1) {
                weightChangeKg = round1(weightKg - weekEntries.getLast().getWeight());
            }
        }

        return new WeeklyTrainerReport.ClientWeekSummary(
                displayName(client), completedWorkouts, missedWorkouts,
                daysLogged, daysWithinGoalResult, avgCalories, weightKg, weightChangeKg);
    }

    private static double round1(double value) {
        return Math.round(value * 10) / 10.0;
    }

    private static String displayName(User user) {
        String email = user.getEmail();
        int at = email.indexOf('@');
        return at > 0 ? email.substring(0, at) : email;
    }
}
