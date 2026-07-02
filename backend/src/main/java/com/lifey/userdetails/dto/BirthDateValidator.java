package com.lifey.userdetails.dto;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.time.LocalDate;
import java.time.Period;

class BirthDateValidator implements ConstraintValidator<ValidBirthDate, LocalDate> {

    private static final int MIN_AGE = 13;
    private static final int MAX_AGE = 120;

    @Override
    public boolean isValid(LocalDate birthDate, ConstraintValidatorContext context) {
        if (birthDate == null) {
            return true; // let @NotNull report the missing-value case
        }
        LocalDate today = LocalDate.now();
        if (!birthDate.isBefore(today)) {
            return false;
        }
        int age = Period.between(birthDate, today).getYears();
        return age >= MIN_AGE && age <= MAX_AGE;
    }
}
