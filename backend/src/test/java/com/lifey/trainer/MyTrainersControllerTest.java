package com.lifey.trainer;

import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.service.TrainerAccessService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(MyTrainersController.class)
class MyTrainersControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerAccessService trainerAccessService;

    @Test
    void findActiveTrainers_returnsList() throws Exception {
        when(trainerAccessService.findActiveTrainersForClient()).thenReturn(List.of(
                new MyTrainerResponse(1L, "trainer@example.com", Instant.parse("2026-06-01T00:00:00Z"))));

        mockMvc.perform(get("/api/v1/my-trainers"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].trainerEmail").value("trainer@example.com"));
    }

    @Test
    void leave_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/my-trainers/1"))
                .andExpect(status().isNoContent());
    }
}
