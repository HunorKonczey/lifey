package com.lifey.clientconfig;

import com.lifey.clientconfig.dto.ClientConfigResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Runtime configuration the clients fetch instead of compiling in
 * (docs/chat/44-chat-service-extraction-plan.md §7.1).
 *
 * <p><b>Why this exists at all.</b> The mobile app's base URL is a compile-time
 * constant, so putting the chat service's URL there too would make rolling the
 * cutover back an App Store review — one to three days, in the middle of
 * whatever went wrong. Serving it from here turns the rollback into an
 * environment variable on this service.
 *
 * <p>Authenticated, because only signed-in users chat and there is no reason to
 * advertise the deployment's topology to anyone else.
 */
@Tag(name = "Client Config", description = "Runtime configuration for mobile and web clients")
@RestController
@RequestMapping("/api/v1/client-config")
class ClientConfigController {

    /**
     * Empty means "the chat is served by this API" — which is both the state
     * before the cutover and the rollback afterwards. Clients treat an empty or
     * missing value as "use your normal base URL", so this variable going away
     * degrades to the pre-cutover behaviour rather than to a broken chat.
     */
    @Value("${lifey.client-config.chat-base-url:}")
    private String chatBaseUrl;

    /**
     * How long a client may trust a cached copy. Deliberately short around a
     * cutover (five minutes) so the switch propagates quickly, and longer
     * afterwards — the value is an environment variable for exactly that.
     */
    @Value("${lifey.client-config.ttl-seconds:21600}")
    private long ttlSeconds;

    @Operation(summary = "Runtime client configuration",
            description = "Where the chat API lives, and how long this answer may be cached. "
                    + "An empty chatBaseUrl means the chat is served by this API — clients must "
                    + "fall back to their normal base URL rather than failing.")
    @GetMapping
    ClientConfigResponse get() {
        return new ClientConfigResponse(chatBaseUrl, ttlSeconds);
    }
}
