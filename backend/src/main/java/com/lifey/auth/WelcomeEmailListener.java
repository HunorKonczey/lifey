package com.lifey.auth;

import com.lifey.mail.service.MailService;

import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Fires only once the registration transaction has actually committed, so the
 * welcome email is never sent for a user row that ends up rolled back — and
 * the user is guaranteed to exist when the mail job (itself {@code @Async} in
 * {@link MailService}) reads it. Re-fetches the user rather than carrying it
 * on the event since AFTER_COMMIT runs outside the original transaction.
 */
@Component
@RequiredArgsConstructor
class WelcomeEmailListener {

    private static final Logger log = LoggerFactory.getLogger(WelcomeEmailListener.class);

    private final UserRepository userRepository;
    private final MailService mailService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onUserRegistered(UserRegisteredEvent event) {
        try {
            User user = userRepository.findById(event.userId()).orElse(null);
            if (user == null) {
                log.warn("Skipping welcome email, user {} not found after commit", event.userId());
                return;
            }
            mailService.sendWelcomeEmail(user);
        } catch (RuntimeException e) {
            // Registration already succeeded and committed - a failure here must
            // never surface to the caller.
            log.error("Failed to trigger welcome email for user {}", event.userId(), e);
        }
    }
}
