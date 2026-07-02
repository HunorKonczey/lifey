package com.lifey.statistics;

import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.statistics.service.StatisticsService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(StatisticsController.class)
class StatisticsControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    StatisticsService statisticsService;

    @Test
    void daily_returnsOk() throws Exception {
        when(statisticsService.daily())
                .thenReturn(new StatisticsResponse(200.0, 20.0, 30.0, 10.0, 1, 78.4, 1.5));

        mockMvc.perform(get("/api/v1/statistics/daily"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCalories").value(200.0))
                .andExpect(jsonPath("$.totalProtein").value(20.0))
                .andExpect(jsonPath("$.totalCarbs").value(30.0))
                .andExpect(jsonPath("$.totalFat").value(10.0))
                .andExpect(jsonPath("$.workoutCount").value(1))
                .andExpect(jsonPath("$.latestWeight").value(78.4))
                .andExpect(jsonPath("$.totalWater").value(1.5));
    }

    @Test
    void weekly_returnsOk() throws Exception {
        when(statisticsService.weekly())
                .thenReturn(new StatisticsResponse(400.0, 40.0, 60.0, 20.0, 3, null, 0.0));

        mockMvc.perform(get("/api/v1/statistics/weekly"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCalories").value(400.0))
                .andExpect(jsonPath("$.latestWeight").doesNotExist());
    }

    @Test
    void monthly_returnsOk() throws Exception {
        when(statisticsService.monthly())
                .thenReturn(new StatisticsResponse(1000.0, 100.0, 150.0, 50.0, 12, 77.0, 5.0));

        mockMvc.perform(get("/api/v1/statistics/monthly"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.workoutCount").value(12));
    }
}
