package com.lifey.common.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * A calendar date the client says is "today or earlier" — on <em>its own</em> clock.
 *
 * <p>{@code @PastOrPresent} on a {@code LocalDate} compares with the server's date, which is
 * yesterday's for a user ahead of UTC during the first hours of their day: a weigh-in logged at
 * 00:30 in Budapest was rejected with a 400 (and, queued offline, parked as a failed sync for good).
 * No timezone is more than a day ahead of UTC, so this accepts everything up to tomorrow's UTC date
 * and still rejects a date that is really in the future.
 */
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Constraint(validatedBy = NotFutureDateValidator.class)
public @interface NotFutureDate {

    String message() default "must not be in the future";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
