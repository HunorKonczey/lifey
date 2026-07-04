package com.lifey.trainer;

import com.lifey.trainer.controller.ClientInviteController;
import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.RespondToInviteRequest;
import com.lifey.trainer.service.TrainerInviteService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ClientInviteController.class)
class ClientInviteControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerInviteService trainerInviteService;

    @Test
    void findPending_returnsList() throws Exception {
        when(trainerInviteService.findPendingForClient()).thenReturn(List.of(new PendingInviteResponse(
                1L, "trainer@example.com", Instant.parse("2026-06-01T00:00:00Z"), Instant.parse("2026-06-02T00:00:00Z"))));

        mockMvc.perform(get("/api/v1/trainer-invites/pending"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].trainerEmail").value("trainer@example.com"));
    }

    @Test
    void respond_acceptReturnsNoContent() throws Exception {
        mockMvc.perform(post("/api/v1/trainer-invites/1/respond").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isNoContent());

        verify(trainerInviteService).respond(eq(1L), argThatAccept(true));
    }

    @Test
    void respond_missingAcceptReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/trainer-invites/1/respond").contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    private static RespondToInviteRequest argThatAccept(boolean accept) {
        return org.mockito.ArgumentMatchers.argThat(r -> r.accept() == accept);
    }
}
