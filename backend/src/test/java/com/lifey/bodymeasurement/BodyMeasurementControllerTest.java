package com.lifey.bodymeasurement;

import com.lifey.bodymeasurement.dto.BodyMeasurementResponse;
import com.lifey.bodymeasurement.service.BodyMeasurementService;
import com.lifey.common.exception.ResourceNotFoundException;
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
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(BodyMeasurementController.class)
class BodyMeasurementControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    BodyMeasurementService service;

    private static BodyMeasurementResponse waist(long id, Instant deletedAt) {
        return new BodyMeasurementResponse(id, LocalDate.of(2026, Month.JUNE, 18), MeasurementSite.WAIST, 82.5,
                Instant.parse("2026-06-18T08:00:00Z"), deletedAt);
    }

    @Test
    void list_returnsOk() throws Exception {
        when(service.findAll()).thenReturn(List.of(waist(1L, null)));

        mockMvc.perform(get("/api/v1/measurements"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].site").value("WAIST"))
                .andExpect(jsonPath("$[0].valueCm").value(82.5))
                .andExpect(jsonPath("$[0].date").value("2026-06-18"));
    }

    @Test
    void delta_returnsPageIncludingTombstones() throws Exception {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        when(service.findDelta(eq(since), any()))
                .thenReturn(new PageImpl<>(List.of(waist(2L, Instant.parse("2026-06-19T00:00:00Z")))));

        mockMvc.perform(get("/api/v1/measurements").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());

        verify(service, never()).findAll();
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(service.create(any())).thenReturn(waist(3L, null));

        mockMvc.perform(post("/api/v1/measurements")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"date\":\"2026-06-18\",\"site\":\"WAIST\",\"valueCm\":82.5}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(3));
    }

    @Test
    void create_rejectsInvalidBodies() throws Exception {
        String[] bad = {
                "{\"date\":\"2026-06-18\",\"site\":\"WAIST\",\"valueCm\":0}",
                "{\"date\":\"2026-06-18\",\"site\":\"WAIST\",\"valueCm\":300.5}",
                "{\"date\":\"2026-06-18\",\"site\":\"WAIST\"}",
                "{\"date\":\"2026-06-18\",\"site\":\"ELBOW\",\"valueCm\":30}",
                "{\"date\":\"2999-01-01\",\"site\":\"WAIST\",\"valueCm\":80}",
                "{\"site\":\"WAIST\",\"valueCm\":80}"
        };
        for (String body : bad) {
            mockMvc.perform(post("/api/v1/measurements").contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isBadRequest());
        }
        verify(service, never()).create(any());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/measurements/5")).andExpect(status().isNoContent());
        verify(service).delete(5L);
    }

    @Test
    void delete_unknownId_returnsNotFound() throws Exception {
        doThrow(new ResourceNotFoundException("nope")).when(service).delete(9L);

        mockMvc.perform(delete("/api/v1/measurements/9")).andExpect(status().isNotFound());
    }
}
