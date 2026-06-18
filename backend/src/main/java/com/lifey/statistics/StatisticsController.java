package com.lifey.statistics;

import com.lifey.statistics.dto.StatisticsResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Statistics", description = "Aggregated totals over rolling periods")
@RestController
@RequestMapping("/api/v1/statistics")
public class StatisticsController {

    private final StatisticsService statisticsService;

    public StatisticsController(StatisticsService statisticsService) {
        this.statisticsService = statisticsService;
    }

    @Operation(summary = "Stats for today")
    @GetMapping("/daily")
    public StatisticsResponse daily() {
        return statisticsService.daily();
    }

    @Operation(summary = "Stats for the last 7 days")
    @GetMapping("/weekly")
    public StatisticsResponse weekly() {
        return statisticsService.weekly();
    }

    @Operation(summary = "Stats for the last 30 days")
    @GetMapping("/monthly")
    public StatisticsResponse monthly() {
        return statisticsService.monthly();
    }
}
