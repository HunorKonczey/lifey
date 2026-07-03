package com.lifey.trainer;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentResponse;
import com.lifey.trainer.exception.NotYourClientException;
import com.lifey.trainer.service.ContentAssignmentService;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AssignmentController.class)
class AssignmentControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    ContentAssignmentService contentAssignmentService;

    @Test
    void assign_returnsCreated() throws Exception {
        when(contentAssignmentService.assign(any())).thenReturn(new AssignmentResponse(
                1L, ContentType.TEMPLATE, 7L, 88L, Instant.parse("2026-06-01T00:00:00Z"), false));

        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientId\":2,\"contentType\":\"TEMPLATE\",\"sourceId\":7}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.copiedId").value(88))
                .andExpect(jsonPath("$.previouslyAssigned").value(false));
    }

    @Test
    void assign_missingFieldsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void assign_notYourClientReturns403() throws Exception {
        when(contentAssignmentService.assign(any())).thenThrow(new NotYourClientException("nope"));

        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientId\":2,\"contentType\":\"TEMPLATE\",\"sourceId\":7}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void assign_sourceNotFoundReturns404() throws Exception {
        when(contentAssignmentService.assign(any())).thenThrow(new ResourceNotFoundException("not found"));

        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientId\":2,\"contentType\":\"TEMPLATE\",\"sourceId\":7}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void findForClient_returnsList() throws Exception {
        when(contentAssignmentService.findForClient(2L)).thenReturn(List.of(new AssignmentListItemResponse(
                1L, ContentType.RECIPE, 12L, 66L, Instant.parse("2026-06-01T00:00:00Z"))));

        mockMvc.perform(get("/api/v1/trainer/clients/2/assignments"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].copiedId").value(66));
    }
}
