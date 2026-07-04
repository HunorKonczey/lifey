package com.lifey.userdetails.dto;

import com.lifey.userdetails.ActivityLevel;
import com.lifey.userdetails.Gender;
import com.lifey.userdetails.PrimaryGoal;
import com.lifey.userdetails.UserDetailsField;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.Set;

/**
 * Partial update for {@code PATCH /user-details}. The client always sends its
 * full, already-valid current form state — {@code fields} says which of those
 * values should actually be persisted; the rest are ignored and the entity
 * keeps its existing value for them.
 */
public record UserDetailsPatchRequest(

        @NotEmpty
        Set<UserDetailsField> fields,

        @NotNull
        Gender gender,

        @NotNull
        @ValidBirthDate
        LocalDate birthDate,

        @NotNull
        @DecimalMin(value = "80.0", message = "must be at least 80 cm")
        @DecimalMax(value = "250.0", message = "must be at most 250 cm")
        Double heightCm,

        @NotNull
        ActivityLevel activityLevel,

        @NotNull
        PrimaryGoal primaryGoal,

        @DecimalMin(value = "30.0", message = "must be at least 30 kg")
        @DecimalMax(value = "300.0", message = "must be at most 300 kg")
        Double targetWeightKg
) {
}
