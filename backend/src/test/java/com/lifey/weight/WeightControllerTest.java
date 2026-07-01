package com.lifey.weight;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.weight.dto.WeightResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(WeightController.class)
class WeightControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    WeightService weightService;

    @Test
    void list_returnsOk() throws Exception {
        when(weightService.findAll())
                .thenReturn(List.of(new WeightResponse(1L, LocalDate.of(2026, 6, 18), 80.0,
                        Instant.parse("2026-06-18T08:00:00Z"), null)));

        mockMvc.perform(get("/api/v1/weights"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].weight").value(80.0))
                .andExpect(jsonPath("$[0].date").value("2026-06-18"));
    }

    @Test
    void delta_returnsPageIncludingTombstones() throws Exception {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        WeightResponse tombstoned = new WeightResponse(2L, LocalDate.of(2026, 6, 18), 80.0,
                Instant.parse("2026-06-19T00:00:00Z"), Instant.parse("2026-06-19T00:00:00Z"));
        when(weightService.findDelta(eq(since), any())).thenReturn(new PageImpl<>(List.of(tombstoned)));

        mockMvc.perform(get("/api/v1/weights").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(weightService.create(any()))
                .thenReturn(new WeightResponse(5L, LocalDate.of(2026, 6, 1), 78.4,
                        Instant.parse("2026-06-01T00:00:00Z"), null));

        mockMvc.perform(post("/api/v1/weights").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"date\":\"2026-06-01\",\"weight\":78.4}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(5));
    }

    @Test
    void create_futureDateOrNegativeWeightReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/weights").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"date\":\"2999-01-01\",\"weight\":-5}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        verify(weightService, never()).create(any());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/weights/1"))
                .andExpect(status().isNoContent());

        verify(weightService).delete(1L);
    }

    @Test
    void delete_notFoundReturns404() throws Exception {
        doThrow(new ResourceNotFoundException("Weight entry not found: 99"))
                .when(weightService).delete(99L);

        mockMvc.perform(delete("/api/v1/weights/99"))
                .andExpect(status().isNotFound());
    }
}
