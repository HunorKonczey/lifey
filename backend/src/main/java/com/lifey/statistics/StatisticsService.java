package com.lifey.statistics;

import com.lifey.statistics.dto.StatisticsResponse;

public interface StatisticsService {

    StatisticsResponse daily();

    StatisticsResponse weekly();

    StatisticsResponse monthly();
}
