package com.lifey.userdetails.dto;

import com.lifey.userdetails.ActivityLevel;
import com.lifey.userdetails.Gender;
import com.lifey.userdetails.PrimaryGoal;

import java.time.Instant;
import java.time.LocalDate;

public record UserDetailsResponse(
        Gender gender,
        LocalDate birthDate,
        Double heightCm,
        ActivityLevel activityLevel,
        PrimaryGoal primaryGoal,
        Double targetWeightKg,
        Instant onboardingCompletedAt,
        Instant updatedAt
) {
}
