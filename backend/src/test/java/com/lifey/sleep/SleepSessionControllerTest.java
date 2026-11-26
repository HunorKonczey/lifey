package com.lifey.sleep;

import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.sleep.dto.SleepSessionResponse;
import com.lifey.sleep.service.SleepSessionService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
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

/** docs/integrations/89 G2.1: the sleep-session endpoints. */
@WebMvcTest(SleepSessionController.class)
class SleepSessionControllerTest {

    private static final String NIGHT = "{\"startedAt\":\"2026-11-20T22:40:00Z\",\"endedAt\":\"2026-11-21T06:10:00Z\","
            + "\"asleepMinutes\":420,\"deepMinutes\":80,\"lightMinutes\":230,\"remMinutes\":110,\"awakeMinutes\":30,"
            + "\"sourceAppName\":\"Garmin Connect\",\"healthRecordId\":\"hc-sleep-1\"}";

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    SleepSessionService service;

    private static SleepSessionResponse night(long id, Instant deletedAt) {
        return new SleepSessionResponse(id, Instant.parse("2026-11-20T22:40:00Z"), Instant.parse("2026-11-21T06:10:00Z"),
                420, 80, 230, 110, 30, "Garmin Connect", "hc-sleep-1", Instant.parse("2026-11-21T06:15:00Z"), deletedAt);
    }

    @Test
    void list_returnsTheSessionsWithTheirStages() throws Exception {
        when(service.findAll()).thenReturn(List.of(night(1L, null)));

        mockMvc.perform(get("/api/v1/sleep-sessions"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].endedAt").value("2026-11-21T06:10:00Z"))
                .andExpect(jsonPath("$[0].deepMinutes").value(80))
                .andExpect(jsonPath("$[0].sourceAppName").value("Garmin Connect"))
                .andExpect(jsonPath("$[0].updatedAt").exists());
    }

    @Test
    void delta_routesOnUpdatedSinceAndReturnsTombstones() throws Exception {
        Instant since = Instant.parse("2026-11-20T00:00:00Z");
        when(service.findDelta(eq(since), any()))
                .thenReturn(new PageImpl<>(List.of(night(2L, Instant.parse("2026-11-22T08:00:00Z")))));

        mockMvc.perform(get("/api/v1/sleep-sessions").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());

        verify(service, never()).findAll();
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(service.create(any())).thenReturn(night(3L, null));

        mockMvc.perform(post("/api/v1/sleep-sessions").contentType(MediaType.APPLICATION_JSON).content(NIGHT))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(3))
                .andExpect(jsonPath("$.healthRecordId").value("hc-sleep-1"));
    }

    @Test
    void create_withoutStagesIsValid() throws Exception {
        when(service.create(any())).thenReturn(night(4L, null));

        mockMvc.perform(post("/api/v1/sleep-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-11-20T22:40:00Z\",\"endedAt\":\"2026-11-21T06:10:00Z\"}"))
                .andExpect(status().isCreated());
    }

    @Test
    void create_rejectsInvalidBodies() throws Exception {
        String[] bad = {
                // no start, no end
                "{\"endedAt\":\"2026-11-21T06:10:00Z\"}",
                "{\"startedAt\":\"2026-11-20T22:40:00Z\"}",
                // the end before, or at, the start
                "{\"startedAt\":\"2026-11-21T06:10:00Z\",\"endedAt\":\"2026-11-20T22:40:00Z\"}",
                "{\"startedAt\":\"2026-11-21T06:10:00Z\",\"endedAt\":\"2026-11-21T06:10:00Z\"}",
                // a night that hasn't ended yet
                "{\"startedAt\":\"2999-01-01T22:00:00Z\",\"endedAt\":\"2999-01-02T06:00:00Z\"}",
                // negative minutes
                "{\"startedAt\":\"2026-11-20T22:40:00Z\",\"endedAt\":\"2026-11-21T06:10:00Z\",\"deepMinutes\":-5}",
                // over-long strings
                "{\"startedAt\":\"2026-11-20T22:40:00Z\",\"endedAt\":\"2026-11-21T06:10:00Z\",\"sourceAppName\":\""
                        + "x".repeat(65) + "\"}",
                "{\"startedAt\":\"2026-11-20T22:40:00Z\",\"endedAt\":\"2026-11-21T06:10:00Z\",\"healthRecordId\":\""
                        + "x".repeat(129) + "\"}"
        };
        for (String body : bad) {
            mockMvc.perform(post("/api/v1/sleep-sessions").contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isBadRequest());
        }
        verify(service, never()).create(any());
    }

    @Test
    void create_aReImportIsAConflict() throws Exception {
        when(service.create(any())).thenThrow(new DuplicateResourceException("Sleep session already imported: hc-sleep-1"));

        mockMvc.perform(post("/api/v1/sleep-sessions").contentType(MediaType.APPLICATION_JSON).content(NIGHT))
                .andExpect(status().isConflict());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/sleep-sessions/5")).andExpect(status().isNoContent());
        verify(service).delete(5L);
    }

    @Test
    void delete_unknownId_returnsNotFound() throws Exception {
        doThrow(new ResourceNotFoundException("nope")).when(service).delete(9L);

        mockMvc.perform(delete("/api/v1/sleep-sessions/9")).andExpect(status().isNotFound());
    }
}
