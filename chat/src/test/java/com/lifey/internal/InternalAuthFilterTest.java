package com.lifey.internal;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.lifey.chat.spi.http.InternalHeaders;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * The internal API acts on behalf of a user without one being signed in —
 * {@code POST /internal/relationships/revoked} freezes any pair's thread — so this filter is
 * the only thing between the internet and anyone who wants to silence a conversation
 * (docs/chat/44-chat-service-extraction-plan.md §5.5).
 *
 * <p>The case worth pinning down is the <em>unconfigured</em> one: a deployment
 * that forgot the secret must end up closed, not open.
 */
class InternalAuthFilterTest {

    private static final String SECRET = "s3cr3t-token-value";

    @Test
    void aMatchingSecretPassesThrough() throws Exception {
        FilterChain chain = mock(FilterChain.class);
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter(SECRET).doFilter(request(SECRET), response, chain);

        verify(chain).doFilter(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
        assertThat(response.getStatus()).isEqualTo(200);
    }

    @Test
    void aWrongSecretIsRejected() throws Exception {
        FilterChain chain = mock(FilterChain.class);
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter(SECRET).doFilter(request("not-the-secret"), response, chain);

        verify(chain, never()).doFilter(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(response.getContentAsString()).contains("Invalid internal credentials");
    }

    @Test
    void aMissingHeaderIsRejected() throws Exception {
        FilterChain chain = mock(FilterChain.class);
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter(SECRET).doFilter(new MockHttpServletRequest("POST", "/internal/relationships/revoked"), response, chain);

        verify(chain, never()).doFilter(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
        assertThat(response.getStatus()).isEqualTo(401);
    }

    @Test
    void withNoSecretConfiguredEverythingIsRejected() throws Exception {
        // The dangerous default. An empty token must CLOSE the endpoint: a
        // deployment that forgot the variable should stop receiving revoke
        // notifications (loud, fixable), not expose a way to freeze any thread.
        for (String unconfigured : new String[]{null, "", "   "}) {
            FilterChain chain = mock(FilterChain.class);
            MockHttpServletResponse response = new MockHttpServletResponse();

            filter(unconfigured).doFilter(request("anything"), response, chain);

            verify(chain, never()).doFilter(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
            assertThat(response.getStatus()).isEqualTo(401);
        }
    }

    @Test
    void aSecretThatIsAPrefixOfTheRealOneIsRejected() throws Exception {
        // Constant-time comparison also has to get the boring part right:
        // different lengths must not compare equal.
        FilterChain chain = mock(FilterChain.class);
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter(SECRET).doFilter(request(SECRET.substring(0, 5)), response, chain);

        verify(chain, never()).doFilter(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any());
        assertThat(response.getStatus()).isEqualTo(401);
    }

    private static InternalAuthFilter filter(String token) {
        return new InternalAuthFilter(token, new ObjectMapper().registerModule(new JavaTimeModule()));
    }

    private static MockHttpServletRequest request(String presentedToken) {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/internal/relationships/revoked");
        request.addHeader(InternalHeaders.TOKEN_HEADER, presentedToken);
        return request;
    }
}
