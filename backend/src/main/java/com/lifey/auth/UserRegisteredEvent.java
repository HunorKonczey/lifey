package com.lifey.auth;

/**
 * Published after a new user row is saved. Carries just the id — listeners
 * that need the full entity (e.g. to send mail) re-fetch it themselves, since
 * this event may be handled after the publishing transaction commits, on a
 * fresh transaction (see {@link WelcomeEmailListener}).
 */
record UserRegisteredEvent(Long userId) {
}
