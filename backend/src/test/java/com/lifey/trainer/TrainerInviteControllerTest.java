package com.lifey.trainer;

import com.lifey.trainer.controller.TrainerInviteController;
import com.lifey.trainer.dto.TrainerInviteResponse;
import com.lifey.trainer.exception.AlreadyClientException;
import com.lifey.trainer.exception.InviteRateLimitedException;
import com.lifey.trainer.exception.UserNotFoundForInviteException;
import com.lifey.trainer.service.TrainerInviteService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(TrainerInviteController.class)
class TrainerInviteControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerInviteService trainerInviteService;

    @Test
    void invite_returnsCreated() throws Exception {
        when(trainerInviteService.invite(any())).thenReturn(new TrainerInviteResponse(
                1L, "client@example.com", Instant.parse("2026-06-01T00:00:00Z"), Instant.parse("2026-06-02T00:00:00Z")));

        mockMvc.perform(post("/api/v1/trainer/invites").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"client@example.com\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.clientEmail").value("client@example.com"));
    }

    @Test
    void invite_blankEmailReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/trainer/invites").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invite_userNotFoundReturns404() throws Exception {
        when(trainerInviteService.invite(any())).thenThrow(new UserNotFoundForInviteException("not found"));

        mockMvc.perform(post("/api/v1/trainer/invites").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"nobody@example.com\"}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void invite_alreadyClientReturns409() throws Exception {
        when(trainerInviteService.invite(any())).thenThrow(new AlreadyClientException("already"));

        mockMvc.perform(post("/api/v1/trainer/invites").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"client@example.com\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void invite_rateLimitedReturns429() throws Exception {
        when(trainerInviteService.invite(any())).thenThrow(new InviteRateLimitedException("too many"));

        mockMvc.perform(post("/api/v1/trainer/invites").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"client@example.com\"}"))
                .andExpect(status().isTooManyRequests());
    }

    @Test
    void findPending_returnsList() throws Exception {
        when(trainerInviteService.findPendingForTrainer()).thenReturn(List.of(new TrainerInviteResponse(
                1L, "client@example.com", Instant.parse("2026-06-01T00:00:00Z"), Instant.parse("2026-06-02T00:00:00Z"))));

        mockMvc.perform(get("/api/v1/trainer/invites"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].clientEmail").value("client@example.com"));
    }

    @Test
    void cancel_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/trainer/invites/1"))
                .andExpect(status().isNoContent());
    }
}
