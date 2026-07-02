package com.lifey.auth;

import com.lifey.auth.dto.AuthResponse;
import com.lifey.auth.dto.ChangePasswordRequest;
import com.lifey.auth.dto.LoginRequest;
import com.lifey.auth.dto.RegisterRequest;
import com.lifey.auth.dto.UserResponse;

public interface AuthService {

    UserResponse register(RegisterRequest request);

    AuthResponse login(LoginRequest request);

    /**
     * Verifies {@code currentPassword}, sets the new one, and revokes every refresh
     * token for the current user (resolved from the security context) — including
     * whichever one the caller is using. Returns a fresh token pair so the calling
     * device stays logged in without a full re-login.
     */
    AuthResponse changePassword(ChangePasswordRequest request);

    /** Validates {@code refreshToken}, revokes it, and issues a new access/refresh pair. */
    AuthResponse refresh(String refreshToken);

    /** Revokes a single refresh token (logout from the device that holds it). Idempotent. */
    void logout(String refreshToken);

    /** Revokes every live refresh token for the current user (logout from all devices). */
    void logoutAll();
}
