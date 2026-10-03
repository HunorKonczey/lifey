package com.lifey.auth;

import com.lifey.auth.service.JwtService;
import com.lifey.user.Role;
import com.lifey.user.UserActivityTracker;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Set;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** What the JWT filter hands to the activity tracker (docs/redesign-web/82 section 2.3). */
@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterActivityTest {

    @Mock
    JwtService jwtService;

    @Mock
    UserActivityTracker tracker;

    @Mock
    FilterChain chain;

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private JwtAuthenticationFilter filter() {
        return new JwtAuthenticationFilter(jwtService, tracker);
    }

    private MockHttpServletRequest bearer(String token) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("Authorization", "Bearer " + token);
        return request;
    }

    @Test
    void anAuthenticatedRequestStampsTheUsersActivity() throws Exception {
        Claims claims = mock(Claims.class);
        when(claims.get("email", String.class)).thenReturn("a@example.com");
        when(jwtService.parseAccessToken("good")).thenReturn(claims);
        when(jwtService.extractUserId(claims)).thenReturn(42L);
        when(jwtService.extractRoles(claims)).thenReturn(Set.of(Role.ROLE_USER));

        filter().doFilter(bearer("good"), new MockHttpServletResponse(), chain);

        verify(tracker).touch(42L);
        verify(chain).doFilter(any(), any());
    }

    @Test
    void aRejectedTokenStampsNothing_andTheRequestStillContinues() throws Exception {
        when(jwtService.parseAccessToken("bad")).thenThrow(new JwtException("expired"));

        filter().doFilter(bearer("bad"), new MockHttpServletResponse(), chain);

        verify(tracker, never()).touch(anyLong());
        verify(chain).doFilter(any(), any());
    }

    @Test
    void aRequestWithoutATokenStampsNothing() throws Exception {
        filter().doFilter(new MockHttpServletRequest(), new MockHttpServletResponse(), chain);

        verify(tracker, never()).touch(anyLong());
        verify(chain).doFilter(any(), any());
    }
}
