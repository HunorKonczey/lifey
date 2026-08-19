package com.lifey.workout.session.cardio;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.SessionKind;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.PersistenceException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.function.Supplier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V71__cardio_hike_fields.sql's {@code cardio_details} half — backpack
 * weight, GAP, and the manual weather snapshot (docs/cardio/60 C8.1,
 * Q-C8.1). Runs against a real Postgres so the CHECK constraints are
 * actually exercised, not just assumed from the SQL text. Unlike V66/V70,
 * there's no separate raw-SQL migration test here: every new column is a
 * plain nullable addition with no default-value or legacy-row story to
 * check beyond what persisting through JPA already proves.
 */
@SpringBootTest
@Testcontainers
class CardioHikeFieldsTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    WorkoutSessionRepository workoutSessionRepository;

    @PersistenceContext
    EntityManager entityManager;

    @Autowired
    PlatformTransactionManager transactionManager;

    TransactionTemplate txTemplate;
    WorkoutSession hikeSession;

    @BeforeEach
    void seedHikeSession() {
        txTemplate = new TransactionTemplate(transactionManager);

        User user = new User();
        user.setEmail("cardio-hike-fields-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userRepository.save(user);

        WorkoutSession session = new WorkoutSession();
        session.setUser(user);
        session.setStartedAt(Instant.now());
        session.setSessionKind(SessionKind.CARDIO);
        session.setActivityType(ActivityType.HIKING);
        hikeSession = workoutSessionRepository.save(session);
    }

    private void inTransaction(Runnable action) {
        txTemplate.executeWithoutResult(_ -> action.run());
    }

    private <T> T inTransaction(Supplier<T> action) {
        return txTemplate.execute(_ -> action.get());
    }

    private CardioDetails newDetails() {
        CardioDetails details = new CardioDetails();
        details.setWorkoutSession(hikeSession);
        return details;
    }

    @Test
    void persistsAndReadsBackTheFullHikeFieldSet() {
        CardioDetails details = newDetails();
        details.setBackpackWeightKg(8.5);
        details.setAvgGapSecondsPerKm(842.0);
        details.setWeatherTempC(7.0);
        details.setWeatherWindKph(12.0);
        details.setWeatherPrecipMm(0.0);
        details.setWeatherCondition("PARTLY_CLOUDY");

        inTransaction(() -> entityManager.persist(details));
        entityManager.clear();

        CardioDetails reloaded = inTransaction(() -> entityManager.find(CardioDetails.class, details.getId()));
        assertThat(reloaded.getBackpackWeightKg()).isEqualTo(8.5);
        assertThat(reloaded.getAvgGapSecondsPerKm()).isEqualTo(842.0);
        assertThat(reloaded.getWeatherTempC()).isEqualTo(7.0);
        assertThat(reloaded.getWeatherWindKph()).isEqualTo(12.0);
        assertThat(reloaded.getWeatherPrecipMm()).isEqualTo(0.0);
        assertThat(reloaded.getWeatherCondition()).isEqualTo("PARTLY_CLOUDY");
    }

    @Test
    void everyHikeFieldIsNullableForAFreshlyLoggedSession() {
        CardioDetails details = newDetails();

        inTransaction(() -> entityManager.persist(details));

        assertThat(details.getId()).isNotNull();
    }

    @Test
    void subZeroTemperatureIsAcceptedUnconstrained() {
        // Winter hikes are the whole reason a signed field, not PositiveOrZero.
        CardioDetails details = newDetails();
        details.setWeatherTempC(-14.5);

        inTransaction(() -> entityManager.persist(details));

        assertThat(details.getId()).isNotNull();
    }

    @Test
    void aNegativeBackpackWeightViolatesTheCheckConstraint() {
        CardioDetails details = newDetails();
        details.setBackpackWeightKg(-1.0);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_backpack_weight_nonneg_ck");
    }

    @Test
    void aNegativeGapViolatesTheCheckConstraint() {
        CardioDetails details = newDetails();
        details.setAvgGapSecondsPerKm(-1.0);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_gap_nonneg_ck");
    }

    @Test
    void aNegativeWindSpeedViolatesTheCheckConstraint() {
        CardioDetails details = newDetails();
        details.setWeatherWindKph(-1.0);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_weather_wind_nonneg_ck");
    }

    @Test
    void aNegativePrecipitationViolatesTheCheckConstraint() {
        CardioDetails details = newDetails();
        details.setWeatherPrecipMm(-1.0);

        assertThatThrownBy(() -> inTransaction(() -> entityManager.persist(details)))
                .isInstanceOf(PersistenceException.class)
                .hasStackTraceContaining("cardio_details_weather_precip_nonneg_ck");
    }

    @Test
    void anyWeatherConditionCodeIsAcceptedUnconstrained() {
        // No DB CHECK on weather_condition — same precedent as game_format/
        // distance_source, since it drives display only (see the migration's
        // own comment). A made-up code must not be rejected at the DB layer.
        CardioDetails details = newDetails();
        details.setWeatherCondition("MADE_UP_CODE");

        inTransaction(() -> entityManager.persist(details));

        assertThat(details.getId()).isNotNull();
    }
}
