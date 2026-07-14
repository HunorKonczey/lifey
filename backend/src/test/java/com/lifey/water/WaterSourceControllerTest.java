package com.lifey.water;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.water.dto.WaterSourceResponse;
import com.lifey.water.service.WaterSourceService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(WaterSourceController.class)
class WaterSourceControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    WaterSourceService waterSourceService;

    @Test
    void list_returnsOkWithJson() throws Exception {
        when(waterSourceService.findAll())
                .thenReturn(List.of(new WaterSourceResponse(1L, "Creatine Shake", 0.9)));

        mockMvc.perform(get("/api/v1/water-sources"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("Creatine Shake"))
                .andExpect(jsonPath("$[0].volumeLiters").value(0.9));
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(waterSourceService.create(any()))
                .thenReturn(new WaterSourceResponse(5L, "Water Bottle", 0.75));

        mockMvc.perform(post("/api/v1/water-sources").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Water Bottle\",\"volumeLiters\":0.75}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(5))
                .andExpect(jsonPath("$.volumeLiters").value(0.75));
    }

    @Test
    void create_invalidReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/v1/water-sources").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"volumeLiters\":-1}"))
                .andExpect(status().isBadRequest());

        verify(waterSourceService, never()).create(any());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/water-sources/1"))
                .andExpect(status().isNoContent());

        verify(waterSourceService).delete(1L);
    }

    @Test
    void delete_notFoundReturns404() throws Exception {
        doThrow(new ResourceNotFoundException("Water source not found: 99"))
                .when(waterSourceService).delete(99L);

        mockMvc.perform(delete("/api/v1/water-sources/99"))
                .andExpect(status().isNotFound());
    }
}
