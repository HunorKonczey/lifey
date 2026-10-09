package com.lifey.trainer;

import com.lifey.trainer.controller.InviteLinkJoinController;
import com.lifey.trainer.controller.TrainerInviteLinkController;
import com.lifey.trainer.dto.CreatedTrainerInviteLinkResponse;
import com.lifey.trainer.dto.InviteLinkPreviewResponse;
import com.lifey.trainer.dto.TrainerInviteLinkResponse;
import com.lifey.trainer.exception.AlreadyClientException;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.exception.InviteRateLimitedException;
import com.lifey.trainer.service.TrainerInviteLinkService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest({TrainerInviteLinkController.class, InviteLinkJoinController.class})
class InviteLinkControllersTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerInviteLinkService service;

    @Test
    void create_returnsTheTokenWithTheLink() throws Exception {
        when(service.create()).thenReturn(new CreatedTrainerInviteLinkResponse(
                9L, "the-token", Instant.parse("2026-06-01T00:00:00Z"), Instant.parse("2026-06-08T00:00:00Z")));

        mockMvc.perform(post("/api/v1/trainer/invite-links"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9))
                .andExpect(jsonPath("$.token").value("the-token"))
                .andExpect(jsonPath("$.expiresAt").value("2026-06-08T00:00:00Z"));
    }

    @Test
    void create_atTheCapReturns429() throws Exception {
        when(service.create()).thenThrow(new InviteRateLimitedException("too many"));

        mockMvc.perform(post("/api/v1/trainer/invite-links")).andExpect(status().isTooManyRequests());
    }

    @Test
    void list_neverReturnsATokenForAnExistingLink() throws Exception {
        when(service.findActiveForTrainer()).thenReturn(List.of(new TrainerInviteLinkResponse(
                9L, Instant.parse("2026-06-01T00:00:00Z"), Instant.parse("2026-06-08T00:00:00Z"))));

        mockMvc.perform(get("/api/v1/trainer/invite-links"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(9))
                .andExpect(jsonPath("$[0].token").doesNotExist());
    }

    @Test
    void revoke_returnsNoContent_andAGoneLinkReturns404() throws Exception {
        mockMvc.perform(delete("/api/v1/trainer/invite-links/9")).andExpect(status().isNoContent());
        verify(service).revoke(9L);

        doThrow(new InviteNotFoundException("gone")).when(service).revoke(10L);
        mockMvc.perform(delete("/api/v1/trainer/invite-links/10")).andExpect(status().isNotFound());
    }

    @Test
    void preview_namesTheTrainer_andADeadLinkReturns404() throws Exception {
        when(service.preview("ok")).thenReturn(new InviteLinkPreviewResponse("Kata Coach"));
        when(service.preview("dead")).thenThrow(new InviteNotFoundException("gone"));

        mockMvc.perform(get("/api/v1/trainer-invite-links/ok"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.trainerName").value("Kata Coach"));
        mockMvc.perform(get("/api/v1/trainer-invite-links/dead")).andExpect(status().isNotFound());
    }

    @Test
    void accept_returnsNoContent_alreadyAClientReturns409_deadLinkReturns404() throws Exception {
        mockMvc.perform(post("/api/v1/trainer-invite-links/ok/accept")).andExpect(status().isNoContent());
        verify(service).redeem("ok");

        doThrow(new AlreadyClientException("already")).when(service).redeem("client");
        doThrow(new InviteNotFoundException("gone")).when(service).redeem("dead");
        mockMvc.perform(post("/api/v1/trainer-invite-links/client/accept")).andExpect(status().isConflict());
        mockMvc.perform(post("/api/v1/trainer-invite-links/dead/accept")).andExpect(status().isNotFound());
    }
}
