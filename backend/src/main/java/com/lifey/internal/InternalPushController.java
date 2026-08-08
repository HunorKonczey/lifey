package com.lifey.internal;

import com.lifey.internal.dto.InternalPushRequest;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import io.swagger.v3.oas.annotations.Hidden;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Lets another service in this deployment send a push through the one pipeline
 * that holds the APNs key and the Firebase credentials
 * (docs/chat/44-chat-service-extraction-plan.md §6.1).
 *
 * <p><b>Not chat-specific</b>, on purpose. The chat is the first caller, but the
 * reason this endpoint exists is that the push credentials — and the Firebase
 * Admin SDK's considerable class-loading cost — should live in exactly one JVM.
 * Any future service gets the same deal without a second integration.
 *
 * <p>Authorization is the shared secret checked by {@link InternalAuthFilter};
 * there is no user in this request, which is exactly why that filter is strict.
 */
@Hidden // not part of the public API surface springdoc advertises
@RestController
@RequestMapping("/internal")
@RequiredArgsConstructor
class InternalPushController {

    private final PushService pushService;

    /**
     * Fire and forget: {@code PushService} never throws, prunes dead tokens
     * itself, and logs its own failures. 202 rather than 200 says what actually
     * happened — the notification was accepted for delivery, not delivered.
     */
    @PostMapping("/push")
    @ResponseStatus(HttpStatus.ACCEPTED)
    void send(@Valid @RequestBody InternalPushRequest request) {
        pushService.sendToUser(request.userId(), new PushMessage(
                request.title(), request.body(), request.data(), request.collapseKey()));
    }
}
