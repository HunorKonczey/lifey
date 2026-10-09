package com.lifey.trainer;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.meal.MealType;
import com.lifey.nutrition.meal.dto.MealResponse;
import com.lifey.nutrition.meal.service.MealService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.ThemePreference;
import com.lifey.settings.UnitSystem;
import com.lifey.settings.NutritionGoalsAttribution;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.settings.service.SettingsService;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.statistics.service.StatisticsService;
import com.lifey.steps.dto.DailyStepCountResponse;
import com.lifey.steps.service.DailyStepCountService;
import com.lifey.trainer.controller.TrainerClientDataController;
import com.lifey.trainer.dto.ClientNutritionGoalsRequest;
import com.lifey.trainer.dto.ClientNutritionGoalsResponse;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.trainer.dto.ClientStepGoalRequest;
import com.lifey.trainer.dto.ClientStepGoalResponse;
import com.lifey.trainer.service.ClientNutritionGoalsService;
import com.lifey.trainer.service.MealCommentService;
import com.lifey.trainer.service.ClientStepGoalService;
import com.lifey.trainer.service.SessionCommentService;
import com.lifey.trainer.service.TrainerAccessService;
import com.lifey.user.AvatarSource;
import com.lifey.user.UserAvatar;
import com.lifey.user.UserAvatarRepository;
import com.lifey.weight.dto.WeightResponse;
import com.lifey.weight.service.WeightService;
import com.lifey.workout.session.SessionKind;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import com.lifey.workout.session.service.WorkoutSessionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.time.LocalDate;
import java.time.Month;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(TrainerClientDataController.class)
class TrainerClientDataControllerTest {

    private static final Long TRAINER_ID = 1L;
    private static final Long CLIENT_ID = 2L;

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerAccessService trainerAccessService;

    @MockitoBean
    StatisticsService statisticsService;

    @MockitoBean
    DailyStepCountService dailyStepCountService;

    @MockitoBean
    WeightService weightService;

    @MockitoBean
    WorkoutSessionService workoutSessionService;

    @MockitoBean
    SessionCommentService sessionCommentService;

    @MockitoBean
    ClientNutritionGoalsService clientNutritionGoalsService;

    @MockitoBean
    MealCommentService mealCommentService;

    @MockitoBean
    ClientStepGoalService clientStepGoalService;

    @MockitoBean
    UserAvatarRepository userAvatarRepository;

    @MockitoBean
    MealService mealService;

    @MockitoBean
    SettingsService settingsService;

    @MockitoBean
    CurrentUserProvider currentUserProvider;

    @BeforeEach
    void setUp() {
        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
    }

    @Test
    void dailyStatistics_returnsStatsForTheClient() throws Exception {
        when(statisticsService.dailyForUser(CLIENT_ID)).thenReturn(
                new StatisticsResponse(2000.0, 150.0, 200.0, 60.0, 1, 80.0, 2.0, 1, 0, 0, 0.0, 0.0));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/statistics/daily", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCalories").value(2000.0));
    }

    @Test
    void dailyStatistics_passesExplicitDateThrough() throws Exception {
        when(statisticsService.dailyForUser(CLIENT_ID, LocalDate.of(2026, Month.JUNE, 1)))
                .thenReturn(new StatisticsResponse(1.0, 1.0, 1.0, 1.0, 0, null, 0.0, 0, 0, 0, 0.0, 0.0));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/statistics/daily", CLIENT_ID)
                        .param("date", "2026-06-01"))
                .andExpect(status().isOk());
    }

    @Test
    void weeklyStatistics_returnsStatsForTheClient() throws Exception {
        when(statisticsService.weeklyForUser(CLIENT_ID)).thenReturn(
                new StatisticsResponse(10000.0, 500.0, 900.0, 300.0, 3, 80.0, 10.0, 3, 0, 0, 0.0, 0.0));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/statistics/weekly", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.workoutCount").value(3));
    }

    @Test
    void monthlyStatistics_returnsStatsForTheClient() throws Exception {
        when(statisticsService.monthlyForUser(CLIENT_ID)).thenReturn(
                new StatisticsResponse(40000.0, 2000.0, 3600.0, 1200.0, 12, 80.0, 40.0, 12, 0, 0, 0.0, 0.0));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/statistics/monthly", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.workoutCount").value(12));
    }

    @Test
    void steps_returnsClientsStepHistory() throws Exception {
        when(dailyStepCountService.findAllForUser(eq(CLIENT_ID), any(), any())).thenReturn(List.of(
                new DailyStepCountResponse(1L, LocalDate.of(2026, Month.JUNE, 1), 8000, Instant.now(), null)));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/steps", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].steps").value(8000));
    }

    @Test
    void steps_passesFromAndToThrough() throws Exception {
        when(dailyStepCountService.findAllForUser(CLIENT_ID, LocalDate.of(2026, Month.JUNE, 1), LocalDate.of(2026, Month.JUNE, 30)))
                .thenReturn(List.of());

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/steps", CLIENT_ID)
                        .param("from", "2026-06-01").param("to", "2026-06-30"))
                .andExpect(status().isOk());
    }

    @Test
    void weights_returnsClientsWeightHistory() throws Exception {
        when(weightService.findAllForUser(eq(CLIENT_ID), any(), any())).thenReturn(List.of(
                new WeightResponse(1L, LocalDate.of(2026, Month.JUNE, 1), 80.5, Instant.now(), null)));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/weights", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].weight").value(80.5));
    }

    @Test
    void weights_passesFromAndToThrough() throws Exception {
        when(weightService.findAllForUser(CLIENT_ID, LocalDate.of(2026, Month.JUNE, 1), LocalDate.of(2026, Month.JUNE, 30)))
                .thenReturn(List.of());

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/weights", CLIENT_ID)
                        .param("from", "2026-06-01").param("to", "2026-06-30"))
                .andExpect(status().isOk());
    }

    @Test
    void workoutSessions_returnsClientsSessionHistory() throws Exception {
        WorkoutSessionResponse session = new WorkoutSessionResponse(1L, Instant.parse("2026-06-01T08:00:00Z"),
                Instant.parse("2026-06-01T09:00:00Z"), List.of(), List.of(),
                null, null, null, null, null, null, null, null, null, null, null, null, Instant.now(), null,
                SessionKind.STRENGTH, null, null, null, List.of(), null);
        Page<WorkoutSessionResponse> page = new PageImpl<>(List.of(session), PageRequest.of(0, 20), 1);
        when(workoutSessionService.findPageForUser(eq(CLIENT_ID), any())).thenReturn(page);

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/workout-sessions", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(1));
    }

    @Test
    void workoutSession_returnsOneOfTheClientsSessionsById() throws Exception {
        WorkoutSessionResponse session = new WorkoutSessionResponse(481L, Instant.parse("2026-04-01T08:00:00Z"),
                Instant.parse("2026-04-01T09:00:00Z"), List.of(), List.of(),
                null, null, null, null, null, null, null, null, null, null, null, null, Instant.now(), null,
                SessionKind.STRENGTH, null, null, null, List.of(), null);
        when(workoutSessionService.findByIdForUser(CLIENT_ID, 481L)).thenReturn(session);

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}", CLIENT_ID, 481L))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(481));

        verify(trainerAccessService).requireActiveClient(TRAINER_ID, CLIENT_ID);
    }

    @Test
    void workoutSession_unknownOrForeignSessionReturns404() throws Exception {
        when(workoutSessionService.findByIdForUser(CLIENT_ID, 99L))
                .thenThrow(new ResourceNotFoundException("Workout session not found: 99"));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}", CLIENT_ID, 99L))
                .andExpect(status().isNotFound());
    }

    @Test
    void workoutSession_notYourClientReturns403_andNeverReadsTheSession() throws Exception {
        doThrow(new NotYourClientException("nope")).when(trainerAccessService).requireActiveClient(TRAINER_ID, CLIENT_ID);

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}", CLIENT_ID, 481L))
                .andExpect(status().isForbidden());

        verify(workoutSessionService, never()).findByIdForUser(any(), any());
    }

    @Test
    void putSessionComment_upsertsAndReturnsUpdatedSession() throws Exception {
        Long sessionId = 5L;
        WorkoutSessionResponse updated = new WorkoutSessionResponse(sessionId, Instant.parse("2026-06-01T08:00:00Z"),
                Instant.parse("2026-06-01T09:00:00Z"), List.of(), List.of(),
                null, null, null, null, null, null, null, null, null, null,
                "Nice pace, add weight next time", Instant.parse("2026-06-18T07:00:00Z"), Instant.now(), null,
                SessionKind.STRENGTH, null, null, null, List.of(), null);
        when(sessionCommentService.upsertComment(TRAINER_ID, CLIENT_ID, sessionId, "Nice pace, add weight next time"))
                .thenReturn(updated);

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}/comment", CLIENT_ID, sessionId)
                        .contentType(APPLICATION_JSON)
                        .content("{\"comment\":\"Nice pace, add weight next time\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.trainerComment").value("Nice pace, add weight next time"));
    }

    @Test
    void putSessionComment_blankCommentReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}/comment", CLIENT_ID, 5L)
                        .contentType(APPLICATION_JSON)
                        .content("{\"comment\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void putSessionComment_tooLongCommentReturns400() throws Exception {
        String tooLong = "a".repeat(2001);

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}/comment", CLIENT_ID, 5L)
                        .contentType(APPLICATION_JSON)
                        .content("{\"comment\":\"" + tooLong + "\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void putSessionComment_sessionNotFoundReturns404() throws Exception {
        when(sessionCommentService.upsertComment(eq(TRAINER_ID), eq(CLIENT_ID), eq(99L), any()))
                .thenThrow(new ResourceNotFoundException("Workout session not found: 99"));

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}/comment", CLIENT_ID, 99L)
                        .contentType(APPLICATION_JSON)
                        .content("{\"comment\":\"hi\"}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void putSessionComment_notYourClientReturns403() throws Exception {
        when(sessionCommentService.upsertComment(eq(TRAINER_ID), eq(CLIENT_ID), eq(5L), any()))
                .thenThrow(new NotYourClientException("nope"));

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}/comment", CLIENT_ID, 5L)
                        .contentType(APPLICATION_JSON)
                        .content("{\"comment\":\"hi\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void deleteSessionComment_notYourClientReturns403() throws Exception {
        when(sessionCommentService.deleteComment(TRAINER_ID, CLIENT_ID, 5L))
                .thenThrow(new NotYourClientException("nope"));

        mockMvc.perform(delete("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}/comment", CLIENT_ID, 5L))
                .andExpect(status().isForbidden());
    }

    @Test
    void deleteSessionComment_clearsTheComment() throws Exception {
        Long sessionId = 5L;
        WorkoutSessionResponse cleared = new WorkoutSessionResponse(sessionId, Instant.parse("2026-06-01T08:00:00Z"),
                Instant.parse("2026-06-01T09:00:00Z"), List.of(), List.of(),
                null, null, null, null, null, null, null, null, null, null,
                null, null, Instant.now(), null,
                SessionKind.STRENGTH, null, null, null, List.of(), null);
        when(sessionCommentService.deleteComment(TRAINER_ID, CLIENT_ID, sessionId)).thenReturn(cleared);

        mockMvc.perform(delete("/api/v1/trainer/clients/{clientId}/workout-sessions/{sessionId}/comment", CLIENT_ID, sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.trainerComment").doesNotExist());
    }

    @Test
    void avatar_returnsClientsProfilePicture() throws Exception {
        UserAvatar avatar = new UserAvatar();
        avatar.setImage(new byte[] {1, 2, 3});
        avatar.setContentType("image/jpeg");
        avatar.setSource(AvatarSource.UPLOAD);
        avatar.setUpdatedAt(Instant.now());
        when(userAvatarRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.of(avatar));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/avatar", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(content().contentType("image/jpeg"))
                .andExpect(content().bytes(new byte[] {1, 2, 3}));
    }

    @Test
    void avatar_returns404WhenClientHasNoPicture() throws Exception {
        when(userAvatarRepository.findByUserId(CLIENT_ID)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/avatar", CLIENT_ID))
                .andExpect(status().isNotFound());
    }

    @Test
    void meals_returnsClientsLoggedMeals() throws Exception {
        MealResponse meal = new MealResponse(1L, Instant.parse("2026-06-01T08:00:00Z"),
                MealType.BREAKFAST, "Breakfast", List.of(), Instant.now(), null, null, null);
        when(mealService.findAllForUserBetween(eq(CLIENT_ID), any(), any())).thenReturn(List.of(meal));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/meals", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].mealType").value("BREAKFAST"));
    }

    @Test
    void putMealComment_writesAndReturnsTheMealWithItsComment() throws Exception {
        MealResponse commented = new MealResponse(7L, Instant.parse("2026-06-01T08:00:00Z"),
                MealType.LUNCH, null, List.of(), Instant.now(), null, "More protein here", Instant.parse("2026-06-01T10:00:00Z"));
        when(mealCommentService.upsertComment(TRAINER_ID, CLIENT_ID, 7L, "More protein here")).thenReturn(commented);

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/meals/{mealId}/comment", CLIENT_ID, 7L)
                        .contentType(APPLICATION_JSON)
                        .content("{\"comment\":\"More protein here\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.trainerComment").value("More protein here"))
                .andExpect(jsonPath("$.trainerCommentAt").exists());
    }

    @Test
    void putMealComment_blankOrOverlongCommentReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/meals/{mealId}/comment", CLIENT_ID, 7L)
                        .contentType(APPLICATION_JSON)
                        .content("{\"comment\":\"   \"}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/meals/{mealId}/comment", CLIENT_ID, 7L)
                        .contentType(APPLICATION_JSON)
                        .content("{\"comment\":\"" + "x".repeat(2001) + "\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void putMealComment_unknownMealReturns404_andNotYourClientReturns403() throws Exception {
        when(mealCommentService.upsertComment(eq(TRAINER_ID), eq(CLIENT_ID), eq(99L), any()))
                .thenThrow(new com.lifey.common.exception.ResourceNotFoundException("Meal not found: 99"));
        when(mealCommentService.upsertComment(eq(TRAINER_ID), eq(CLIENT_ID), eq(8L), any()))
                .thenThrow(new NotYourClientException("nope"));

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/meals/{mealId}/comment", CLIENT_ID, 99L)
                        .contentType(APPLICATION_JSON).content("{\"comment\":\"hi\"}"))
                .andExpect(status().isNotFound());
        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/meals/{mealId}/comment", CLIENT_ID, 8L)
                        .contentType(APPLICATION_JSON).content("{\"comment\":\"hi\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void deleteMealComment_returnsTheMealWithoutIt() throws Exception {
        when(mealCommentService.deleteComment(TRAINER_ID, CLIENT_ID, 7L)).thenReturn(new MealResponse(7L,
                Instant.parse("2026-06-01T08:00:00Z"), MealType.LUNCH, null, List.of(), Instant.now(), null, null, null));

        mockMvc.perform(delete("/api/v1/trainer/clients/{clientId}/meals/{mealId}/comment", CLIENT_ID, 7L))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.trainerComment").doesNotExist());
    }

    @Test
    void meals_passesFromAndToThrough() throws Exception {
        when(mealService.findAllForUserBetween(CLIENT_ID, LocalDate.of(2026, Month.JUNE, 1), LocalDate.of(2026, Month.JUNE, 30)))
                .thenReturn(List.of());

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/meals", CLIENT_ID)
                        .param("from", "2026-06-01").param("to", "2026-06-30"))
                .andExpect(status().isOk());
    }

    @Test
    void nutritionGoals_returnsClientsGoals() throws Exception {
        when(settingsService.forUser(CLIENT_ID)).thenReturn(new SettingsResponse(
                UnitSystem.METRIC, 2200, 150, 240, 70, 2.5, 10000, ThemePreference.SYSTEM, LanguagePreference.SYSTEM, true, true, true, true, true, null, null, true, 90));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/nutrition-goals", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dailyCalorieGoal").value(2200))
                .andExpect(jsonPath("$.dailyProteinGoal").value(150));
    }

    @Test
    void updateNutritionGoals_updatesAndReturnsGoals() throws Exception {
        when(clientNutritionGoalsService.updateGoals(TRAINER_ID, CLIENT_ID,
                new ClientNutritionGoalsRequest(2200, 150, 240, 70)))
                .thenReturn(new ClientNutritionGoalsResponse(2200, 150, 240, 70));

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/nutrition-goals", CLIENT_ID)
                        .contentType(APPLICATION_JSON)
                        .content("{\"dailyCalorieGoal\":2200,\"dailyProteinGoal\":150,\"dailyCarbsGoal\":240,\"dailyFatGoal\":70}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dailyCalorieGoal").value(2200))
                .andExpect(jsonPath("$.dailyProteinGoal").value(150));
    }

    @Test
    void updateNutritionGoals_negativeValueReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/nutrition-goals", CLIENT_ID)
                        .contentType(APPLICATION_JSON)
                        .content("{\"dailyCalorieGoal\":-100}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void updateNutritionGoals_notYourClientReturns403() throws Exception {
        when(clientNutritionGoalsService.updateGoals(eq(TRAINER_ID), eq(CLIENT_ID), any()))
                .thenThrow(new NotYourClientException("nope"));

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/nutrition-goals", CLIENT_ID)
                        .contentType(APPLICATION_JSON)
                        .content("{\"dailyCalorieGoal\":2200}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void updateStepGoal_setsAndReturnsTheGoal() throws Exception {
        when(clientStepGoalService.updateStepGoal(TRAINER_ID, CLIENT_ID, new ClientStepGoalRequest(10000)))
                .thenReturn(new ClientStepGoalResponse(10000));

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/step-goal", CLIENT_ID)
                        .contentType(APPLICATION_JSON)
                        .content("{\"dailyStepGoal\":10000}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dailyStepGoal").value(10000));
    }

    @Test
    void updateStepGoal_aMissingGoalClearsIt() throws Exception {
        when(clientStepGoalService.updateStepGoal(TRAINER_ID, CLIENT_ID, new ClientStepGoalRequest(null)))
                .thenReturn(new ClientStepGoalResponse(null));

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/step-goal", CLIENT_ID)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dailyStepGoal").doesNotExist());
    }

    @Test
    void updateStepGoal_zeroOrNegativeReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/step-goal", CLIENT_ID)
                        .contentType(APPLICATION_JSON)
                        .content("{\"dailyStepGoal\":0}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/step-goal", CLIENT_ID)
                        .contentType(APPLICATION_JSON)
                        .content("{\"dailyStepGoal\":-5}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void updateStepGoal_notYourClientReturns403() throws Exception {
        when(clientStepGoalService.updateStepGoal(eq(TRAINER_ID), eq(CLIENT_ID), any()))
                .thenThrow(new NotYourClientException("nope"));

        mockMvc.perform(put("/api/v1/trainer/clients/{clientId}/step-goal", CLIENT_ID)
                        .contentType(APPLICATION_JSON)
                        .content("{\"dailyStepGoal\":10000}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void anyEndpoint_notYourClientReturns403() throws Exception {
        doThrow(new NotYourClientException("nope")).when(trainerAccessService).requireActiveClient(TRAINER_ID, CLIENT_ID);

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/weights", CLIENT_ID))
                .andExpect(status().isForbidden());
    }

    @Test
    void nutritionGoalsSource_flagsYourOwnChange_andNeverNamesAnyone() throws Exception {
        when(settingsService.nutritionGoalsAttribution(CLIENT_ID)).thenReturn(
                NutritionGoalsAttribution.of(CLIENT_ID, Instant.parse("2026-09-12T08:00:00Z"), TRAINER_ID));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/nutrition-goals/source", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.source").value("TRAINER"))
                .andExpect(jsonPath("$.setByYou").value(true))
                .andExpect(jsonPath("$.setByName").doesNotExist());
    }

    @Test
    void nutritionGoalsSource_anotherTrainersChangeIsNotYours() throws Exception {
        when(settingsService.nutritionGoalsAttribution(CLIENT_ID)).thenReturn(
                NutritionGoalsAttribution.of(CLIENT_ID, Instant.parse("2026-09-12T08:00:00Z"), 77L));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/nutrition-goals/source", CLIENT_ID))
                .andExpect(jsonPath("$.source").value("TRAINER"))
                .andExpect(jsonPath("$.setByYou").value(false));
    }

    @Test
    void nutritionGoalsSource_theClientsOwnGoalsAndUnknownAreNeverSetByYou() throws Exception {
        when(settingsService.nutritionGoalsAttribution(CLIENT_ID)).thenReturn(
                NutritionGoalsAttribution.of(CLIENT_ID, Instant.parse("2026-09-12T08:00:00Z"), CLIENT_ID));
        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/nutrition-goals/source", CLIENT_ID))
                .andExpect(jsonPath("$.source").value("SELF"))
                .andExpect(jsonPath("$.setByYou").value(false));

        when(settingsService.nutritionGoalsAttribution(CLIENT_ID)).thenReturn(NutritionGoalsAttribution.unknown());
        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/nutrition-goals/source", CLIENT_ID))
                .andExpect(jsonPath("$.source").value("UNKNOWN"))
                .andExpect(jsonPath("$.setAt").doesNotExist());
    }
}
