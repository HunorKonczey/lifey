package com.lifey.trainer;

import com.lifey.settings.service.SettingsService;
import com.lifey.trainer.controller.TrainerPreferencesController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.when;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(TrainerPreferencesController.class)
class TrainerPreferencesControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    SettingsService settingsService;

    @Test
    void get_returnsCurrentPreference() throws Exception {
        when(settingsService.isWeeklyReportEmailEnabled()).thenReturn(true);

        mockMvc.perform(get("/api/v1/trainer/preferences"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.weeklyReportEmailEnabled").value(true));
    }

    @Test
    void update_flipsPreferenceAndReturnsNewValue() throws Exception {
        when(settingsService.setWeeklyReportEmailEnabled(false)).thenReturn(false);

        mockMvc.perform(put("/api/v1/trainer/preferences")
                        .contentType(APPLICATION_JSON)
                        .content("{\"weeklyReportEmailEnabled\":false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.weeklyReportEmailEnabled").value(false));
    }

    @Test
    void update_missingValue_returns400() throws Exception {
        mockMvc.perform(put("/api/v1/trainer/preferences")
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }
}
