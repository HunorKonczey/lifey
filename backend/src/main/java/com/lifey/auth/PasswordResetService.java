package com.lifey.auth;

public interface PasswordResetService {

    /**
     * Always succeeds from the caller's point of view — never reveals whether
     * {@code email} belongs to a registered account (see anti-enumeration rule
     * in docs/19-password-email-plan.md).
     */
    void forgotPassword(String email);

    /**
     * Validates the code and sets {@code newPassword} on success, revoking every
     * refresh token for the user. Throws {@link InvalidResetCodeException} with a
     * single generic message for every failure mode.
     */
    void resetPassword(String email, String code, String newPassword);
}
