package com.lifey.chat;

import com.jayway.jsonpath.JsonPath;
import com.lifey.auth.JwtProperties;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.Date;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end pass over iteration I1's "Kész, ha" bar
 * (docs/chat/40-trainer-chat-plan.md): the Postman flow, driven through the
 * real filter chain and a real Postgres — open a thread, talk both ways, count
 * unread, tombstone, archive — plus the guard that matters most, namely that a
 * user who is not a participant sees a 404 on every route.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class ChatFlowIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JdbcClient jdbcClient;

    @Autowired
    JwtProperties jwtProperties;

    long trainerId;
    long clientId;
    long strangerId;
    long relationshipId;
    String trainerToken;
    String clientToken;
    String strangerToken;

    @BeforeEach
    void seed() {
        trainerId = saveUser("chat-trainer-");
        clientId = saveUser("chat-client-");
        strangerId = saveUser("chat-stranger-");
        relationshipId = saveRelationship(trainerId, clientId, "ACTIVE");

        trainerToken = tokenFor(trainerId);
        clientToken = tokenFor(clientId);
        strangerToken = tokenFor(strangerId);
    }

    @Test
    void trainerAndClientHoldAConversation() throws Exception {
        long conversationId = openConversation();

        send(conversationId, trainerToken, "Holnap 17:00 jó?", "trainer-msg-1")
                .andExpect(status().isCreated());
        send(conversationId, clientToken, "Persze!", "client-msg-1")
                .andExpect(status().isCreated());

        // Newest first, both directions present.
        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages")
                        .header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.items[0].body").value("Persze!"))
                .andExpect(jsonPath("$.items[1].body").value("Holnap 17:00 jó?"))
                .andExpect(jsonPath("$.hasMore").value(false));
    }

    @Test
    void bothSidesSeeTheSameThreadWithTheirOwnPeerLabel() throws Exception {
        long conversationId = openConversation();
        send(conversationId, trainerToken, "Szia!", "trainer-msg-1");

        mockMvc.perform(get("/api/v1/chat/conversations").header("Authorization", "Bearer " + trainerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].peer.role").value("CLIENT"))
                .andExpect(jsonPath("$.items[0].peer.userId").value(clientId))
                // The sender's own message never counts as unread for them.
                .andExpect(jsonPath("$.items[0].unreadCount").value(0));

        mockMvc.perform(get("/api/v1/chat/conversations").header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].peer.role").value("TRAINER"))
                .andExpect(jsonPath("$.items[0].peer.userId").value(trainerId))
                .andExpect(jsonPath("$.items[0].unreadCount").value(1));
    }

    @Test
    void readReceiptClearsTheUnreadCount() throws Exception {
        long conversationId = openConversation();
        long messageId = sendAndReadId(conversationId, trainerToken, "Szia!", "trainer-msg-1");

        mockMvc.perform(post("/api/v1/chat/conversations/" + conversationId + "/read")
                        .header("Authorization", "Bearer " + clientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lastReadMessageId\":" + messageId + "}"))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/chat/conversations").header("Authorization", "Bearer " + clientToken))
                .andExpect(jsonPath("$.items[0].unreadCount").value(0));
    }

    @Test
    void resendingTheSameClientMessageIdStoresOneMessage() throws Exception {
        long conversationId = openConversation();

        send(conversationId, trainerToken, "Szia!", "same-id").andExpect(status().isCreated());
        // The offline outbox's blind retry: same id, 200 instead of 201, no second row.
        send(conversationId, trainerToken, "Szia!", "same-id").andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages")
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items.length()").value(1));
    }

    @Test
    void keysetPagingWalksTheThreadWithoutGapsOrDuplicates() throws Exception {
        long conversationId = openConversation();
        for (int i = 0; i < 5; i++) {
            send(conversationId, trainerToken, "m" + i, "msg-" + i);
        }

        String firstPage = mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages?limit=2")
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.items[0].body").value("m4"))
                .andExpect(jsonPath("$.items[1].body").value("m3"))
                .andExpect(jsonPath("$.hasMore").value(true))
                .andReturn().getResponse().getContentAsString();
        long oldestOnFirstPage = idAt(firstPage, "$.items[1].id");

        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId
                        + "/messages?limit=2&before=" + oldestOnFirstPage)
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items[0].body").value("m2"))
                .andExpect(jsonPath("$.items[1].body").value("m1"))
                .andExpect(jsonPath("$.hasMore").value(true));
    }

    @Test
    void afterCursorFillsTheGapAboveAKnownMessage() throws Exception {
        long conversationId = openConversation();
        long first = sendAndReadId(conversationId, trainerToken, "m0", "msg-0");
        send(conversationId, trainerToken, "m1", "msg-1");
        send(conversationId, trainerToken, "m2", "msg-2");

        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages?after=" + first)
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.items[0].body").value("m2"))
                .andExpect(jsonPath("$.items[1].body").value("m1"));
    }

    @Test
    void deletingYourOwnMessageLeavesATombstone() throws Exception {
        long conversationId = openConversation();
        long messageId = sendAndReadId(conversationId, trainerToken, "oops", "trainer-msg-1");

        mockMvc.perform(delete("/api/v1/chat/messages/" + messageId)
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages")
                        .header("Authorization", "Bearer " + clientToken))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].body").doesNotExist())
                .andExpect(jsonPath("$.items[0].deletedAt").isNotEmpty());
    }

    @Test
    void deletingSomeoneElsesMessageIsNotFound() throws Exception {
        long conversationId = openConversation();
        long messageId = sendAndReadId(conversationId, trainerToken, "mine", "trainer-msg-1");

        mockMvc.perform(delete("/api/v1/chat/messages/" + messageId)
                        .header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void anArchivedThreadIsReadOnly() throws Exception {
        long conversationId = openConversation();
        send(conversationId, trainerToken, "Szia!", "trainer-msg-1");

        // How archived_at comes to be set is not this service's business yet:
        // in the monolith a revoke does it in the same transaction, and in the
        // extracted service it will arrive as the M4 internal webhook (§5.4).
        // What this pins down is the behaviour that follows either way.
        jdbcClient.sql("update chat_conversations set archived_at = now() where id = :id")
                .param("id", conversationId)
                .update();

        send(conversationId, trainerToken, "Még egy", "trainer-msg-2")
                .andExpect(status().isConflict());

        // Read access survives — the history belongs to both of them (§1.3/1).
        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages")
                        .header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1));
    }

    @Test
    void openingAConversationIsIdempotent() throws Exception {
        long first = openConversation();

        mockMvc.perform(post("/api/v1/chat/conversations")
                        .header("Authorization", "Bearer " + clientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"trainerClientId\":" + relationshipId + "}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(first));
    }

    @Test
    void openingWithAPeerUserIdWorksFromEitherSide() throws Exception {
        mockMvc.perform(post("/api/v1/chat/conversations/with-user/" + clientId)
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/chat/conversations/with-user/" + trainerId)
                        .header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isOk());
    }

    @Test
    void aNonParticipantIsNotFoundOnEveryRoute() throws Exception {
        long conversationId = openConversation();
        long messageId = sendAndReadId(conversationId, trainerToken, "private", "trainer-msg-1");

        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages")
                        .header("Authorization", "Bearer " + strangerToken))
                .andExpect(status().isNotFound());

        send(conversationId, strangerToken, "hello?", "stranger-msg-1")
                .andExpect(status().isNotFound());

        mockMvc.perform(post("/api/v1/chat/conversations/" + conversationId + "/read")
                        .header("Authorization", "Bearer " + strangerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lastReadMessageId\":" + messageId + "}"))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete("/api/v1/chat/messages/" + messageId)
                        .header("Authorization", "Bearer " + strangerToken))
                .andExpect(status().isNotFound());

        mockMvc.perform(post("/api/v1/chat/conversations/with-user/" + clientId)
                        .header("Authorization", "Bearer " + strangerToken))
                .andExpect(status().isNotFound());

        // ...and the thread never shows up in their list.
        mockMvc.perform(get("/api/v1/chat/conversations").header("Authorization", "Bearer " + strangerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void chatEndpointsAreReachableWithoutTheTrainerRole() throws Exception {
        // The whole point of hanging chat off /api/v1/chat/** instead of
        // /api/v1/trainer/**: the client has no ROLE_TRAINER (§4).
        mockMvc.perform(get("/api/v1/chat/conversations").header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isOk());
    }

    @Test
    void unauthenticatedRequestsAreRejected() throws Exception {
        mockMvc.perform(get("/api/v1/chat/conversations"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void readReceiptShowsUpAsThePeerCursorsOnTheSendersSide() throws Exception {
        // What the sender's tick marks are drawn from (§I4): the trainer sees
        // how far the client got, not their own cursor.
        long conversationId = openConversation();
        long messageId = sendAndReadId(conversationId, trainerToken, "Szia!", "trainer-msg-1");

        mockMvc.perform(get("/api/v1/chat/conversations").header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items[0].peerLastReadMessageId").doesNotExist())
                .andExpect(jsonPath("$.items[0].peerLastDeliveredMessageId").doesNotExist());

        mockMvc.perform(post("/api/v1/chat/conversations/" + conversationId + "/read")
                        .header("Authorization", "Bearer " + clientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lastReadMessageId\":" + messageId + "}"))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/chat/conversations").header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items[0].peerLastReadMessageId").value(messageId))
                // Reading is a stronger statement than delivery, so it drags
                // the delivered cursor along with it.
                .andExpect(jsonPath("$.items[0].peerLastDeliveredMessageId").value(messageId));
    }

    @Test
    void presenceIsAcceptedInBothDirections() throws Exception {
        long conversationId = openConversation();

        mockMvc.perform(post("/api/v1/chat/presence")
                        .header("Authorization", "Bearer " + clientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"activeConversationId\":" + conversationId + "}"))
                .andExpect(status().isNoContent());

        // Leaving the thread / going to the background.
        mockMvc.perform(post("/api/v1/chat/presence")
                        .header("Authorization", "Bearer " + clientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"activeConversationId\":null}"))
                .andExpect(status().isNoContent());
    }

    @Test
    void theStreamIsBehindAuthenticationLikeEveryOtherChatRoute() throws Exception {
        mockMvc.perform(get("/api/v1/chat/stream"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/v1/chat/stream").header("Authorization", "Bearer " + clientToken))
                .andExpect(request().asyncStarted());
    }

    // --- search (I6) --------------------------------------------------------
    //
    // These are the only tests that exercise the search query itself: the
    // accent folding and the wildcard escaping live in SQL, so a mock cannot
    // tell whether they work.

    @Test
    void searchFindsAMessageIgnoringCaseAndAccents() throws Exception {
        long conversationId = openConversation();
        send(conversationId, trainerToken, "Holnap Lábnap lesz", "trainer-msg-1");
        send(conversationId, clientToken, "Rendben", "client-msg-1");

        // "labnap" must find "Lábnap" — in Hungarian an accent-sensitive search
        // is a search nobody can use.
        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages/search")
                        .param("q", "labnap")
                        .header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].body").value("Holnap Lábnap lesz"))
                .andExpect(jsonPath("$.hasMore").value(false));
    }

    @Test
    void searchDoesNotMatchTombstonedMessages() throws Exception {
        long conversationId = openConversation();
        long messageId = sendAndReadId(conversationId, trainerToken, "titok", "trainer-msg-1");

        mockMvc.perform(delete("/api/v1/chat/messages/" + messageId)
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(status().isNoContent());

        // The text is genuinely gone, so there is nothing left to find.
        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages/search")
                        .param("q", "titok")
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void searchTreatsWildcardsAsText() throws Exception {
        long conversationId = openConversation();
        send(conversationId, trainerToken, "Menj fel 50% terheléssel", "trainer-msg-1");
        send(conversationId, trainerToken, "Semmi százalék itt", "trainer-msg-2");

        // Unescaped, "%" would match both — and every other message too.
        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages/search")
                        .param("q", "50%")
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].body").value("Menj fel 50% terheléssel"));
    }

    @Test
    void searchIsScopedToTheThreadAndToItsParticipants() throws Exception {
        long conversationId = openConversation();
        send(conversationId, trainerToken, "lábnap", "trainer-msg-1");

        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages/search")
                        .param("q", "lábnap")
                        .header("Authorization", "Bearer " + strangerToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void searchPagesBackwardsWithTheSameCursorTheThreadUses() throws Exception {
        long conversationId = openConversation();
        long first = sendAndReadId(conversationId, trainerToken, "ismétlés egy", "trainer-msg-1");
        long second = sendAndReadId(conversationId, trainerToken, "ismétlés kettő", "trainer-msg-2");

        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages/search")
                        .param("q", "ismétlés")
                        .param("limit", "1")
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items[0].id").value(second))
                .andExpect(jsonPath("$.hasMore").value(true));

        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages/search")
                        .param("q", "ismétlés")
                        .param("before", String.valueOf(second))
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].id").value(first))
                .andExpect(jsonPath("$.hasMore").value(false));
    }

    // --- helpers -----------------------------------------------------------

    private long openConversation() throws Exception {
        String body = mockMvc.perform(post("/api/v1/chat/conversations")
                        .header("Authorization", "Bearer " + trainerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"trainerClientId\":" + relationshipId + "}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return idAt(body, "$.id");
    }

    private ResultActions send(long conversationId, String token, String body, String clientMessageId)
            throws Exception {
        return mockMvc.perform(post("/api/v1/chat/conversations/" + conversationId + "/messages")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"body\":\"" + body + "\",\"clientMessageId\":\"" + clientMessageId + "\"}"));
    }

    private long sendAndReadId(long conversationId, String token, String body, String clientMessageId)
            throws Exception {
        String response = send(conversationId, token, body, clientMessageId)
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return idAt(response, "$.id");
    }

    private static long idAt(String json, String path) {
        return ((Number) JsonPath.read(json, path)).longValue();
    }

    /**
     * Straight SQL, not a repository: {@code users} belongs to lifey-api, and
     * this service deliberately has no entity for it (§4.4). Seeding it the
     * same way the production code reads it — by column name — is what makes
     * this test able to catch a projection that names a column wrong.
     */
    private long saveUser(String emailPrefix) {
        return jdbcClient.sql("""
                        insert into users (email, first_name, last_name, password_hash,
                                           created_at, utc_offset_minutes)
                        values (:email, :firstName, :lastName, 'irrelevant', :createdAt, 0)
                        returning id
                        """)
                .param("email", emailPrefix + System.nanoTime() + "@example.com")
                .param("firstName", "Test")
                .param("lastName", emailPrefix)
                .param("createdAt", OffsetDateTime.now())
                .query(Long.class)
                .single();
    }

    private long saveRelationship(long trainerUserId, long clientUserId, String status) {
        return jdbcClient.sql("""
                        insert into trainer_clients (trainer_id, client_id, status, created_at)
                        values (:trainerId, :clientId, :status, :createdAt)
                        returning id
                        """)
                .param("trainerId", trainerUserId)
                .param("clientId", clientUserId)
                .param("status", status)
                .param("createdAt", OffsetDateTime.now())
                .query(Long.class)
                .single();
    }

    /**
     * Mints exactly what lifey-api mints (§5.3): HS256 over the shared secret,
     * {@code sub}/{@code email}/{@code roles}/{@code iss}. Written out by hand
     * rather than reusing a helper, because <em>this claim shape is the
     * contract</em> between the two services — if lifey-api changes it, this
     * test is where the chat service finds out.
     */
    private String tokenFor(long userId) {
        SecretKey key = Keys.hmacShaKeyFor(jwtProperties.secret().getBytes(StandardCharsets.UTF_8));
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("email", "user" + userId + "@example.com")
                .claim("roles", List.of("ROLE_USER"))
                .issuer(jwtProperties.issuer())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(900)))
                .signWith(key)
                .compact();
    }
}
