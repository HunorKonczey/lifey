package com.lifey.trainer;

import com.lifey.trainer.controller.TrainerClientController;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.userdetails.PrimaryGoal;
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
                new TrainerClientResponse(2L, "client@example.com", "Kiss", "Anna",
                        Instant.parse("2026-06-01T00:00:00Z"),
                        List.of(), 0, 0, null, null, 0, null, null, null, null, 0, 0, null)));

        mockMvc.perform(get("/api/v1/trainer/clients"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].clientEmail").value("client@example.com"))
                // Name feeds the mobile "new conversation" picker's person row.
                .andExpect(jsonPath("$[0].clientFirstName").value("Kiss"))
                .andExpect(jsonPath("$[0].clientLastName").value("Anna"));
    }

    @Test
    void findActiveClients_reportsTheCardFiguresWhenThereIsSomethingToReport() throws Exception {
        when(trainerAccessService.findActiveClientsForTrainer()).thenReturn(List.of(
                new TrainerClientResponse(2L, "client@example.com", "Kiss", "Anna",
                        Instant.parse("2026-06-01T00:00:00Z"),
                        List.of(), 0, 6, null, null, 0, 1631, 2, 1900, 10000, 4, 3, PrimaryGoal.GAIN_MUSCLE)));

        mockMvc.perform(get("/api/v1/trainer/clients"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].avgCalories7d").value(1631))
                .andExpect(jsonPath("$[0].prCount7d").value(2))
                .andExpect(jsonPath("$[0].dailyCalorieGoal").value(1900))
                .andExpect(jsonPath("$[0].dailyStepGoal").value(10000))
                .andExpect(jsonPath("$[0].plannedSessions7d").value(4))
                .andExpect(jsonPath("$[0].completedSessions7d").value(3))
                .andExpect(jsonPath("$[0].primaryGoal").value("GAIN_MUSCLE"));
    }

    @Test
    void findActiveClients_aClientWithoutMealsHasNoAverageButZeroRecordsIsARealAnswer() throws Exception {
        when(trainerAccessService.findActiveClientsForTrainer()).thenReturn(List.of(
                new TrainerClientResponse(2L, "client@example.com", "Kiss", "Anna",
                        Instant.parse("2026-06-01T00:00:00Z"),
                        List.of(), 0, 0, null, null, 0, null, 0, null, null, 0, 0, null)));

        mockMvc.perform(get("/api/v1/trainer/clients"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].avgCalories7d").doesNotExist())
                .andExpect(jsonPath("$[0].prCount7d").value(0))
                // No goal set: the field is absent (null), never 0.
                .andExpect(jsonPath("$[0].dailyCalorieGoal").doesNotExist())
                // Nothing set, nothing scheduled: absent goals, and zero sessions is a real answer.
                .andExpect(jsonPath("$[0].dailyStepGoal").doesNotExist())
                .andExpect(jsonPath("$[0].primaryGoal").doesNotExist())
                .andExpect(jsonPath("$[0].plannedSessions7d").value(0))
                .andExpect(jsonPath("$[0].completedSessions7d").value(0));
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
