package com.lifey.trainer;

import com.lifey.settings.service.SettingsService;
import com.lifey.trainer.controller.TrainerPreferencesController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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
    void get_returnsCurrentPreferences() throws Exception {
        when(settingsService.isWeeklyReportEmailEnabled()).thenReturn(true);
        when(settingsService.isClientMissedWorkoutPushEnabled()).thenReturn(false);
        when(settingsService.isClientWeighInPushEnabled()).thenReturn(true);

        mockMvc.perform(get("/api/v1/trainer/preferences"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.weeklyReportEmailEnabled").value(true))
                .andExpect(jsonPath("$.clientMissedWorkoutPushEnabled").value(false))
                .andExpect(jsonPath("$.clientWeighInPushEnabled").value(true));
    }

    @Test
    void update_flipsOnlyWhatWasSent_andReturnsAllThree() throws Exception {
        when(settingsService.isWeeklyReportEmailEnabled()).thenReturn(false);
        when(settingsService.isClientMissedWorkoutPushEnabled()).thenReturn(true);
        when(settingsService.isClientWeighInPushEnabled()).thenReturn(true);

        mockMvc.perform(put("/api/v1/trainer/preferences")
                        .contentType(APPLICATION_JSON)
                        .content("{\"weeklyReportEmailEnabled\":false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.weeklyReportEmailEnabled").value(false))
                .andExpect(jsonPath("$.clientMissedWorkoutPushEnabled").value(true));

        verify(settingsService).setWeeklyReportEmailEnabled(false);
        // Absent keeps the stored value: an older client that only knows the first switch must not reset the others.
        verify(settingsService, never()).setClientMissedWorkoutPushEnabled(org.mockito.ArgumentMatchers.anyBoolean());
        verify(settingsService, never()).setClientWeighInPushEnabled(org.mockito.ArgumentMatchers.anyBoolean());
    }

    @Test
    void update_theClientPushSwitches() throws Exception {
        when(settingsService.isWeeklyReportEmailEnabled()).thenReturn(true);
        when(settingsService.isClientMissedWorkoutPushEnabled()).thenReturn(false);
        when(settingsService.isClientWeighInPushEnabled()).thenReturn(false);

        mockMvc.perform(put("/api/v1/trainer/preferences")
                        .contentType(APPLICATION_JSON)
                        .content("{\"clientMissedWorkoutPushEnabled\":false,\"clientWeighInPushEnabled\":false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.clientMissedWorkoutPushEnabled").value(false))
                .andExpect(jsonPath("$.clientWeighInPushEnabled").value(false));

        verify(settingsService).setClientMissedWorkoutPushEnabled(false);
        verify(settingsService).setClientWeighInPushEnabled(false);
        verify(settingsService, never()).setWeeklyReportEmailEnabled(org.mockito.ArgumentMatchers.anyBoolean());
    }
}
