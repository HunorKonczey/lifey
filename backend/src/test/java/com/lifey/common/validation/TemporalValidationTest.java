package com.lifey.common.validation;

import com.lifey.bodymeasurement.MeasurementSite;
import com.lifey.bodymeasurement.dto.BodyMeasurementRequest;
import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.weight.dto.WeightRequest;
import com.lifey.workout.session.dto.ExerciseSetRequest;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * What a client's own clock may say without being refused: a date that is "today" where the user
 * lives (up to a day ahead of the server's UTC date), and an instant a few seconds ahead of the
 * server's clock. Built through the default provider, so {@code META-INF/validation.xml} (the
 * temporal tolerance) is in play exactly as in the running application.
 */
class TemporalValidationTest {

    private static ValidatorFactory factory;
    private static Validator validator;

    @BeforeAll
    static void setUp() {
        factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @AfterAll
    static void tearDown() {
        factory.close();
    }

    private static LocalDate utcToday() {
        return LocalDate.now(ZoneOffset.UTC);
    }

    @Test
    void aWeighInDatedTomorrowInUtcIsTodayForAUserAheadOfUtc() {
        assertThat(validator.validate(new WeightRequest(utcToday().plusDays(1), 80.0))).isEmpty();
    }

    @Test
    void aWeighInTwoDaysAheadIsStillRejected() {
        assertThat(validator.validate(new WeightRequest(utcToday().plusDays(2), 80.0))).hasSize(1);
    }

    @Test
    void anOrdinaryPastWeighInPasses() {
        assertThat(validator.validate(new WeightRequest(utcToday().minusDays(30), 80.0))).isEmpty();
    }

    @Test
    void aMeasurementDatedTomorrowInUtcPasses_andTwoDaysAheadDoesNot() {
        assertThat(validator.validate(new BodyMeasurementRequest(utcToday().plusDays(1), MeasurementSite.WAIST, 80.0)))
                .isEmpty();
        assertThat(validator.validate(new BodyMeasurementRequest(utcToday().plusDays(2), MeasurementSite.WAIST, 80.0)))
                .hasSize(1);
    }

    @Test
    void aPhoneClockASecondsAheadOfTheServerIsNotRefused() {
        Instant slightlyAhead = Instant.now().plus(60, ChronoUnit.SECONDS);

        assertThat(validator.validate(new ExerciseSetRequest(1L, 10, 60.0, slightlyAhead))).isEmpty();
        assertThat(validator.validate(new WaterEntryRequest(slightlyAhead, null, 0.5))).isEmpty();
    }

    @Test
    void aTimestampAnHourAheadIsStillRefused() {
        Instant farAhead = Instant.now().plus(1, ChronoUnit.HOURS);

        assertThat(validator.validate(new ExerciseSetRequest(1L, 10, 60.0, farAhead))).hasSize(1);
        assertThat(validator.validate(new WaterEntryRequest(farAhead, null, 0.5))).hasSize(1);
    }
}
