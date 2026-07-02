package com.lifey.auth;

import com.lifey.auth.dto.AuthResponse;
import com.lifey.auth.dto.ChangePasswordRequest;
import com.lifey.auth.dto.ForgotPasswordRequest;
import com.lifey.auth.dto.LoginRequest;
import com.lifey.auth.dto.RefreshRequest;
import com.lifey.auth.dto.RegisterRequest;
import com.lifey.auth.dto.ResetPasswordRequest;
import com.lifey.auth.dto.UserResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Auth", description = "Registration, login, and refresh-token lifecycle")
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    /** httpOnly cookie carrying the refresh token for browser clients. */
    private static final String REFRESH_COOKIE = "refreshToken";
    private static final String COOKIE_PATH = "/api/v1/auth";

    private final AuthService authService;
    private final PasswordResetService passwordResetService;
    private final JwtProperties jwtProperties;
    private final boolean cookieSecure;
    private final String cookieSameSite;

    public AuthController(AuthService authService,
                          PasswordResetService passwordResetService,
                          JwtProperties jwtProperties,
                          @Value("${lifey.cookie.secure}") boolean cookieSecure,
                          @Value("${lifey.cookie.same-site}") String cookieSameSite) {
        this.authService = authService;
        this.passwordResetService = passwordResetService;
        this.jwtProperties = jwtProperties;
        this.cookieSecure = cookieSecure;
        this.cookieSameSite = cookieSameSite;
    }

    @Operation(summary = "Register a new account")
    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @Operation(summary = "Log in and receive an access/refresh token pair",
            description = "The refresh token is also set as an httpOnly cookie for browser clients; "
                    + "it remains in the body for mobile/native clients.")
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return withRefreshCookie(authService.login(request));
    }

    @Operation(summary = "Exchange a refresh token for a new access/refresh pair (rotation)",
            description = "Reads the refresh token from the httpOnly cookie (browser) or the request "
                    + "body (mobile). The new refresh token is rotated into the cookie.")
    @PostMapping("/refresh")
    public ResponseEntity<AuthResponse> refresh(
            @CookieValue(name = REFRESH_COOKIE, required = false) String cookieToken,
            @RequestBody(required = false) RefreshRequest body) {
        AuthResponse auth = authService.refresh(resolveToken(cookieToken, body));
        return withRefreshCookie(auth);
    }

    @Operation(summary = "Log out (revoke the given refresh token)")
    @PostMapping("/logout")
    public ResponseEntity<Void> logout(
            @CookieValue(name = REFRESH_COOKIE, required = false) String cookieToken,
            @RequestBody(required = false) RefreshRequest body) {
        authService.logout(resolveToken(cookieToken, body));
        return ResponseEntity.noContent()
                .header(HttpHeaders.SET_COOKIE, clearedRefreshCookie().toString())
                .build();
    }

    @Operation(summary = "Log out of every device (revoke all of the current user's refresh tokens)")
    @PostMapping("/logout-all")
    public ResponseEntity<Void> logoutAll() {
        authService.logoutAll();
        return ResponseEntity.noContent()
                .header(HttpHeaders.SET_COOKIE, clearedRefreshCookie().toString())
                .build();
    }

    @Operation(summary = "Request a password reset code by email",
            description = "Always returns 200 regardless of whether the email is registered, "
                    + "so this endpoint can't be used to enumerate accounts.")
    @PostMapping("/forgot-password")
    @ResponseStatus(HttpStatus.OK)
    public void forgotPassword(@Valid @RequestBody ForgotPasswordRequest request) {
        passwordResetService.forgotPassword(request.email());
    }

    @Operation(summary = "Reset a password using the emailed code")
    @PostMapping("/reset-password")
    @ResponseStatus(HttpStatus.OK)
    public void resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        passwordResetService.resetPassword(request.email(), request.code(), request.newPassword());
    }

    @Operation(summary = "Change the current user's password",
            description = "Revokes every refresh token for the user (including the one used for this "
                    + "request) and returns a fresh token pair, so the calling device stays logged in.")
    @PostMapping("/change-password")
    public ResponseEntity<AuthResponse> changePassword(@Valid @RequestBody ChangePasswordRequest request) {
        return withRefreshCookie(authService.changePassword(request));
    }

    // ─── helpers ───

    private String resolveToken(String cookieToken, RefreshRequest body) {
        if (cookieToken != null && !cookieToken.isBlank()) {
            return cookieToken;
        }
        if (body != null && body.refreshToken() != null && !body.refreshToken().isBlank()) {
            return body.refreshToken();
        }
        throw new InvalidTokenException("No refresh token provided (cookie or body)");
    }

    private ResponseEntity<AuthResponse> withRefreshCookie(AuthResponse auth) {
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, refreshCookie(auth.refreshToken()).toString())
                .body(auth);
    }

    private ResponseCookie refreshCookie(String token) {
        return ResponseCookie.from(REFRESH_COOKIE, token)
                .httpOnly(true)
                .secure(cookieSecure)
                .sameSite(cookieSameSite)
                .path(COOKIE_PATH)
                .maxAge(jwtProperties.refreshTokenTtl())
                .build();
    }

    private ResponseCookie clearedRefreshCookie() {
        return ResponseCookie.from(REFRESH_COOKIE, "")
                .httpOnly(true)
                .secure(cookieSecure)
                .sameSite(cookieSameSite)
                .path(COOKIE_PATH)
                .maxAge(0)
                .build();
    }
}
