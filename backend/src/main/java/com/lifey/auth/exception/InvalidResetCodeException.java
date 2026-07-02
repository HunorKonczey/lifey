package com.lifey.auth.exception;

/**
 * Thrown for every password-reset-code failure mode (unknown email, no active
 * code, expired, wrong code, attempts exhausted). Deliberately a single type
 * with a single generic message — see docs/19-password-email-plan.md,
 * distinguishing failure modes would let an attacker enumerate registered
 * emails or brute-force codes with feedback.
 */
public class InvalidResetCodeException extends RuntimeException {

    public InvalidResetCodeException(String message) {
        super(message);
    }
}
