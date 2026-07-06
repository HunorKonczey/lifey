package com.lifey.userdetails;

/**
 * Selects which {@link UserDetails} fields a partial update
 * ({@code PATCH /user-details}) should actually persist.
 */
public enum UserDetailsField {
    GENDER,
    BIRTH_DATE,
    HEIGHT_CM,
    ACTIVITY_LEVEL,
    PRIMARY_GOAL,
    TARGET_WEIGHT_KG
}
