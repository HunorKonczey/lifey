package com.lifey.common.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;

import java.time.LocalDate;
import java.time.ZoneOffset;

public class NotFutureDateValidator implements ConstraintValidator<NotFutureDate, LocalDate> {

    @Override
    public boolean isValid(LocalDate date, ConstraintValidatorContext context) {
        if (date == null) {
            return true; // let @NotNull report the missing-value case
        }
        LocalDate utcToday = LocalDate.now(context.getClockProvider().getClock().withZone(ZoneOffset.UTC));
        return !date.isAfter(utcToday.plusDays(1));
    }
}
