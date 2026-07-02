package com.lifey.auth;

import com.lifey.auth.dto.AuthResponse;
import com.lifey.auth.dto.UserResponse;
import com.lifey.auth.exception.*;
import com.lifey.auth.properties.JwtProperties;
import com.lifey.auth.service.AuthService;
import com.lifey.auth.service.PasswordResetService;
import com.lifey.auth.service.SocialAuthService;
import com.lifey.user.Role;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Duration;
import java.time.Instant;
import java.util.Set;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AuthController.class)
class AuthControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    AuthService authService;

    @MockitoBean
    SocialAuthService socialAuthService;

    @MockitoBean
    PasswordResetService passwordResetService;

    @MockitoBean
    JwtProperties jwtProperties;

    @Test
    void register_returnsCreated() throws Exception {
        when(authService.register(any()))
                .thenReturn(new UserResponse(1L, "user@example.com", Set.of(Role.ROLE_USER), Instant.now()));

        mockMvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"user@example.com\",\"password\":\"password123\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.email").value("user@example.com"));
    }

    @Test
    void register_invalidBodyReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"not-an-email\",\"password\":\"short\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        verify(authService, never()).register(any());
    }

    @Test
    void login_returnsTokenPair() throws Exception {
        when(authService.login(any()))
                .thenReturn(new AuthResponse("access-token", "refresh-token", 900L));
        when(jwtProperties.refreshTokenTtl()).thenReturn(Duration.ofDays(30));

        mockMvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"user@example.com\",\"password\":\"password123\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("access-token"))
                .andExpect(jsonPath("$.refreshToken").value("refresh-token"))
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresIn").value(900));
    }

    @Test
    void login_invalidCredentialsReturns401() throws Exception {
        when(authService.login(any())).thenThrow(new InvalidCredentialsException("Invalid email or password"));

        mockMvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"user@example.com\",\"password\":\"wrong-password\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void refresh_returnsNewTokenPair() throws Exception {
        when(authService.refresh("old-refresh-token"))
                .thenReturn(new AuthResponse("new-access-token", "new-refresh-token", 900L));
        when(jwtProperties.refreshTokenTtl()).thenReturn(Duration.ofDays(30));

        mockMvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"old-refresh-token\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("new-access-token"))
                .andExpect(jsonPath("$.refreshToken").value("new-refresh-token"));
    }

    @Test
    void refresh_revokedTokenReturns401() throws Exception {
        when(authService.refresh(eq("stolen-token")))
                .thenThrow(new TokenRevokedException("Refresh token has been revoked"));

        mockMvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"stolen-token\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logout_returnsNoContent() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"some-refresh-token\"}"))
                .andExpect(status().isNoContent());

        verify(authService).logout("some-refresh-token");
    }

    @Test
    void logoutAll_returnsNoContent() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout-all"))
                .andExpect(status().isNoContent());

        verify(authService).logoutAll();
    }

    @Test
    void forgotPassword_returnsOkRegardlessOfWhetherEmailExists() throws Exception {
        mockMvc.perform(post("/api/v1/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"unknown@example.com\"}"))
                .andExpect(status().isOk());

        verify(passwordResetService).forgotPassword("unknown@example.com");
    }

    @Test
    void resetPassword_validRequestReturnsOk() throws Exception {
        mockMvc.perform(post("/api/v1/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"user@example.com\",\"code\":\"123456\",\"newPassword\":\"newpassword123\"}"))
                .andExpect(status().isOk());

        verify(passwordResetService).resetPassword("user@example.com", "123456", "newpassword123");
    }

    @Test
    void resetPassword_invalidCodeReturns400() throws Exception {
        doThrow(new InvalidResetCodeException("Invalid or expired code"))
                .when(passwordResetService).resetPassword(any(), any(), any());

        mockMvc.perform(post("/api/v1/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"user@example.com\",\"code\":\"000000\",\"newPassword\":\"newpassword123\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void changePassword_success_returnsFreshTokenPair() throws Exception {
        when(authService.changePassword(any()))
                .thenReturn(new AuthResponse("new-access-token", "new-refresh-token", 900L));
        when(jwtProperties.refreshTokenTtl()).thenReturn(Duration.ofDays(30));

        mockMvc.perform(post("/api/v1/auth/change-password").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"old-password\",\"newPassword\":\"new-password-123\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("new-access-token"))
                .andExpect(jsonPath("$.refreshToken").value("new-refresh-token"));
    }

    @Test
    void changePassword_wrongCurrentPasswordReturns400() throws Exception {
        when(authService.changePassword(any()))
                .thenThrow(new IncorrectPasswordException("Current password is incorrect"));

        mockMvc.perform(post("/api/v1/auth/change-password").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"wrong-password\",\"newPassword\":\"new-password-123\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void changePassword_samePasswordReturns400() throws Exception {
        when(authService.changePassword(any()))
                .thenThrow(new SamePasswordException("New password must be different from the current password"));

        mockMvc.perform(post("/api/v1/auth/change-password").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"same-password\",\"newPassword\":\"same-password\"}"))
                .andExpect(status().isBadRequest());
    }
}
