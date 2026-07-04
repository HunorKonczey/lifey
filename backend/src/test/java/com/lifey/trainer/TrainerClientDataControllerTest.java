package com.lifey.trainer;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.statistics.service.StatisticsService;
import com.lifey.steps.dto.DailyStepCountResponse;
import com.lifey.steps.service.DailyStepCountService;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.trainer.service.TrainerAccessService;
import com.lifey.weight.dto.WeightResponse;
import com.lifey.weight.service.WeightService;
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
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
    CurrentUserProvider currentUserProvider;

    @BeforeEach
    void setUp() {
        when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
    }

    @Test
    void dailyStatistics_returnsStatsForTheClient() throws Exception {
        when(statisticsService.dailyForUser(eq(CLIENT_ID), any())).thenReturn(
                new StatisticsResponse(2000.0, 150.0, 200.0, 60.0, 1, 80.0, 2.0));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/statistics/daily", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCalories").value(2000.0));
    }

    @Test
    void dailyStatistics_passesExplicitDateThrough() throws Exception {
        when(statisticsService.dailyForUser(eq(CLIENT_ID), eq(LocalDate.of(2026, 6, 1))))
                .thenReturn(new StatisticsResponse(1.0, 1.0, 1.0, 1.0, 0, null, 0.0));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/statistics/daily", CLIENT_ID)
                        .param("date", "2026-06-01"))
                .andExpect(status().isOk());
    }

    @Test
    void weeklyStatistics_returnsStatsForTheClient() throws Exception {
        when(statisticsService.weeklyForUser(eq(CLIENT_ID), any())).thenReturn(
                new StatisticsResponse(10000.0, 500.0, 900.0, 300.0, 3, 80.0, 10.0));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/statistics/weekly", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.workoutCount").value(3));
    }

    @Test
    void monthlyStatistics_returnsStatsForTheClient() throws Exception {
        when(statisticsService.monthlyForUser(eq(CLIENT_ID), any())).thenReturn(
                new StatisticsResponse(40000.0, 2000.0, 3600.0, 1200.0, 12, 80.0, 40.0));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/statistics/monthly", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.workoutCount").value(12));
    }

    @Test
    void steps_returnsClientsStepHistory() throws Exception {
        when(dailyStepCountService.findAllForUser(eq(CLIENT_ID), any(), any())).thenReturn(List.of(
                new DailyStepCountResponse(1L, LocalDate.of(2026, 6, 1), 8000, Instant.now(), null)));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/steps", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].steps").value(8000));
    }

    @Test
    void steps_passesFromAndToThrough() throws Exception {
        when(dailyStepCountService.findAllForUser(CLIENT_ID, LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30)))
                .thenReturn(List.of());

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/steps", CLIENT_ID)
                        .param("from", "2026-06-01").param("to", "2026-06-30"))
                .andExpect(status().isOk());
    }

    @Test
    void weights_returnsClientsWeightHistory() throws Exception {
        when(weightService.findAllForUser(eq(CLIENT_ID), any(), any())).thenReturn(List.of(
                new WeightResponse(1L, LocalDate.of(2026, 6, 1), 80.5, Instant.now(), null)));

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/weights", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].weight").value(80.5));
    }

    @Test
    void weights_passesFromAndToThrough() throws Exception {
        when(weightService.findAllForUser(CLIENT_ID, LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 30)))
                .thenReturn(List.of());

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/weights", CLIENT_ID)
                        .param("from", "2026-06-01").param("to", "2026-06-30"))
                .andExpect(status().isOk());
    }

    @Test
    void workoutSessions_returnsClientsSessionHistory() throws Exception {
        WorkoutSessionResponse session = new WorkoutSessionResponse(1L, Instant.parse("2026-06-01T08:00:00Z"),
                Instant.parse("2026-06-01T09:00:00Z"), List.of(), List.of(),
                null, null, null, null, null, Instant.now(), null);
        Page<WorkoutSessionResponse> page = new PageImpl<>(List.of(session), PageRequest.of(0, 20), 1);
        when(workoutSessionService.findPageForUser(eq(CLIENT_ID), any())).thenReturn(page);

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/workout-sessions", CLIENT_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(1));
    }

    @Test
    void anyEndpoint_notYourClientReturns403() throws Exception {
        doThrow(new NotYourClientException("nope")).when(trainerAccessService).requireActiveClient(TRAINER_ID, CLIENT_ID);

        mockMvc.perform(get("/api/v1/trainer/clients/{clientId}/weights", CLIENT_ID))
                .andExpect(status().isForbidden());
    }
}
