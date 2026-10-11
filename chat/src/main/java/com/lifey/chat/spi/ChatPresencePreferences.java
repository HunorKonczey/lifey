package com.lifey.chat.spi;

import java.util.Collection;
import java.util.Set;

/**
 * Who has asked not to be seen online (LIF-153).
 *
 * <p>The question is asked about many people at once - every tick of the reconcile job, every peer list of a connecting
 * client - so it is one batch call, never a lookup per user. A user with no settings row has not asked for anything, so is
 * visible.
 */
public interface ChatPresencePreferences {

    /** The subset of {@code userIds} that turned "show when I am online" off. Empty input, empty answer. */
    Set<Long> hiddenAmong(Collection<Long> userIds);
}
