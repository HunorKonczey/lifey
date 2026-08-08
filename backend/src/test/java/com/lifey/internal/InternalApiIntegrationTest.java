package com.lifey.internal;

import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The service-to-service seam, through the real filter chain
 * (docs/chat/44-chat-service-extraction-plan.md §5.5, §6.1).
 *
 * <p>What matters here is that {@code /internal/**} is reachable <em>only</em>
 * with the shared secret and reachable <em>without</em> a user token — it is
 * governed by its own filter chain, ahead of the JWT one, and getting that
 * ordering wrong in either direction is a security bug rather than a bug.
 */
@SpringBootTest(properties = "lifey.internal.token=" + InternalApiIntegrationTest.SECRET)
@AutoConfigureMockMvc
@Testcontainers
class InternalApiIntegrationTest {

    static final String SECRET = "integration-test-internal-secret";

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    PushService pushService;

    @Test
    void aPushWithTheSharedSecretIsAccepted_withNoUserTokenAtAll() throws Exception {
        mockMvc.perform(post("/internal/push")
                        .header(InternalAuthFilter.TOKEN_HEADER, SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"userId":42,"title":"Nagy Péter","body":"Holnap 17:00 jó?",
                                 "data":{"type":"chat_message","conversationId":"7"},
                                 "collapseKey":"chat-7"}
                                """))
                // 202, not 200: accepted for delivery is all this can honestly say.
                .andExpect(status().isAccepted());

        var captor = org.mockito.ArgumentCaptor.forClass(PushMessage.class);
        verify(pushService).sendToUser(eq(42L), captor.capture());
        assertThat(captor.getValue().title()).isEqualTo("Nagy Péter");
        assertThat(captor.getValue().collapseKey()).isEqualTo("chat-7");
        assertThat(captor.getValue().data()).containsEntry("type", "chat_message");
    }

    @Test
    void aPushWithoutTheSecretIsRejected_andSendsNothing() throws Exception {
        mockMvc.perform(post("/internal/push")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":42,\"title\":\"t\",\"body\":\"b\"}"))
                .andExpect(status().isUnauthorized());

        verify(pushService, never()).sendToUser(org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.any());
    }

    @Test
    void aPushWithTheWrongSecretIsRejected() throws Exception {
        mockMvc.perform(post("/internal/push")
                        .header(InternalAuthFilter.TOKEN_HEADER, "wrong")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userId\":42,\"title\":\"t\",\"body\":\"b\"}"))
                .andExpect(status().isUnauthorized());

        verify(pushService, never()).sendToUser(org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.any());
    }

    @Test
    void anInvalidBodyIsAFourHundred_notAnAcceptedNoOp() throws Exception {
        // Past the secret, so this exercises the validation rather than the
        // filter: a caller that gets the wire format wrong must find out.
        mockMvc.perform(post("/internal/push")
                        .header(InternalAuthFilter.TOKEN_HEADER, SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"no user id\",\"body\":\"b\"}"))
                .andExpect(status().isBadRequest());
    }
}
