package com.lifey.userdetails;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import com.lifey.userdetails.dto.UserDetailsResponse;
import com.lifey.userdetails.service.UserDetailsService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.time.LocalDate;
import java.time.Month;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(UserDetailsController.class)
class UserDetailsControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    UserDetailsService userDetailsService;

    @Test
    void get_notOnboardedReturns404() throws Exception {
        when(userDetailsService.get()).thenThrow(new ResourceNotFoundException("User has not completed onboarding"));

        mockMvc.perform(get("/api/v1/user-details"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void get_returnsOk() throws Exception {
        when(userDetailsService.get()).thenReturn(new UserDetailsResponse(
                Gender.MALE, LocalDate.of(1990, Month.JANUARY, 1), 180.0, ActivityLevel.MODERATE, PrimaryGoal.MAINTAIN,
                null, Instant.parse("2026-06-18T08:00:00Z"), Instant.parse("2026-06-18T08:00:00Z")));

        mockMvc.perform(get("/api/v1/user-details"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.gender").value("MALE"))
                .andExpect(jsonPath("$.heightCm").value(180.0));
    }

    @Test
    void update_invalidHeightReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/user-details").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "gender": "MALE",
                                  "birthDate": "1990-01-01",
                                  "heightCm": 10.0,
                                  "activityLevel": "MODERATE",
                                  "primaryGoal": "MAINTAIN"
                                }
                                """))
                .andExpect(status().isBadRequest());

        verify(userDetailsService, never()).upsert(any());
    }

    @Test
    void update_underageBirthDateReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/user-details").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "gender": "MALE",
                                  "birthDate": "%s",
                                  "heightCm": 170.0,
                                  "activityLevel": "MODERATE",
                                  "primaryGoal": "MAINTAIN"
                                }
                                """.formatted(LocalDate.now().minusYears(10))))
                .andExpect(status().isBadRequest());

        verify(userDetailsService, never()).upsert(any());
    }

    @Test
    void update_validRequestReturnsOk() throws Exception {
        when(userDetailsService.upsert(any())).thenReturn(new UserDetailsResponse(
                Gender.FEMALE, LocalDate.of(1995, Month.MAY, 1), 165.0, ActivityLevel.LIGHT, PrimaryGoal.LOSE_WEIGHT,
                60.0, Instant.parse("2026-06-18T08:00:00Z"), Instant.parse("2026-06-18T08:00:00Z")));

        mockMvc.perform(put("/api/v1/user-details").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "gender": "FEMALE",
                                  "birthDate": "1995-05-01",
                                  "heightCm": 165.0,
                                  "activityLevel": "LIGHT",
                                  "primaryGoal": "LOSE_WEIGHT",
                                  "targetWeightKg": 60.0
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.gender").value("FEMALE"));
    }

    @Test
    void partialUpdate_emptyFieldsReturns400() throws Exception {
        mockMvc.perform(patch("/api/v1/user-details").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fields": [],
                                  "gender": "MALE",
                                  "birthDate": "1990-01-01",
                                  "heightCm": 180.0,
                                  "activityLevel": "MODERATE",
                                  "primaryGoal": "MAINTAIN"
                                }
                                """))
                .andExpect(status().isBadRequest());

        verify(userDetailsService, never()).partialUpdate(any());
    }

    @Test
    void partialUpdate_validRequestReturnsOk() throws Exception {
        when(userDetailsService.partialUpdate(any())).thenReturn(new UserDetailsResponse(
                Gender.MALE, LocalDate.of(1990, Month.JANUARY, 1), 182.0, ActivityLevel.MODERATE, PrimaryGoal.MAINTAIN,
                null, Instant.parse("2026-06-18T08:00:00Z"), Instant.parse("2026-06-18T08:00:00Z")));

        mockMvc.perform(patch("/api/v1/user-details").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "fields": ["HEIGHT_CM"],
                                  "gender": "MALE",
                                  "birthDate": "1990-01-01",
                                  "heightCm": 182.0,
                                  "activityLevel": "MODERATE",
                                  "primaryGoal": "MAINTAIN"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.heightCm").value(182.0));
    }

    @Test
    void suggestGoals_returnsComputedValues() throws Exception {
        when(userDetailsService.suggestGoals(any())).thenReturn(
                new SuggestGoalsResponse(1780, 2759, 2350, 176, 265, 65, 3.1));

        mockMvc.perform(post("/api/v1/user-details/suggest-goals").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "gender": "MALE",
                                  "birthDate": "1996-01-01",
                                  "heightCm": 180.0,
                                  "weightKg": 80.0,
                                  "activityLevel": "MODERATE",
                                  "primaryGoal": "LOSE_WEIGHT"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.calories").value(2350))
                .andExpect(jsonPath("$.proteinGrams").value(176))
                .andExpect(jsonPath("$.waterLiters").value(3.1));
    }

    @Test
    void suggestGoals_missingFieldReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/user-details/suggest-goals").contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());

        verify(userDetailsService, never()).suggestGoals(any());
    }
}
