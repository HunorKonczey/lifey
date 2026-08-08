package com.lifey.chat.spi.jdbc;

import com.lifey.chat.spi.ChatNotificationPreferences;
import com.lifey.chat.spi.ChatPushPrefs;
import com.lifey.chat.spi.ChatRelationship;
import com.lifey.chat.spi.ChatRelationshipGuard;
import com.lifey.chat.spi.ChatUser;
import com.lifey.chat.spi.ChatUserDirectory;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The three hand-written projections over tables this service does not own
 * (docs/chat/44-chat-service-extraction-plan.md §4.4).
 *
 * <p><b>This is the most load-bearing test in the service.</b> Everything else
 * here is Java the compiler checks; these are SQL strings naming columns in
 * another deployable's schema, and nothing but a real database will notice when
 * one of those names stops being true. They run against Postgres for that
 * reason — mocking {@code JdbcClient} would verify the string equals itself.
 *
 * <p>The defaults asserted below used to live in the monolith's adapters, which
 * were deleted when the chat left it. They matter as much here as they did
 * there: a settings row is created lazily on first access, so <em>most</em>
 * users do not have one, and reading "no row" as "push off" would silence the
 * feature for exactly the people who never touched the settings screen.
 */
@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
class JdbcProjectionsIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    JdbcClient jdbcClient;

    @Autowired
    ChatUserDirectory userDirectory;

    @Autowired
    ChatNotificationPreferences preferences;

    @Autowired
    ChatRelationshipGuard relationshipGuard;

    // --- ChatUserDirectory -------------------------------------------------

    @Test
    void aUserWithANameIsShownByName() {
        long id = saveUser("Nagy", "Péter", 0);

        ChatUser user = userDirectory.find(id).orElseThrow();

        assertThat(user.displayName()).isEqualTo("Nagy Péter");
        assertThat(user.email()).endsWith("@example.com");
    }

    @Test
    void aUserWithNoNameFallsBackToTheirEmail() {
        // Someone who signed up and never filled in a profile still needs
        // something to show in a thread header.
        long id = saveUser(null, null, 0);

        assertThat(userDirectory.find(id).orElseThrow().displayName()).contains("@example.com");
    }

    @Test
    void aHalfFilledNameIsTrimmedRatherThanPaddedWithASpace() {
        long id = saveUser("Nagy", null, 0);

        assertThat(userDirectory.find(id).orElseThrow().displayName()).isEqualTo("Nagy");
    }

    @Test
    void theBatchLookupReturnsWhatItFindsAndSkipsWhatItDoesNot() {
        long a = saveUser("A", "One", 0);
        long b = saveUser("B", "Two", 0);

        var found = userDirectory.findAll(List.of(a, b, 999_999L));

        assertThat(found).containsOnlyKeys(a, b);
        assertThat(found.get(a).displayName()).isEqualTo("A One");
    }

    @Test
    void anEmptyBatchDoesNotReachTheDatabase() {
        // `in ()` is a syntax error in Postgres; the empty conversation list
        // must not turn into a failed query.
        assertThat(userDirectory.findAll(Set.of())).isEmpty();
    }

    @Test
    void anUnknownUserIsEmpty() {
        assertThat(userDirectory.find(999_999L)).isEmpty();
    }

    // --- ChatNotificationPreferences ---------------------------------------

    @Test
    void aUserWithNoSettingsRowGetsPushOnNoQuietWindowAndEnglishCopy() {
        // The default that matters most: settings rows are created lazily, so
        // this is the common case, not an edge one.
        long id = saveUser("No", "Settings", 120);

        ChatPushPrefs prefs = preferences.load(id);

        assertThat(prefs.pushEnabled()).isTrue();
        assertThat(prefs.quietHoursStart()).isNull();
        assertThat(prefs.quietHoursEnd()).isNull();
        assertThat(prefs.hungarian()).isFalse();
        // Read off users, not user_settings — so it survives the row's absence.
        assertThat(prefs.utcOffsetMinutes()).isEqualTo(120);
    }

    @Test
    void anExistingRowIsCarriedThroughFieldByField() {
        long id = saveUser("Has", "Settings", 60);
        saveSettings(id, false, LocalTime.of(22, 0), LocalTime.of(7, 0), "HUNGARIAN");

        ChatPushPrefs prefs = preferences.load(id);

        assertThat(prefs.pushEnabled()).isFalse();
        assertThat(prefs.quietHoursStart()).isEqualTo(LocalTime.of(22, 0));
        assertThat(prefs.quietHoursEnd()).isEqualTo(LocalTime.of(7, 0));
        assertThat(prefs.hungarian()).isTrue();
        assertThat(prefs.utcOffsetMinutes()).isEqualTo(60);
    }

    @Test
    void anyLanguageOtherThanHungarianIsEnglishCopy() {
        long id = saveUser("Sys", "Lang", 0);
        saveSettings(id, true, null, null, "SYSTEM");

        assertThat(preferences.load(id).hungarian()).isFalse();
    }

    @Test
    void aVanishedUserFallsBackToDefaults_ratherThanFailingTheNotification() {
        ChatPushPrefs prefs = preferences.load(999_999L);

        // Push stays on: the failure mode is a wasted send, not a silently
        // dropped message.
        assertThat(prefs.pushEnabled()).isTrue();
        assertThat(prefs.utcOffsetMinutes()).isZero();
    }

    // --- ChatRelationshipGuard ---------------------------------------------

    @Test
    void anActiveLinkIsReturnedWithBothSides() {
        long trainer = saveUser("T", "One", 0);
        long client = saveUser("C", "Two", 0);
        long id = saveRelationship(trainer, client, "ACTIVE");

        ChatRelationship relationship = relationshipGuard.findActive(id).orElseThrow();

        assertThat(relationship.id()).isEqualTo(id);
        assertThat(relationship.trainerId()).isEqualTo(trainer);
        assertThat(relationship.clientId()).isEqualTo(client);
    }

    @Test
    void aRevokedLinkIsNotActive_soTheChatNeverSeesIt() {
        long trainer = saveUser("T", "Rev", 0);
        long client = saveUser("C", "Rev", 0);
        long id = saveRelationship(trainer, client, "REVOKED");

        assertThat(relationshipGuard.findActive(id)).isEmpty();
        assertThat(relationshipGuard.findActiveBetween(trainer, client)).isEmpty();
    }

    @Test
    void aPendingInviteIsNotAnActiveRelationshipEither() {
        long trainer = saveUser("T", "Pend", 0);
        long client = saveUser("C", "Pend", 0);
        long id = saveRelationship(trainer, client, "PENDING");

        assertThat(relationshipGuard.findActive(id)).isEmpty();
    }

    @Test
    void aPairIsFoundFromEitherSide() {
        // Without this, a client could never open a thread with their trainer.
        long trainer = saveUser("T", "Either", 0);
        long client = saveUser("C", "Either", 0);
        long id = saveRelationship(trainer, client, "ACTIVE");

        assertThat(relationshipGuard.findActiveBetween(trainer, client))
                .get().extracting(ChatRelationship::id).isEqualTo(id);
        assertThat(relationshipGuard.findActiveBetween(client, trainer))
                .get().extracting(ChatRelationship::id).isEqualTo(id);
    }

    @Test
    void twoStrangersHaveNoRelationship() {
        long a = saveUser("A", "Stranger", 0);
        long b = saveUser("B", "Stranger", 0);

        assertThat(relationshipGuard.findActiveBetween(a, b)).isEmpty();
    }

    @Test
    void aMissingLinkIsEmpty() {
        assertThat(relationshipGuard.findActive(999_999L)).isEmpty();
    }

    // --- fixtures ----------------------------------------------------------

    private long saveUser(String firstName, String lastName, int utcOffsetMinutes) {
        return jdbcClient.sql("""
                        insert into users (email, first_name, last_name, password_hash,
                                           created_at, utc_offset_minutes)
                        values (:email, :firstName, :lastName, 'irrelevant', :now, :offset)
                        returning id
                        """)
                .param("email", "proj-" + System.nanoTime() + "@example.com")
                .param("firstName", firstName)
                .param("lastName", lastName)
                .param("now", OffsetDateTime.now())
                .param("offset", utcOffsetMinutes)
                .query(Long.class)
                .single();
    }

    private void saveSettings(long userId, boolean pushEnabled, LocalTime start, LocalTime end, String language) {
        jdbcClient.sql("""
                        insert into user_settings (user_id, language, chat_push_enabled,
                                                   chat_quiet_hours_start, chat_quiet_hours_end)
                        values (:userId, :language, :pushEnabled, :start, :end)
                        """)
                .param("userId", userId)
                .param("language", language)
                .param("pushEnabled", pushEnabled)
                .param("start", start)
                .param("end", end)
                .update();
    }

    private long saveRelationship(long trainerId, long clientId, String status) {
        return jdbcClient.sql("""
                        insert into trainer_clients (trainer_id, client_id, status, created_at)
                        values (:trainer, :client, :status, :now) returning id
                        """)
                .param("trainer", trainerId)
                .param("client", clientId)
                .param("status", status)
                .param("now", OffsetDateTime.now())
                .query(Long.class)
                .single();
    }
}
