package com.lifey.settings;

import com.lifey.settings.dto.SettingsResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(SettingsController.class)
class SettingsControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    SettingsService settingsService;

    @Test
    void get_returnsLanguageDefaultingToSystem() throws Exception {
        when(settingsService.get())
                .thenReturn(new SettingsResponse(UnitSystem.METRIC, null, null, null, null, null, null,
                        ThemePreference.SYSTEM, LanguagePreference.SYSTEM));

        mockMvc.perform(get("/api/v1/settings"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.language").value("SYSTEM"));
    }

    @Test
    void update_withHungarianReturnsIt() throws Exception {
        when(settingsService.update(any()))
                .thenReturn(new SettingsResponse(UnitSystem.METRIC, null, null, null, null, null, null,
                        ThemePreference.SYSTEM, LanguagePreference.HUNGARIAN));

        mockMvc.perform(put("/api/v1/settings").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"unitSystem":"METRIC","theme":"SYSTEM","language":"HUNGARIAN"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.language").value("HUNGARIAN"));
    }

    @Test
    void update_missingLanguageReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/settings").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"unitSystem":"METRIC","theme":"SYSTEM"}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void update_withDailyStepGoalReturnsIt() throws Exception {
        when(settingsService.update(any()))
                .thenReturn(new SettingsResponse(UnitSystem.METRIC, null, null, null, null, null, 10000,
                        ThemePreference.SYSTEM, LanguagePreference.SYSTEM));

        mockMvc.perform(put("/api/v1/settings").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"unitSystem":"METRIC","theme":"SYSTEM","language":"SYSTEM","dailyStepGoal":10000}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dailyStepGoal").value(10000));
    }

    @Test
    void update_zeroDailyStepGoalReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/settings").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"unitSystem":"METRIC","theme":"SYSTEM","language":"SYSTEM","dailyStepGoal":0}
                                """))
                .andExpect(status().isBadRequest());

        verify(settingsService, never()).update(any());
    }
}
