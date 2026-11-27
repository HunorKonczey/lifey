package com.lifey.vitals;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.vitals.dto.DailyVitalsResponse;
import com.lifey.vitals.service.DailyVitalsService;
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

/** docs/integrations/89 G3.1: the daily-vitals endpoints. */
@WebMvcTest(DailyVitalsController.class)
class DailyVitalsControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    DailyVitalsService service;

    private static DailyVitalsResponse day(long id, Instant deletedAt) {
        return new DailyVitalsResponse(id, LocalDate.parse("2026-11-21"), 52, 48.5, HrvMethod.RMSSD,
                Instant.parse("2026-11-21T08:00:00Z"), deletedAt);
    }

    private static String body(String json) {
        return "{\"date\":\"2026-11-21\"" + json + "}";
    }

    @Test
    void list_returnsTheDaysWithTheirMethod() throws Exception {
        when(service.findAll()).thenReturn(List.of(day(1L, null)));

        mockMvc.perform(get("/api/v1/vitals"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].date").value("2026-11-21"))
                .andExpect(jsonPath("$[0].restingHr").value(52))
                .andExpect(jsonPath("$[0].hrvMs").value(48.5))
                .andExpect(jsonPath("$[0].hrvMethod").value("RMSSD"))
                .andExpect(jsonPath("$[0].updatedAt").exists());
    }

    @Test
    void list_withARangeUsesTheRangeQuery() throws Exception {
        when(service.findAll(LocalDate.parse("2026-11-01"), null)).thenReturn(List.of());

        mockMvc.perform(get("/api/v1/vitals").param("from", "2026-11-01")).andExpect(status().isOk());

        verify(service, never()).findAll();
    }

    @Test
    void delta_routesOnUpdatedSinceAndReturnsTombstones() throws Exception {
        Instant since = Instant.parse("2026-11-20T00:00:00Z");
        when(service.findDelta(eq(since), any()))
                .thenReturn(new PageImpl<>(List.of(day(2L, Instant.parse("2026-11-22T08:00:00Z")))));

        mockMvc.perform(get("/api/v1/vitals").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());

        verify(service, never()).findAll();
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(service.create(any())).thenReturn(day(3L, null));

        mockMvc.perform(post("/api/v1/vitals").contentType(MediaType.APPLICATION_JSON)
                        .content(body(",\"restingHr\":52,\"hrvMs\":48.5,\"hrvMethod\":\"RMSSD\"")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(3));
    }

    @Test
    void create_withOnlyARestingHeartRateIsAccepted() throws Exception {
        when(service.create(any())).thenReturn(day(4L, null));

        mockMvc.perform(post("/api/v1/vitals").contentType(MediaType.APPLICATION_JSON).content(body(",\"restingHr\":55")))
                .andExpect(status().isCreated());
    }

    @Test
    void create_rejectsADayWithNoValue() throws Exception {
        mockMvc.perform(post("/api/v1/vitals").contentType(MediaType.APPLICATION_JSON).content(body("")))
                .andExpect(status().isBadRequest());
        verify(service, never()).create(any());
    }

    @Test
    void create_rejectsAnHrvWithoutItsMethodAndAMethodWithoutAValue() throws Exception {
        mockMvc.perform(post("/api/v1/vitals").contentType(MediaType.APPLICATION_JSON).content(body(",\"hrvMs\":40")))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/v1/vitals").contentType(MediaType.APPLICATION_JSON)
                        .content(body(",\"restingHr\":55,\"hrvMethod\":\"SDNN\"")))
                .andExpect(status().isBadRequest());
        verify(service, never()).create(any());
    }

    @Test
    void create_rejectsValuesOutsideTheSanityBounds() throws Exception {
        mockMvc.perform(post("/api/v1/vitals").contentType(MediaType.APPLICATION_JSON).content(body(",\"restingHr\":5")))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/v1/vitals").contentType(MediaType.APPLICATION_JSON)
                        .content(body(",\"hrvMs\":1500,\"hrvMethod\":\"SDNN\"")))
                .andExpect(status().isBadRequest());
        verify(service, never()).create(any());
    }

    @Test
    void delete_returnsNoContent_andAForeignIdIsNotFound() throws Exception {
        mockMvc.perform(delete("/api/v1/vitals/5")).andExpect(status().isNoContent());
        verify(service).delete(5L);

        doThrow(new ResourceNotFoundException("Daily vitals not found: 6")).when(service).delete(6L);
        mockMvc.perform(delete("/api/v1/vitals/6")).andExpect(status().isNotFound());
    }
}
