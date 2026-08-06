package com.lifey.chat;

import com.jayway.jsonpath.JsonPath;
import com.lifey.auth.service.JwtService;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
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
class ChatFlowIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JwtService jwtService;

    @Autowired
    UserRepository userRepository;

    @Autowired
    TrainerClientRepository trainerClientRepository;

    @Autowired
    ChatConversationRepository conversationRepository;

    User trainer;
    User client;
    User stranger;
    TrainerClient relationship;
    String trainerToken;
    String clientToken;
    String strangerToken;

    @BeforeEach
    void seed() {
        trainer = saveUser("chat-trainer-", Role.ROLE_USER, Role.ROLE_TRAINER);
        client = saveUser("chat-client-", Role.ROLE_USER);
        stranger = saveUser("chat-stranger-", Role.ROLE_USER);
        relationship = saveRelationship(trainer, client, TrainerClientStatus.ACTIVE);

        trainerToken = jwtService.generateAccessToken(trainer);
        clientToken = jwtService.generateAccessToken(client);
        strangerToken = jwtService.generateAccessToken(stranger);
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
                .andExpect(jsonPath("$.items[0].peer.userId").value(client.getId()))
                // The sender's own message never counts as unread for them.
                .andExpect(jsonPath("$.items[0].unreadCount").value(0));

        mockMvc.perform(get("/api/v1/chat/conversations").header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].peer.role").value("TRAINER"))
                .andExpect(jsonPath("$.items[0].peer.userId").value(trainer.getId()))
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
    void revokingTheRelationshipArchivesTheThreadAndBlocksNewMessages() throws Exception {
        long conversationId = openConversation();
        send(conversationId, trainerToken, "Szia!", "trainer-msg-1");

        mockMvc.perform(delete("/api/v1/trainer/clients/" + client.getId())
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(status().isNoContent());

        send(conversationId, trainerToken, "Még egy", "trainer-msg-2")
                .andExpect(status().isConflict());

        // Read access survives — the history belongs to both of them (§1.3/1).
        mockMvc.perform(get("/api/v1/chat/conversations/" + conversationId + "/messages")
                        .header("Authorization", "Bearer " + clientToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1));

        assertThat(conversationRepository.findById(conversationId))
                .get()
                .satisfies(conversation -> assertThat(conversation.getArchivedAt()).isNotNull());
    }

    @Test
    void openingAConversationIsIdempotent() throws Exception {
        long first = openConversation();

        mockMvc.perform(post("/api/v1/chat/conversations")
                        .header("Authorization", "Bearer " + clientToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"trainerClientId\":" + relationship.getId() + "}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(first));
    }

    @Test
    void openingWithAPeerUserIdWorksFromEitherSide() throws Exception {
        mockMvc.perform(post("/api/v1/chat/conversations/with-user/" + client.getId())
                        .header("Authorization", "Bearer " + trainerToken))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/api/v1/chat/conversations/with-user/" + trainer.getId())
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

        mockMvc.perform(post("/api/v1/chat/conversations/with-user/" + client.getId())
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

    // --- helpers -----------------------------------------------------------

    private long openConversation() throws Exception {
        String body = mockMvc.perform(post("/api/v1/chat/conversations")
                        .header("Authorization", "Bearer " + trainerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"trainerClientId\":" + relationship.getId() + "}"))
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

    private User saveUser(String emailPrefix, Role... roles) {
        User user = new User();
        user.setEmail(emailPrefix + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(roles)));
        return userRepository.save(user);
    }

    private TrainerClient saveRelationship(User trainerUser, User clientUser, TrainerClientStatus status) {
        TrainerClient link = new TrainerClient();
        link.setTrainer(trainerUser);
        link.setClient(clientUser);
        link.setStatus(status);
        link.setCreatedAt(Instant.now());
        link.setExpiresAt(Instant.now().plusSeconds(86_400));
        link.setRespondedAt(Instant.now());
        return trainerClientRepository.save(link);
    }
}
