package com.lifey.trainer.request.controller;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.request.TrainerRequestStatus;
import com.lifey.trainer.request.dto.TrainerRequestResponse;
import com.lifey.trainer.request.service.TrainerRequestService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The HTTP layer only (66 §2) — business rules live in {@code TrainerRequestServiceImplTest}. */
@WebMvcTest(TrainerRequestController.class)
class TrainerRequestControllerTest {

    private static final Long USER_ID = 1L;

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerRequestService trainerRequestService;

    @MockitoBean
    CurrentUserProvider currentUserProvider;

    @BeforeEach
    void setUp() {
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
    }

    @Test
    void submit_returns201WithTheCreatedRequest() throws Exception {
        TrainerRequestResponse response = new TrainerRequestResponse(5L, TrainerRequestStatus.PENDING,
                "10 clients on spreadsheets", 10, Instant.parse("2026-08-28T09:00:00Z"), null);
        when(trainerRequestService.submit(eq(USER_ID), any())).thenReturn(response);

        mockMvc.perform(post("/api/v1/trainer-requests")
                        .contentType("application/json")
                        .content("{\"motivation\":\"10 clients on spreadsheets\",\"clientCount\":10,\"signupSource\":\"landing-hero\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(5))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void submit_alreadyOpen_returns409() throws Exception {
        when(trainerRequestService.submit(eq(USER_ID), any()))
                .thenThrow(new DuplicateResourceException("You already have an open trainer request"));

        mockMvc.perform(post("/api/v1/trainer-requests")
                        .contentType("application/json")
                        .content("{}"))
                .andExpect(status().isConflict());
    }

    @Test
    void submit_negativeClientCount_isRejectedWith400_beforeReachingTheService() throws Exception {
        mockMvc.perform(post("/api/v1/trainer-requests")
                        .contentType("application/json")
                        .content("{\"clientCount\":-1}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void findMine_returnsTheUsersMostRecentRequest() throws Exception {
        TrainerRequestResponse response = new TrainerRequestResponse(5L, TrainerRequestStatus.APPROVED,
                null, null, Instant.parse("2026-08-28T09:00:00Z"), Instant.parse("2026-08-28T10:00:00Z"));
        when(trainerRequestService.findMine(USER_ID)).thenReturn(response);

        mockMvc.perform(get("/api/v1/trainer-requests/me"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void findMine_noneSubmittedYet_returns404() throws Exception {
        when(trainerRequestService.findMine(USER_ID)).thenThrow(new ResourceNotFoundException("No trainer request found"));

        mockMvc.perform(get("/api/v1/trainer-requests/me"))
                .andExpect(status().isNotFound());
    }
}
