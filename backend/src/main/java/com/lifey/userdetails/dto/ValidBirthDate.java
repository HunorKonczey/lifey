package com.lifey.userdetails.dto;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.*;

/**
 * Birth date must be in the past and imply an age between 13 and 120 —
 * both the BMR formula and basic plausibility break down outside that range.
 */
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Constraint(validatedBy = BirthDateValidator.class)
public @interface ValidBirthDate {

    String message() default "must be a past date implying an age between 13 and 120";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
