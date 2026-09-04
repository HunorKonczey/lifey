package com.lifey.billing.service;

import com.lifey.billing.entity.AiUsageCounter;
import com.lifey.billing.repository.AiUsageCounterRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.YearMonth;

/**
 * Not yet wired into an actual AI call: docs/23-ai-calorie-estimation-plan.md's
 * meal-estimation feature (the intended caller, via its {@code AiFeatureGate})
 * doesn't exist in this codebase yet. This is the counter half of `64` Prompt
 * 12 — {@link #usedThisMonth} already feeds {@code EntitlementServiceImpl}'s
 * {@code aiCreditsRemaining}, and {@link #recordUsage} is ready for that
 * feature's gate to call once it lands.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class AiUsageCounterServiceImpl implements AiUsageCounterService {

    private final AiUsageCounterRepository repository;
    private final Clock clock;

    @Override
    @Transactional(readOnly = true)
    public int usedThisMonth(Long userId) {
        return repository.findByUserIdAndYearMonth(userId, currentYearMonth())
                .map(AiUsageCounter::getUsedCount)
                .orElse(0);
    }

    @Override
    public void recordUsage(Long userId) {
        repository.incrementUsage(userId, currentYearMonth());
    }

    private String currentYearMonth() {
        return YearMonth.now(clock).toString();
    }
}
