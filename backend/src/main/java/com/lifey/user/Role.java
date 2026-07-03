package com.lifey.user;

/**
 * Application roles. New roles can be added here without touching the
 * persistence mapping ({@link User#getRoles()} is a plain string-backed set).
 */
public enum Role {
    ROLE_USER,
    ROLE_ADMIN,
    ROLE_TRAINER,
    /**
     * Bootstrapped once by hand via direct SQL (see V43__role_audit_log.sql) —
     * never granted or revoked through the API. Still needs to exist here so
     * {@code JwtService}/{@code Role.valueOf} can round-trip it through the
     * token's {@code roles} claim for whichever account holds it.
     */
    ROLE_SUPER_ADMIN
}
