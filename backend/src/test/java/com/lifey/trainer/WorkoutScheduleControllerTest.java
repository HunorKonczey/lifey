package com.lifey.trainer;

import com.lifey.trainer.controller.WorkoutScheduleController;
import com.lifey.trainer.dto.OccurrenceStatus;
import com.lifey.trainer.dto.ScheduleResponse;
import com.lifey.trainer.dto.ScheduleSummaryResponse;
import com.lifey.trainer.dto.ScheduledSessionResponse;
import com.lifey.trainer.dto.TrainerCalendarSessionResponse;
import com.lifey.trainer.exception.CalendarRangeExceededException;
import com.lifey.trainer.exception.EmptyRecurrenceException;
import com.lifey.trainer.exception.OccurrenceNotCancellableException;
import com.lifey.trainer.exception.ScheduleHorizonExceededException;
import com.lifey.trainer.exception.ScheduleInPastException;
import com.lifey.trainer.exception.ScheduleNotFoundException;
import com.lifey.trainer.service.WorkoutScheduleService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.time.Month;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(WorkoutScheduleController.class)
class WorkoutScheduleControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    WorkoutScheduleService workoutScheduleService;

    private static final String ONCE_BODY = "{\"clientId\":2,\"templateId\":7,\"recurrence\":\"ONCE\","
            + "\"startDate\":\"2026-07-10\",\"endDate\":\"2026-07-10\"}";

    @Test
    void create_returnsCreated() throws Exception {
        when(workoutScheduleService.create(any())).thenReturn(new ScheduleResponse(
                9L, 2L, 7L, "Push day", com.lifey.trainer.Recurrence.ONCE, List.of(), null,
                LocalDate.of(2026, Month.JULY, 10), LocalDate.of(2026, Month.JULY, 10), 1));

        mockMvc.perform(post("/api/v1/trainer/schedules").contentType(MediaType.APPLICATION_JSON)
                        .content(ONCE_BODY))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9))
                .andExpect(jsonPath("$.occurrencesCreated").value(1));
    }

    @Test
    void create_missingFieldsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/trainer/schedules").contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void create_pastStartDateReturns400() throws Exception {
        when(workoutScheduleService.create(any())).thenThrow(new ScheduleInPastException("nope"));

        mockMvc.perform(post("/api/v1/trainer/schedules").contentType(MediaType.APPLICATION_JSON)
                        .content(ONCE_BODY))
                .andExpect(status().isBadRequest());
    }

    @Test
    void create_emptyWeeklyReturns400() throws Exception {
        when(workoutScheduleService.create(any())).thenThrow(new EmptyRecurrenceException("nope"));

        mockMvc.perform(post("/api/v1/trainer/schedules").contentType(MediaType.APPLICATION_JSON)
                        .content(ONCE_BODY))
                .andExpect(status().isBadRequest());
    }

    @Test
    void create_horizonExceededReturns422() throws Exception {
        when(workoutScheduleService.create(any())).thenThrow(new ScheduleHorizonExceededException("nope"));

        mockMvc.perform(post("/api/v1/trainer/schedules").contentType(MediaType.APPLICATION_JSON)
                        .content(ONCE_BODY))
                .andExpect(status().isUnprocessableContent());
    }

    @Test
    void findForClient_returnsSummaries() throws Exception {
        when(workoutScheduleService.findForClient(2L)).thenReturn(List.of(new ScheduleSummaryResponse(
                9L, 2L, 7L, "Push day", com.lifey.trainer.Recurrence.WEEKLY,
                List.of(java.time.DayOfWeek.MONDAY, java.time.DayOfWeek.THURSDAY), null,
                LocalDate.of(2026, Month.JULY, 6), LocalDate.of(2026, Month.OCTOBER, 6), 3, 1, 20, null)));

        mockMvc.perform(get("/api/v1/trainer/clients/2/schedules"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].doneCount").value(3))
                .andExpect(jsonPath("$[0].remainingCount").value(20));
    }

    @Test
    void findScheduledSessions_returnsOccurrences() throws Exception {
        when(workoutScheduleService.findScheduledSessions(2L, LocalDate.of(2026, Month.JULY, 6), LocalDate.of(2026, Month.JULY, 13)))
                .thenReturn(List.of(new ScheduledSessionResponse(
                        30L, LocalDate.of(2026, Month.JULY, 9), null, "Push day", OccurrenceStatus.UPCOMING, 9L, null)));

        mockMvc.perform(get("/api/v1/trainer/clients/2/scheduled-sessions")
                        .param("from", "2026-07-06").param("to", "2026-07-13"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status").value("UPCOMING"));
    }

    @Test
    void findScheduledSessionsForTrainer_returnsOccurrencesAcrossClients() throws Exception {
        when(workoutScheduleService.findScheduledSessionsForTrainer(
                LocalDate.of(2026, Month.JULY, 6), LocalDate.of(2026, Month.JULY, 13)))
                .thenReturn(List.of(new TrainerCalendarSessionResponse(
                        30L, 2L, "anna@example.com", LocalDate.of(2026, Month.JULY, 9), null,
                        "Push day", OccurrenceStatus.UPCOMING, 9L, null, null)));

        mockMvc.perform(get("/api/v1/trainer/scheduled-sessions")
                        .param("from", "2026-07-06").param("to", "2026-07-13"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].clientId").value(2))
                .andExpect(jsonPath("$[0].clientEmail").value("anna@example.com"))
                .andExpect(jsonPath("$[0].status").value("UPCOMING"));
    }

    @Test
    void findScheduledSessionsForTrainer_rangeExceededReturns400() throws Exception {
        when(workoutScheduleService.findScheduledSessionsForTrainer(any(), any()))
                .thenThrow(new CalendarRangeExceededException("nope"));

        mockMvc.perform(get("/api/v1/trainer/scheduled-sessions")
                        .param("from", "2026-07-06").param("to", "2026-12-13"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cancelSchedule_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/trainer/schedules/9"))
                .andExpect(status().isNoContent());
    }

    @Test
    void cancelSchedule_notOwnedReturns404() throws Exception {
        doThrow(new ScheduleNotFoundException("nope"))
                .when(workoutScheduleService).cancelSchedule(9L);

        mockMvc.perform(delete("/api/v1/trainer/schedules/9"))
                .andExpect(status().isNotFound());
    }

    @Test
    void cancelOccurrence_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/trainer/scheduled-sessions/30"))
                .andExpect(status().isNoContent());
    }

    @Test
    void cancelOccurrence_notCancellableReturns409() throws Exception {
        doThrow(new OccurrenceNotCancellableException("nope"))
                .when(workoutScheduleService).cancelOccurrence(30L);

        mockMvc.perform(delete("/api/v1/trainer/scheduled-sessions/30"))
                .andExpect(status().isConflict());
    }
}
