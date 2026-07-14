package com.lifey.steps;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.steps.dto.DailyStepCountResponse;
import com.lifey.steps.service.DailyStepCountService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.time.LocalDate;
import java.time.Month;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(DailyStepCountController.class)
class DailyStepCountControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    DailyStepCountService stepCountService;

    @Test
    void list_returnsOk() throws Exception {
        when(stepCountService.findAll())
                .thenReturn(List.of(new DailyStepCountResponse(1L, LocalDate.of(2026, Month.JUNE, 18), 8200,
                        Instant.parse("2026-06-18T08:00:00Z"), null)));

        mockMvc.perform(get("/api/v1/steps"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].steps").value(8200))
                .andExpect(jsonPath("$[0].date").value("2026-06-18"));
    }

    @Test
    void list_withFromAndTo_usesRangeQuery() throws Exception {
        when(stepCountService.findAll(LocalDate.of(2026, Month.JUNE, 1), LocalDate.of(2026, Month.JUNE, 30)))
                .thenReturn(List.of(new DailyStepCountResponse(1L, LocalDate.of(2026, Month.JUNE, 18), 8200,
                        Instant.parse("2026-06-18T08:00:00Z"), null)));

        mockMvc.perform(get("/api/v1/steps").param("from", "2026-06-01").param("to", "2026-06-30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].steps").value(8200));

        verify(stepCountService, never()).findAll();
    }

    @Test
    void delta_returnsPageIncludingTombstones() throws Exception {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        DailyStepCountResponse tombstoned = new DailyStepCountResponse(2L, LocalDate.of(2026, Month.JUNE, 18), 8200,
                Instant.parse("2026-06-19T00:00:00Z"), Instant.parse("2026-06-19T00:00:00Z"));
        when(stepCountService.findDelta(eq(since), any())).thenReturn(new PageImpl<>(List.of(tombstoned)));

        mockMvc.perform(get("/api/v1/steps").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(stepCountService.create(any()))
                .thenReturn(new DailyStepCountResponse(5L, LocalDate.of(2026, Month.JUNE, 1), 11000,
                        Instant.parse("2026-06-01T00:00:00Z"), null));

        mockMvc.perform(post("/api/v1/steps").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"date\":\"2026-06-01\",\"steps\":11000}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(5));
    }

    @Test
    void create_futureDateOrNegativeStepsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/steps").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"date\":\"2999-01-01\",\"steps\":-5}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        verify(stepCountService, never()).create(any());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/steps/1"))
                .andExpect(status().isNoContent());

        verify(stepCountService).delete(1L);
    }

    @Test
    void delete_notFoundReturns404() throws Exception {
        doThrow(new ResourceNotFoundException("Daily step count not found: 99"))
                .when(stepCountService).delete(99L);

        mockMvc.perform(delete("/api/v1/steps/99"))
                .andExpect(status().isNotFound());
    }
}
