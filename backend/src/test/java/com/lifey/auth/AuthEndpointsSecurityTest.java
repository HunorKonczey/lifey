package com.lifey.auth;

import com.lifey.auth.service.AuthService;
import com.lifey.auth.service.JwtService;
import com.lifey.auth.service.PasswordResetService;
import com.lifey.auth.service.SocialAuthService;
import com.lifey.common.config.WebCorsConfig;
import com.lifey.user.UserActivityTracker;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The auth endpoints through the real filter chain ({@link SecurityConfig}), which every other controller
 * test skips by being a slice. Logout is authorised by the refresh token in its own body, and both clients
 * call it after clearing their access token: if the chain demanded a bearer, every logout answered 401 and
 * no refresh token was ever revoked on the server.
 */
@WebMvcTest(AuthController.class)
@Import({SecurityConfig.class, JwtService.class, JwtAuthenticationEntryPoint.class, JwtAccessDeniedHandler.class,
        WebCorsConfig.class, AuthEndpointsSecurityTest.Beans.class})
@TestPropertySource(properties = {
        "lifey.jwt.secret=test-secret-test-secret-test-secret-test-secret-1234",
        "lifey.jwt.access-token-ttl=15m",
        "lifey.jwt.refresh-token-ttl=30d",
        "lifey.jwt.issuer=lifey-api",
        "lifey.cors.allowed-origins=http://localhost:3000",
        "lifey.google.client-ids=x"
})
class AuthEndpointsSecurityTest {

    @TestConfiguration
    @EnableWebSecurity
    static class Beans {
        @Bean
        UserDetailsService userDetailsService() {
            return username -> {
                throw new org.springframework.security.core.userdetails.UsernameNotFoundException(username);
            };
        }
    }

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    AuthService authService;

    @MockitoBean
    SocialAuthService socialAuthService;

    @MockitoBean
    PasswordResetService passwordResetService;

    @MockitoBean
    UserActivityTracker activityTracker;

    @Test
    void logout_withoutAnAccessToken_revokesTheRefreshToken() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"the-refresh-token\"}"))
                .andExpect(status().isNoContent());

        verify(authService).logout("the-refresh-token");
    }

    @Test
    void logoutAll_stillNeedsAnAccessToken() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout-all")).andExpect(status().isUnauthorized());
    }

    @Test
    void changePassword_stillNeedsAnAccessToken() throws Exception {
        mockMvc.perform(post("/api/v1/auth/change-password").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"a\",\"newPassword\":\"b\"}"))
                .andExpect(status().isUnauthorized());
    }
}
