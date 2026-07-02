package com.lifey.userdetails.dto;

import com.lifey.userdetails.ActivityLevel;
import com.lifey.userdetails.Gender;
import com.lifey.userdetails.PrimaryGoal;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record UserDetailsRequest(

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
