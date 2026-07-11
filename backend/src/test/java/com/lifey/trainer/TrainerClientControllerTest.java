package com.lifey.trainer;

import com.lifey.trainer.controller.TrainerClientController;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.trainer.service.TrainerAccessService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(TrainerClientController.class)
class TrainerClientControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerAccessService trainerAccessService;

    @Test
    void findActiveClients_returnsList() throws Exception {
        when(trainerAccessService.findActiveClientsForTrainer()).thenReturn(List.of(
                new TrainerClientResponse(2L, "client@example.com", Instant.parse("2026-06-01T00:00:00Z"),
                        List.of(), 0, 0, null, null, 0)));

        mockMvc.perform(get("/api/v1/trainer/clients"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].clientEmail").value("client@example.com"));
    }

    @Test
    void revoke_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/trainer/clients/2"))
                .andExpect(status().isNoContent());
    }

    @Test
    void revoke_notYourClientReturns403() throws Exception {
        doThrow(new NotYourClientException("nope")).when(trainerAccessService).revokeClient(2L);

        mockMvc.perform(delete("/api/v1/trainer/clients/2"))
                .andExpect(status().isForbidden());
    }
}
