package com.lifey.auth.service;

import com.lifey.auth.dto.*;

public interface AuthService {

    /**
     * @param utcOffsetMinutes client-reported UTC offset in minutes (see
     *                         {@code User#utcOffsetMinutes}), or {@code null} if not sent
     */
    UserResponse register(RegisterRequest request, Integer utcOffsetMinutes);

    /**
     * @param utcOffsetMinutes client-reported UTC offset in minutes, refreshed on every
     *                         login so existing users' stored offset stays current
     */
    AuthResponse login(LoginRequest request, Integer utcOffsetMinutes);

    /**
     * Verifies {@code currentPassword}, sets the new one, and revokes every refresh
     * token for the current user (resolved from the security context) — including
     * whichever one the caller is using. Returns a fresh token pair so the calling
     * device stays logged in without a full re-login.
     */
    AuthResponse changePassword(ChangePasswordRequest request);

    /**
     * Validates {@code refreshToken}, revokes it, and issues a new access/refresh pair.
     *
     * @param utcOffsetMinutes client-reported UTC offset in minutes, refreshed on every
     *                         token refresh — the main mechanism by which existing users'
     *                         stored offset gets corrected without re-logging in
     */
    AuthResponse refresh(String refreshToken, Integer utcOffsetMinutes);

    /**
     * Revokes a single refresh token (logout from the device that holds it). Idempotent.
     */
    void logout(String refreshToken);

    /**
     * Revokes every live refresh token for the current user (logout from all devices).
     */
    void logoutAll();
}
