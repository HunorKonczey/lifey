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
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WeeklyReportServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;
    private static final LocalDate WEEK_START = LocalDate.of(2026, 6, 1); // a Monday
    private static final LocalDate WEEK_END = WEEK_START.plusDays(6);

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    UserSettingsRepository userSettingsRepository;

    @Mock
    MealRepository mealRepository;

    @Mock
    WorkoutSessionRepository workoutSessionRepository;

    @Mock
    WeightEntryRepository weightEntryRepository;

    @Mock
    MailService mailService;

    @InjectMocks
    WeeklyReportServiceImpl service;

    @Test
    void noTrainersWithActiveClients_sendsNothing() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of());

        service.sendWeeklyReports(WEEK_START);

        verify(mailService, never()).sendWeeklyTrainerReport(any(), any());
    }

    @Test
    void trainerWithNoActiveClientsLeftAfterLookup_sendsNothing() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of());

        service.sendWeeklyReports(WEEK_START);

        verify(mailService, never()).sendWeeklyTrainerReport(any(), any());
    }

    @Test
    void optedOutTrainer_isSkipped() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, false);

        service.sendWeeklyReports(WEEK_START);

        verify(mailService, never()).sendWeeklyTrainerReport(any(), any());
        verify(trainerClientRepository, never()).findByTrainerIdAndStatusOrderByRespondedAtDesc(any(), any());
    }

    @Test
    void missingSettingsRow_defaultsToEnabled() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        when(userSettingsRepository.findByUserId(TRAINER_ID)).thenReturn(Optional.empty());
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID))));
        stubClientDefaults(CLIENT_ID);
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        service.sendWeeklyReports(WEEK_START);

        verify(mailService).sendWeeklyTrainerReport(any(), any());
    }

    @Test
    void zeroActivityClient_stillIncludedInReport() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID))));
        stubClientDefaults(CLIENT_ID);
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        WeeklyTrainerReport report = captureReport();

        assertThat(report.clients()).hasSize(1);
        WeeklyTrainerReport.ClientWeekSummary summary = report.clients().getFirst();
        assertThat(summary.completedWorkouts()).isZero();
        assertThat(summary.missedWorkouts()).isZero();
        assertThat(summary.daysLogged()).isZero();
        assertThat(summary.avgCalories()).isNull();
        assertThat(summary.weightKg()).isNull();
    }

    @Test
    void calorieAdherence_noGoalSet_daysWithinGoalIsNull() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID))));
        stubClientDefaults(CLIENT_ID);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());
        // Two logged days, 2000 kcal each.
        when(mealRepository.sumCaloriesBetween(eq(CLIENT_ID), any(), any()))
                .thenReturn(0.0, 2000.0, 2000.0, 0.0, 0.0, 0.0, 0.0);
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        WeeklyTrainerReport.ClientWeekSummary summary = captureReport().clients().getFirst();

        assertThat(summary.daysLogged()).isEqualTo(2);
        assertThat(summary.daysWithinGoal()).isNull();
        assertThat(summary.avgCalories()).isEqualTo(2000);
    }

    @Test
    void calorieAdherence_withGoal_overGoalDayNotCountedWithin() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID))));
        stubClientDefaults(CLIENT_ID);
        UserSettings clientSettings = new UserSettings();
        clientSettings.setDailyCalorieGoal(2000);
        when(userSettingsRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(clientSettings));
        // Day 1 within goal, day 2 over goal, rest unlogged.
        when(mealRepository.sumCaloriesBetween(eq(CLIENT_ID), any(), any()))
                .thenReturn(1800.0, 2500.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        WeeklyTrainerReport.ClientWeekSummary summary = captureReport().clients().getFirst();

        assertThat(summary.daysLogged()).isEqualTo(2);
        assertThat(summary.daysWithinGoal()).isEqualTo(1);
    }

    @Test
    void weight_noEntryInWeek_bothNull() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID))));
        stubClientDefaults(CLIENT_ID);
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        WeeklyTrainerReport.ClientWeekSummary summary = captureReport().clients().getFirst();

        assertThat(summary.weightKg()).isNull();
        assertThat(summary.weightChangeKg()).isNull();
    }

    @Test
    void weight_withBaseline_computesChange() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID))));
        stubClientDefaults(CLIENT_ID);
        when(weightEntryRepository.findByUserIdAndDeletedAtIsNullAndDateRange(CLIENT_ID, WEEK_START, WEEK_END))
                .thenReturn(List.of(weightEntry(82.0, WEEK_END)));
        when(weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullAndDateLessThanOrderByDateDescRecordedAtDesc(
                CLIENT_ID, WEEK_START)).thenReturn(Optional.of(weightEntry(82.4, WEEK_START.minusDays(1))));
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        WeeklyTrainerReport.ClientWeekSummary summary = captureReport().clients().getFirst();

        assertThat(summary.weightKg()).isEqualTo(82.0);
        assertThat(summary.weightChangeKg()).isEqualTo(-0.4);
    }

    @Test
    void weight_noBaseline_fallsBackToOldestVsNewestInWeek() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID))));
        stubClientDefaults(CLIENT_ID);
        // Newest-first: newest 81.0, oldest 82.0.
        when(weightEntryRepository.findByUserIdAndDeletedAtIsNullAndDateRange(CLIENT_ID, WEEK_START, WEEK_END))
                .thenReturn(List.of(weightEntry(81.0, WEEK_END), weightEntry(82.0, WEEK_START)));
        when(weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullAndDateLessThanOrderByDateDescRecordedAtDesc(
                CLIENT_ID, WEEK_START)).thenReturn(Optional.empty());
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        WeeklyTrainerReport.ClientWeekSummary summary = captureReport().clients().getFirst();

        assertThat(summary.weightKg()).isEqualTo(81.0);
        assertThat(summary.weightChangeKg()).isEqualTo(-1.0);
    }

    @Test
    void weight_singleEntryNoBaseline_changeOmitted() {
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID))));
        stubClientDefaults(CLIENT_ID);
        when(weightEntryRepository.findByUserIdAndDeletedAtIsNullAndDateRange(CLIENT_ID, WEEK_START, WEEK_END))
                .thenReturn(List.of(weightEntry(82.4, WEEK_END)));
        when(weightEntryRepository.findFirstByUserIdAndDeletedAtIsNullAndDateLessThanOrderByDateDescRecordedAtDesc(
                CLIENT_ID, WEEK_START)).thenReturn(Optional.empty());
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        WeeklyTrainerReport.ClientWeekSummary summary = captureReport().clients().getFirst();

        assertThat(summary.weightKg()).isEqualTo(82.4);
        assertThat(summary.weightChangeKg()).isNull();
    }

    @Test
    void twoClients_bothIncludedInSingleDigest() {
        Long otherClientId = 3L;
        when(trainerClientRepository.findTrainerIdsWithActiveClients()).thenReturn(List.of(TRAINER_ID));
        stubTrainerEnabled(TRAINER_ID, true);
        when(trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(TRAINER_ID, TrainerClientStatus.ACTIVE))
                .thenReturn(List.of(trainerClient(client(CLIENT_ID)), trainerClient(client(otherClientId))));
        stubClientDefaults(CLIENT_ID);
        stubClientDefaults(otherClientId);
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(user(TRAINER_ID)));

        WeeklyTrainerReport report = captureReport();

        assertThat(report.clients()).hasSize(2);
        assertThat(report.weekStart()).isEqualTo(WEEK_START);
        assertThat(report.weekEnd()).isEqualTo(WEEK_END);
    }

    private void stubTrainerEnabled(Long trainerId, boolean enabled) {
        UserSettings settings = new UserSettings();
        settings.setWeeklyReportEmailEnabled(enabled);
        when(userSettingsRepository.findByUserId(trainerId)).thenReturn(Optional.of(settings));
    }

    /** Every metric defaults to "nothing happened" unless a test overrides a specific stub. */
    private void stubClientDefaults(Long clientId) {
        lenient().when(workoutSessionRepository
                        .countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNull(
                                eq(clientId), any(), any()))
                .thenReturn(0L);
        lenient().when(workoutSessionRepository.countMissedOccurrences(eq(TRAINER_ID), eq(clientId), any(), any()))
                .thenReturn(0L);
        lenient().when(mealRepository.sumCaloriesBetween(eq(clientId), any(), any())).thenReturn(0.0);
        lenient().when(weightEntryRepository.findByUserIdAndDeletedAtIsNullAndDateRange(clientId, WEEK_START, WEEK_END))
                .thenReturn(List.of());
        lenient().when(userSettingsRepository.findByUserId(clientId)).thenReturn(Optional.empty());
    }

    private WeeklyTrainerReport captureReport() {
        service.sendWeeklyReports(WEEK_START);
        ArgumentCaptor<WeeklyTrainerReport> captor = ArgumentCaptor.forClass(WeeklyTrainerReport.class);
        verify(mailService).sendWeeklyTrainerReport(any(), captor.capture());
        return captor.getValue();
    }

    private static TrainerClient trainerClient(User client) {
        TrainerClient tc = new TrainerClient();
        tc.setClient(client);
        tc.setStatus(TrainerClientStatus.ACTIVE);
        return tc;
    }

    private static User client(Long id) {
        User user = user(id);
        user.setUtcOffsetMinutes(0);
        return user;
    }

    private static User user(Long id) {
        User user = new User();
        user.setId(id);
        user.setEmail("user" + id + "@example.com");
        return user;
    }

    private static WeightEntry weightEntry(double weight, LocalDate date) {
        WeightEntry entry = new WeightEntry();
        entry.setWeight(weight);
        entry.setDate(date);
        entry.setRecordedAt(Instant.now());
        return entry;
    }
}
