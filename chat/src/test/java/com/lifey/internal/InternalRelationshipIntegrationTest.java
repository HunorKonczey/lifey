package com.lifey.internal;

import com.lifey.chat.spi.http.InternalHeaders;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.OffsetDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The revoke webhook, end to end
 * (docs/chat/44-chat-service-extraction-plan.md §5.4, layer 2).
 *
 * <p>This is what replaced an in-transaction event listener with an HTTP call,
 * so the properties that used to come free now have to be tested: it must be
 * authenticated, it must be idempotent (nothing retries it, and the nightly
 * sweep may get there first), and it must freeze <em>every</em> thread the pair
 * holds — a re-invited client accumulates them.
 */
@SpringBootTest(properties = "lifey.monolith.internal-token=" + InternalRelationshipIntegrationTest.SECRET)
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class InternalRelationshipIntegrationTest {

    static final String SECRET = "integration-test-internal-secret";

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JdbcClient jdbcClient;

    long trainerId;
    long clientId;
    long conversationId;

    @BeforeEach
    void seed() {
        trainerId = saveUser("revoke-trainer-");
        clientId = saveUser("revoke-client-");
        long relationshipId = saveRelationship(trainerId, clientId, "ACTIVE");
        conversationId = saveConversation(relationshipId, trainerId, clientId);
    }

    @Test
    void theWebhookArchivesThePairsThread() throws Exception {
        assertThat(archivedAt(conversationId)).isEmpty();

        revoke(SECRET).andExpect(status().isNoContent());

        assertThat(archivedAt(conversationId)).isPresent();
    }

    @Test
    void aSecondDeliveryChangesNothing() throws Exception {
        // Nobody retries this call, but a duplicate is entirely possible — a
        // redelivery, or the nightly sweep having already done the work. The
        // archive timestamp must not move.
        revoke(SECRET).andExpect(status().isNoContent());
        OffsetDateTime first = archivedAt(conversationId).orElseThrow();

        revoke(SECRET).andExpect(status().isNoContent());

        assertThat(archivedAt(conversationId)).contains(first);
    }

    @Test
    void everyThreadThePairHoldsIsFrozen() throws Exception {
        // Revoke, re-invite, revoke again leaves several historical threads.
        // All of them are dead; only one of them is the newest.
        long secondRelationship = saveRelationship(trainerId, clientId, "ACTIVE");
        long secondConversation = saveConversation(secondRelationship, trainerId, clientId);

        revoke(SECRET).andExpect(status().isNoContent());

        assertThat(archivedAt(conversationId)).isPresent();
        assertThat(archivedAt(secondConversation)).isPresent();
    }

    @Test
    void withoutTheSecretNothingIsFrozen() throws Exception {
        mockMvc.perform(post("/internal/relationships/revoked")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body()))
                .andExpect(status().isUnauthorized());

        assertThat(archivedAt(conversationId)).isEmpty();
    }

    @Test
    void withTheWrongSecretNothingIsFrozen() throws Exception {
        revoke("not-the-secret").andExpect(status().isUnauthorized());

        assertThat(archivedAt(conversationId)).isEmpty();
    }

    // --- helpers -----------------------------------------------------------

    private org.springframework.test.web.servlet.ResultActions revoke(String secret) throws Exception {
        return mockMvc.perform(post("/internal/relationships/revoked")
                .header(InternalHeaders.TOKEN_HEADER, secret)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body()));
    }

    private String body() {
        return "{\"trainerId\":" + trainerId + ",\"clientId\":" + clientId + "}";
    }

    private Optional<OffsetDateTime> archivedAt(long id) {
        return jdbcClient.sql("select archived_at from chat_conversations where id = :id")
                .param("id", id)
                .query(OffsetDateTime.class)
                .optional();
    }

    private long saveUser(String prefix) {
        return jdbcClient.sql("""
                        insert into users (email, first_name, last_name, password_hash, created_at, utc_offset_minutes)
                        values (:email, 'Test', 'User', 'irrelevant', :now, 0)
                        returning id
                        """)
                .param("email", prefix + System.nanoTime() + "@example.com")
                .param("now", OffsetDateTime.now())
                .query(Long.class)
                .single();
    }

    private long saveRelationship(long trainer, long client, String status) {
        return jdbcClient.sql("""
                        insert into trainer_clients (trainer_id, client_id, status, created_at)
                        values (:trainer, :client, :status, :now) returning id
                        """)
                .param("trainer", trainer)
                .param("client", client)
                .param("status", status)
                .param("now", OffsetDateTime.now())
                .query(Long.class)
                .single();
    }

    private long saveConversation(long relationshipId, long trainer, long client) {
        return jdbcClient.sql("""
                        insert into chat_conversations (trainer_client_id, trainer_id, client_id, created_at)
                        values (:relationship, :trainer, :client, :now) returning id
                        """)
                .param("relationship", relationshipId)
                .param("trainer", trainer)
                .param("client", client)
                .param("now", OffsetDateTime.now())
                .query(Long.class)
                .single();
    }
}
