package com.lifey.trainer.request.controller;

import com.lifey.trainer.request.TrainerRequestStatus;
import com.lifey.trainer.request.dto.SuperAdminTrainerRequestResponse;
import com.lifey.trainer.request.exception.TrainerRequestAlreadyDecidedException;
import com.lifey.trainer.request.service.TrainerRequestService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The HTTP layer only (66 §2) — business rules live in {@code TrainerRequestServiceImplTest}. */
@WebMvcTest(SuperAdminTrainerRequestController.class)
class SuperAdminTrainerRequestControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TrainerRequestService trainerRequestService;

    @Test
    void findPending_returnsThePage() throws Exception {
        SuperAdminTrainerRequestResponse response = new SuperAdminTrainerRequestResponse(5L, 1L, "trainer@example.com",
                TrainerRequestStatus.PENDING, "motivation", 10, "landing-hero",
                Instant.parse("2026-08-28T09:00:00Z"), null);
        when(trainerRequestService.findPending(any())).thenReturn(new PageImpl<>(List.of(response)));

        mockMvc.perform(get("/api/v1/superadmin/trainer-requests"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].userEmail").value("trainer@example.com"));
    }

    @Test
    void approve_returns204() throws Exception {
        mockMvc.perform(post("/api/v1/superadmin/trainer-requests/5/approve"))
                .andExpect(status().isNoContent());

        verify(trainerRequestService).approve(5L);
    }

    @Test
    void approve_alreadyDecided_returns409() throws Exception {
        doThrow(new TrainerRequestAlreadyDecidedException("already decided"))
                .when(trainerRequestService).approve(5L);

        mockMvc.perform(post("/api/v1/superadmin/trainer-requests/5/approve"))
                .andExpect(status().isConflict());
    }

    @Test
    void reject_returns204() throws Exception {
        mockMvc.perform(post("/api/v1/superadmin/trainer-requests/5/reject"))
                .andExpect(status().isNoContent());

        verify(trainerRequestService).reject(5L);
    }
}
