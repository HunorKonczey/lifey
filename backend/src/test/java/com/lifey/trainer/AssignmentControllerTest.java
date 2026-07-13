package com.lifey.trainer;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.controller.AssignmentController;
import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.BulkAssignmentResponse;
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
import java.util.stream.Collectors;
import java.util.stream.LongStream;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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
    void assign_returnsCreatedWithPerClientOutcome() throws Exception {
        when(contentAssignmentService.assign(any())).thenReturn(new BulkAssignmentResponse(
                List.of(new BulkAssignmentResponse.BulkAssignmentItem(
                        2L, 1L, 88L, Instant.parse("2026-06-01T00:00:00Z"))),
                List.of(3L)));

        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientIds\":[2,3],\"contentType\":\"TEMPLATE\",\"sourceId\":7}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.assignments[0].clientId").value(2))
                .andExpect(jsonPath("$.assignments[0].copiedId").value(88))
                .andExpect(jsonPath("$.skippedClientIds[0]").value(3));
    }

    @Test
    void assign_missingFieldsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void assign_emptyClientIdsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientIds\":[],\"contentType\":\"TEMPLATE\",\"sourceId\":7}"))
                .andExpect(status().isBadRequest());
        verify(contentAssignmentService, never()).assign(any());
    }

    @Test
    void assign_moreThanHundredClientIdsReturns400() throws Exception {
        String ids = LongStream.rangeClosed(1, 101).mapToObj(String::valueOf).collect(Collectors.joining(","));

        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientIds\":[" + ids + "],\"contentType\":\"TEMPLATE\",\"sourceId\":7}"))
                .andExpect(status().isBadRequest());
        verify(contentAssignmentService, never()).assign(any());
    }

    @Test
    void assign_notYourClientReturns403() throws Exception {
        when(contentAssignmentService.assign(any())).thenThrow(new NotYourClientException("nope"));

        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientIds\":[2],\"contentType\":\"TEMPLATE\",\"sourceId\":7}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void assign_sourceNotFoundReturns404() throws Exception {
        when(contentAssignmentService.assign(any())).thenThrow(new ResourceNotFoundException("not found"));

        mockMvc.perform(post("/api/v1/trainer/assignments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientIds\":[2],\"contentType\":\"TEMPLATE\",\"sourceId\":7}"))
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
