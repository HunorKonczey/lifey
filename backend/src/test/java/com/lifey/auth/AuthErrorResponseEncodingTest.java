package com.lifey.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The auth filter chain writes its JSON error bodies by hand, before any controller advice or message
 * converter runs. A charset-less {@code application/json} made the servlet writer fall back to ISO-8859-1,
 * so a message with an accented character reached the client as mojibake and without a charset to decode it.
 */
class AuthErrorResponseEncodingTest {

    private final ObjectMapper objectMapper = JsonMapper.builder().findAndAddModules().build();

    @Test
    void authenticationEntryPointWritesUtf8() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/weights");
        request.setAttribute(JwtAuthenticationFilter.AUTH_ERROR_ATTRIBUTE, new RuntimeException("Lejárt token — Ő"));
        MockHttpServletResponse response = new MockHttpServletResponse();

        new JwtAuthenticationEntryPoint(objectMapper).commence(request, response, new BadCredentialsException("x"));

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getContentType()).containsIgnoringCase("charset=UTF-8");
        assertThat(new String(response.getContentAsByteArray(), StandardCharsets.UTF_8)).contains("Lejárt token — Ő");
    }

    @Test
    void accessDeniedHandlerWritesUtf8() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/admin");
        MockHttpServletResponse response = new MockHttpServletResponse();

        new JwtAccessDeniedHandler(objectMapper).handle(request, response, new AccessDeniedException("x"));

        assertThat(response.getStatus()).isEqualTo(403);
        assertThat(response.getContentType()).containsIgnoringCase("charset=UTF-8");
    }
}
