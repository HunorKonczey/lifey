package com.lifey.water;

import com.lifey.water.dto.WaterEntryResponse;
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
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(WaterEntryController.class)
class WaterEntryControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    WaterEntryService waterEntryService;

    @Test
    void list_returnsOkWithJson() throws Exception {
        when(waterEntryService.findAll()).thenReturn(List.of(
                new WaterEntryResponse(1L, Instant.parse("2026-06-18T08:00:00Z"), 0.9, 2L, "Creatine Shake",
                        Instant.parse("2026-06-18T08:00:00Z"), null)));

        mockMvc.perform(get("/api/v1/water-entries"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].volumeLiters").value(0.9))
                .andExpect(jsonPath("$[0].sourceName").value("Creatine Shake"));
    }

    @Test
    void delta_returnsPageIncludingTombstones() throws Exception {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        WaterEntryResponse tombstoned = new WaterEntryResponse(2L, Instant.parse("2026-06-18T08:00:00Z"), 0.5,
                null, null, Instant.parse("2026-06-19T00:00:00Z"), Instant.parse("2026-06-19T00:00:00Z"));
        when(waterEntryService.findDelta(eq(since), any())).thenReturn(new PageImpl<>(List.of(tombstoned)));

        mockMvc.perform(get("/api/v1/water-entries").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());
    }

    @Test
    void create_manualEntry_returnsCreated() throws Exception {
        when(waterEntryService.create(any())).thenReturn(
                new WaterEntryResponse(3L, Instant.parse("2026-06-18T08:00:00Z"), 0.5, null, null,
                        Instant.parse("2026-06-18T08:00:00Z"), null));

        mockMvc.perform(post("/api/v1/water-entries").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"consumedAt\":\"2026-06-18T08:00:00Z\",\"volumeLiters\":0.5}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(3))
                .andExpect(jsonPath("$.sourceId").doesNotExist());
    }

    @Test
    void create_missingVolumeReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/v1/water-entries").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"consumedAt\":\"2026-06-18T08:00:00Z\"}"))
                .andExpect(status().isBadRequest());

        verify(waterEntryService, never()).create(any());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/water-entries/1"))
                .andExpect(status().isNoContent());

        verify(waterEntryService).delete(1L);
    }
}
