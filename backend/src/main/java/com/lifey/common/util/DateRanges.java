package com.lifey.common.util;

import java.time.LocalDate;
import java.time.Month;

/**
 * Sentinel bounds for optional {@code from}/{@code to} date-range filters
 * (weights, steps). Repositories compare with a plain {@code >=}/{@code <=}
 * rather than a {@code (:param is null or ...)} JPQL branch — that pattern
 * hits a Postgres parameter-type-inference bug ("could not determine data
 * type of parameter $n") once exactly one bound is non-null. Callers resolve
 * a missing bound to one of these constants instead of passing null.
 */
public final class DateRanges {

    private DateRanges() {
    }

    public static final LocalDate DISTANT_PAST = LocalDate.of(1900, Month.JANUARY, 1);
    public static final LocalDate DISTANT_FUTURE = LocalDate.of(2999, Month.DECEMBER, 31);
}
