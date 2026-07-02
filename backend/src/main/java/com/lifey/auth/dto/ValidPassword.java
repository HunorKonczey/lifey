package com.lifey.auth.dto;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.lang.annotation.*;

/**
 * Single source of truth for the password policy (currently just length),
 * composed from built-in Bean Validation constraints so registration,
 * reset-password, and change-password all reject the same passwords.
 */
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@NotBlank
@Size(min = 8, max = 100, message = "must be at least 8 characters")
@Constraint(validatedBy = {})
public @interface ValidPassword {

    String message() default "invalid password";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
