package com.lifey.trainer;

import com.lifey.trainer.controller.TemplateUsageController;
import com.lifey.trainer.dto.TemplateUsageResponse;
import com.lifey.trainer.service.TemplateUsageService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(TemplateUsageController.class)
class TemplateUsageControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    TemplateUsageService service;

    @Test
    void usage_listsEachUsedTemplateWithItsClients() throws Exception {
        when(service.usageForCurrentTrainer()).thenReturn(List.of(
                new TemplateUsageResponse(10L, List.of(100L, 101L), List.of(100L)),
                new TemplateUsageResponse(12L, List.of(), List.of(102L))));

        mockMvc.perform(get("/api/v1/trainer/templates/usage"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].templateId").value(10))
                .andExpect(jsonPath("$[0].assignedClientIds[1]").value(101))
                .andExpect(jsonPath("$[0].scheduledClientIds[0]").value(100))
                .andExpect(jsonPath("$[1].assignedClientIds").isEmpty())
                .andExpect(jsonPath("$[1].scheduledClientIds[0]").value(102));
    }
}
