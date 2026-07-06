package com.lifey.auth.service;

import com.lifey.auth.dto.AuthResponse;

public interface SocialAuthService {

    /**
     * Verifies a Google ID token, then logs in, links, or creates the
     * matching user per the link/create algorithm in
     * docs/20-social-login-plan.md, and returns a fresh token pair.
     *
     * @param utcOffsetMinutes client-reported UTC offset in minutes, refreshed on every
     *                         login so existing users' stored offset stays current
     */
    AuthResponse loginWithGoogle(String idToken, Integer utcOffsetMinutes);
}
