package com.lifey.statistics;

import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.statistics.service.StatisticsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@Tag(name = "Statistics", description = "Aggregated totals over rolling periods")
@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/statistics")
public class StatisticsController {

    private final StatisticsService statisticsService;

    @Operation(summary = "Stats for today",
            description = "Pass `date` as the caller's own local date (yyyy-MM-dd) so the day "
                    + "boundary follows the caller's clock/timezone instead of the server's; "
                    + "omit it to use the server's current date.")
    @GetMapping("/daily")
    public StatisticsResponse daily(
            @Parameter(description = "Caller's local date; defaults to the server's current date")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return date != null ? statisticsService.daily(date) : statisticsService.daily();
    }

    @Operation(summary = "Stats for the last 7 days")
    @GetMapping("/weekly")
    public StatisticsResponse weekly(
            @Parameter(description = "Caller's local date; defaults to the server's current date")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return date != null ? statisticsService.weekly(date) : statisticsService.weekly();
    }

    @Operation(summary = "Stats for the last 30 days")
    @GetMapping("/monthly")
    public StatisticsResponse monthly(
            @Parameter(description = "Caller's local date; defaults to the server's current date")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return date != null ? statisticsService.monthly(date) : statisticsService.monthly();
    }
}
