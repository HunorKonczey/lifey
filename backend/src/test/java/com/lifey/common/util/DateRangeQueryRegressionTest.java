package com.lifey.common.util;

import com.lifey.steps.DailyStepCount;
import com.lifey.steps.DailyStepCountRepository;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.time.LocalDate;
import java.util.HashSet;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

/**
 * Regression test for a real bug: {@code WeightEntryRepository}/
 * {@code DailyStepCountRepository}'s date-range queries used to write the
 * optional {@code from}/{@code to} filter as {@code (:from is null or
 * field >= :from)}. That throws "could not determine data type of parameter
 * $n" against real Postgres whenever exactly one of the two bounds is
 * non-null — a plain {@code @Mock}-backed service test (see
 * WeightServiceImplTest/DailyStepCountServiceImplTest) never touches
 * Hibernate's SQL translation or the JDBC driver, so it can't catch this;
 * only a real DB round-trip can. This is exactly that round-trip, run against
 * the specific from-only/to-only combinations that used to 500 on the
 * trainer client-data endpoints (`GET /trainer/clients/{id}/weights|steps`)
 * and the client's own `GET /weights|steps`.
 */
@SpringBootTest
@Testcontainers
class DateRangeQueryRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WeightEntryRepository weightEntryRepository;

    @Autowired
    DailyStepCountRepository dailyStepCountRepository;

    Long userId;

    @BeforeEach
    void seedUser() {
        User user = new User();
        user.setEmail("date-range-regression-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(java.util.List.of(Role.ROLE_USER)));
        userId = userRepository.save(user).getId();

        WeightEntry weight = new WeightEntry();
        weight.setUser(user);
        weight.setDate(LocalDate.of(2026, 6, 15));
        weight.setRecordedAt(Instant.now());
        weight.setWeight(80.0);
        weightEntryRepository.save(weight);

        DailyStepCount steps = new DailyStepCount();
        steps.setUser(user);
        steps.setDate(LocalDate.of(2026, 6, 15));
        steps.setSteps(5000);
        dailyStepCountRepository.save(steps);
    }

    @Test
    void weightDateRange_fromOnly_doesNotThrow() {
        assertThatCode(() -> weightEntryRepository.findByUserIdAndDeletedAtIsNullAndDateRange(
                userId, LocalDate.of(2026, 6, 1), DateRanges.DISTANT_FUTURE))
                .doesNotThrowAnyException();

        var result = weightEntryRepository.findByUserIdAndDeletedAtIsNullAndDateRange(
                userId, LocalDate.of(2026, 6, 1), DateRanges.DISTANT_FUTURE);
        assertThat(result).hasSize(1);
    }

    @Test
    void weightDateRange_toOnly_doesNotThrow() {
        assertThatCode(() -> weightEntryRepository.findByUserIdAndDeletedAtIsNullAndDateRange(
                userId, DateRanges.DISTANT_PAST, LocalDate.of(2026, 12, 31)))
                .doesNotThrowAnyException();
    }

    @Test
    void stepsDateRange_fromOnly_doesNotThrow() {
        assertThatCode(() -> dailyStepCountRepository.findByUserIdAndDeletedAtIsNullAndDateRange(
                userId, LocalDate.of(2026, 6, 1), DateRanges.DISTANT_FUTURE))
                .doesNotThrowAnyException();

        var result = dailyStepCountRepository.findByUserIdAndDeletedAtIsNullAndDateRange(
                userId, LocalDate.of(2026, 6, 1), DateRanges.DISTANT_FUTURE);
        assertThat(result).hasSize(1);
    }

    @Test
    void stepsDateRange_toOnly_doesNotThrow() {
        assertThatCode(() -> dailyStepCountRepository.findByUserIdAndDeletedAtIsNullAndDateRange(
                userId, DateRanges.DISTANT_PAST, LocalDate.of(2026, 12, 31)))
                .doesNotThrowAnyException();
    }
}
