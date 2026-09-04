package com.lifey.billing.service;

import com.lifey.billing.entity.AiUsageCounter;
import com.lifey.billing.repository.AiUsageCounterRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** `64` Prompt 12 — the counter half of §3.4, {@link EntitlementServiceImplTest} covers how it feeds {@code aiCreditsRemaining}. */
@ExtendWith(MockitoExtension.class)
class AiUsageCounterServiceImplTest {

    private static final Long USER_ID = 1L;
    private static final Instant NOW = Instant.parse("2026-08-27T10:00:00Z");

    @Mock
    AiUsageCounterRepository repository;

    private AiUsageCounterServiceImpl service() {
        return new AiUsageCounterServiceImpl(repository, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void usedThisMonth_existingRow_returnsItsCount() {
        AiUsageCounter counter = new AiUsageCounter();
        counter.setUsedCount(3);
        when(repository.findByUserIdAndYearMonth(USER_ID, "2026-08")).thenReturn(Optional.of(counter));

        assertThat(service().usedThisMonth(USER_ID)).isEqualTo(3);
    }

    @Test
    void usedThisMonth_noRowYet_returnsZero() {
        when(repository.findByUserIdAndYearMonth(USER_ID, "2026-08")).thenReturn(Optional.empty());

        assertThat(service().usedThisMonth(USER_ID)).isZero();
    }

    @Test
    void recordUsage_incrementsTheCurrentCalendarMonth() {
        service().recordUsage(USER_ID);

        verify(repository).incrementUsage(USER_ID, "2026-08");
    }
}
