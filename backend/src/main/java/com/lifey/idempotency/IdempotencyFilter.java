package com.lifey.idempotency;

import com.lifey.auth.UserPrincipal;
import com.lifey.idempotency.service.IdempotencyService;
import com.lifey.idempotency.service.IdempotencyService.Claim;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.NonNull;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpMethod;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

/**
 * Makes a {@code POST} that carries an {@code Idempotency-Key} header safe to repeat.
 *
 * <p>The mobile outbox retries a create when the answer never arrived (timeout, gateway 502/503/504), and the
 * request it is retrying may already have committed: the retry then created the entity twice. With the key, the
 * first request is claimed and, once it answers 2xx, its response is stored; a repeat is answered from the store
 * ({@code Idempotent-Replayed: true}) without running again. A request that fails frees its key, so a retry after
 * a 4xx/5xx runs for real. Keys are per user.
 *
 * <p>Sits after {@code JwtAuthenticationFilter} in the security chain (built there, deliberately not a bean, like
 * that filter: a {@code Filter} bean would also be registered globally and run twice). Requests without a key, or
 * without an authenticated user, pass straight through, as does a key too long to store.
 */
@RequiredArgsConstructor
public class IdempotencyFilter extends OncePerRequestFilter {

    public static final String HEADER = "Idempotency-Key";
    public static final String REPLAYED_HEADER = "Idempotent-Replayed";

    private static final Logger log = LoggerFactory.getLogger(IdempotencyFilter.class);

    private static final int MAX_KEY_LENGTH = 80;
    /** A response larger than this is not worth keeping in the table: the request runs normally and is not recorded. */
    private static final int MAX_STORED_BODY_BYTES = 256 * 1024;

    private final IdempotencyService service;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String key = request.getHeader(HEADER);
        return !HttpMethod.POST.matches(request.getMethod()) || key == null || key.isBlank()
                || key.trim().length() > MAX_KEY_LENGTH;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request, @NonNull HttpServletResponse response,
                                    @NonNull FilterChain chain) throws ServletException, IOException {
        Long userId = currentUserId();
        if (userId == null) {
            chain.doFilter(request, response);
            return;
        }
        String key = request.getHeader(HEADER).trim();
        String path = request.getQueryString() == null
                ? request.getRequestURI()
                : request.getRequestURI() + "?" + request.getQueryString();

        Claim claim = service.claim(userId, key, request.getMethod(), path);
        switch (claim.outcome()) {
            case REPLAY -> replay(response, claim);
            case IN_FLIGHT -> {
                response.setHeader("Retry-After", "2");
                reject(response, HttpServletResponse.SC_CONFLICT, "Conflict",
                        "A request with this Idempotency-Key is still being processed");
            }
            case MISMATCH -> reject(response, 422, "Unprocessable Entity",
                    "This Idempotency-Key was already used for a different request");
            case OWNED -> runOwned(request, response, chain, userId, key);
        }
    }

    private void runOwned(HttpServletRequest request, HttpServletResponse response, FilterChain chain,
                          Long userId, String key) throws ServletException, IOException {
        ContentCachingResponseWrapper wrapper = new ContentCachingResponseWrapper(response);
        try {
            chain.doFilter(request, wrapper);
        } catch (ServletException | IOException | RuntimeException e) {
            safely(() -> service.release(userId, key), "release", key);
            throw e;
        }

        int status = wrapper.getStatus();
        byte[] body = wrapper.getContentAsByteArray();
        if (status >= 200 && status < 300 && body.length <= MAX_STORED_BODY_BYTES) {
            safely(() -> service.complete(userId, key, status, wrapper.getContentType(), body), "complete", key);
        } else {
            safely(() -> service.release(userId, key), "release", key);
        }
        wrapper.copyBodyToResponse();
    }

    private static void replay(HttpServletResponse response, Claim claim) throws IOException {
        response.setStatus(claim.status());
        response.setHeader(REPLAYED_HEADER, "true");
        if (claim.contentType() != null) {
            response.setContentType(claim.contentType());
        }
        byte[] body = claim.body();
        if (body != null && body.length > 0) {
            response.setContentLength(body.length);
            response.getOutputStream().write(body);
        }
    }

    private static void reject(HttpServletResponse response, int status, String error, String message) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json");
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"status\":" + status + ",\"error\":\"" + error + "\",\"message\":\"" + message + "\"}");
    }

    /** Bookkeeping must never fail a request that already ran: the worst a lost write costs is the old behaviour. */
    private static void safely(Runnable action, String what, String key) {
        try {
            action.run();
        } catch (RuntimeException e) {
            log.warn("Idempotency-Key {} could not be {}d", key, what, e);
        }
    }

    private static Long currentUserId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        return authentication != null && authentication.getPrincipal() instanceof UserPrincipal principal
                ? principal.id()
                : null;
    }
}
