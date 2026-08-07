package com.lifey.chat.service;

import com.lifey.chat.ChatProperties;
import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;

class ChatPresenceRegistryTest {

    private static final Long USER_ID = 7L;
    private static final Long CONVERSATION_ID = 12L;

    @Test
    void reportingAThreadMakesTheUserViewIt() {
        ChatPresenceRegistry registry = registryWithTtl(Duration.ofMinutes(2));

        registry.set(USER_ID, CONVERSATION_ID);

        assertThat(registry.isViewing(USER_ID, CONVERSATION_ID)).isTrue();
        assertThat(registry.isViewing(USER_ID, 99L)).isFalse();
    }

    @Test
    void anUnknownUserIsViewingNothing() {
        assertThat(registryWithTtl(Duration.ofMinutes(2)).isViewing(USER_ID, CONVERSATION_ID)).isFalse();
    }

    @Test
    void reportingNullClearsIt() {
        ChatPresenceRegistry registry = registryWithTtl(Duration.ofMinutes(2));
        registry.set(USER_ID, CONVERSATION_ID);

        registry.set(USER_ID, null);

        assertThat(registry.isViewing(USER_ID, CONVERSATION_ID)).isFalse();
    }

    @Test
    void aDisconnectClearsIt() {
        ChatPresenceRegistry registry = registryWithTtl(Duration.ofMinutes(2));
        registry.set(USER_ID, CONVERSATION_ID);

        registry.clear(USER_ID);

        assertThat(registry.isViewing(USER_ID, CONVERSATION_ID)).isFalse();
    }

    @Test
    void presenceExpires_soAKilledAppStopsSilencingPushes() {
        // A TTL already in the past, so the entry is stale the moment it is
        // written — the same state a two-minute-old entry reaches, without
        // making the test wait two minutes for it.
        ChatPresenceRegistry registry = registryWithTtl(Duration.ofSeconds(-1));
        registry.set(USER_ID, CONVERSATION_ID);

        assertThat(registry.isViewing(USER_ID, CONVERSATION_ID)).isFalse();
    }

    private static ChatPresenceRegistry registryWithTtl(Duration ttl) {
        return new ChatPresenceRegistry(
                new ChatProperties(true, 2000, 30, 100, 30, 600, Duration.ofMinutes(5), 200, ttl,
                        Duration.ofSeconds(60), Duration.ofMinutes(30), 1, false, Duration.ofHours(24),
                        8L * 1024 * 1024, 1600, 400));
    }
}
