package com.lifey.user;

import org.springframework.stereotype.Component;

/**
 * Applies the client-reported UTC offset (see {@code User#utcOffsetMinutes}) to a
 * managed {@link User}. Called from every auth flow that touches an existing or new
 * user (register/login/refresh/social login) so the stored offset stays current for
 * *all* users, not just at registration.
 */
@Component
public class UserUtcOffsetUpdater {

    private static final int MIN_OFFSET_MINUTES = -12 * 60;
    private static final int MAX_OFFSET_MINUTES = 14 * 60;

    public void apply(User user, Integer utcOffsetMinutes) {
        if (utcOffsetMinutes == null) {
            return;
        }
        if (utcOffsetMinutes < MIN_OFFSET_MINUTES || utcOffsetMinutes > MAX_OFFSET_MINUTES) {
            return;
        }
        if (utcOffsetMinutes != user.getUtcOffsetMinutes()) {
            user.setUtcOffsetMinutes(utcOffsetMinutes);
        }
    }
}
