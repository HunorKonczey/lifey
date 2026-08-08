package com.lifey.chat.spi;

import java.time.LocalTime;

/**
 * Everything the §5.2 push ladder needs to know about a recipient, in one
 * object so the gates cost one lookup rather than three.
 *
 * <p>There is no "the user has no settings row" case here: the provider applies
 * the defaults (push on, no quiet window, English) before handing this over, so
 * the ladder reads the same whether the row exists or not.
 *
 * @param utcOffsetMinutes minutes east of UTC. Lives here rather than on
 *                         {@link ChatUser} because the only thing the chat does
 *                         with it is decide whether {@code quietHoursStart..End}
 *                         contains the user's wall clock — it travels with the
 *                         window it is read against.
 * @param quietHoursStart  null when unset; a half-configured window is no window
 * @param hungarian        which copy the notification is written in. A boolean
 *                         rather than a language enum: the chat has exactly two
 *                         sets of strings, and mirroring the settings module's
 *                         enum here would be a wider contract than that.
 */
public record ChatPushPrefs(
        boolean pushEnabled,
        int utcOffsetMinutes,
        LocalTime quietHoursStart,
        LocalTime quietHoursEnd,
        boolean hungarian
) {
}
