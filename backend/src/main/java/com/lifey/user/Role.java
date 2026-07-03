package com.lifey.user;

/**
 * Application roles. New roles can be added here without touching the
 * persistence mapping ({@link User#getRoles()} is a plain string-backed set).
 */
public enum Role {
    ROLE_USER,
    ROLE_ADMIN,
    ROLE_TRAINER
}
