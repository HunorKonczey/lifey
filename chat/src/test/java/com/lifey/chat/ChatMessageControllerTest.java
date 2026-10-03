package com.lifey.chat;

import com.lifey.chat.controller.ChatMessageController;
import com.lifey.chat.dto.MessageCard;
import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.MessageResponse;
import com.lifey.chat.dto.SendMessageRequest;
import com.lifey.chat.exception.InvalidMessageBodyException;
import com.lifey.chat.service.ChatService;
import com.lifey.chat.service.SendMessageResult;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ChatMessageController.class)
class ChatMessageControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    ChatService chatService;

    @Test
    void list_passesTheKeysetCursorsThrough() throws Exception {
        when(chatService.listMessages(eq(12L), eq(4310L), isNull(), eq(30)))
                .thenReturn(new MessageListResponse(List.of(message()), true));

        mockMvc.perform(get("/api/v1/chat/conversations/12/messages?before=4310&limit=30"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(4310))
                .andExpect(jsonPath("$.hasMore").value(true));
    }

    @Test
    void list_withoutCursors_returnsTheNewestPage() throws Exception {
        when(chatService.listMessages(eq(12L), isNull(), isNull(), isNull()))
                .thenReturn(new MessageListResponse(List.of(message()), false));

        mockMvc.perform(get("/api/v1/chat/conversations/12/messages"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.hasMore").value(false));
    }

    @Test
    void send_returnsCreatedForANewMessage() throws Exception {
        when(chatService.sendMessage(eq(12L), any(SendMessageRequest.class)))
                .thenReturn(new SendMessageResult(message(), true));

        mockMvc.perform(post("/api/v1/chat/conversations/12/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"body\":\"Holnap 17:00 jó?\",\"clientMessageId\":\"a3f\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.clientMessageId").value("a3f"));
    }

    @Test
    void send_returnsOkWhenTheClientMessageIdWasAlreadyStored() throws Exception {
        when(chatService.sendMessage(eq(12L), any(SendMessageRequest.class)))
                .thenReturn(new SendMessageResult(message(), false));

        mockMvc.perform(post("/api/v1/chat/conversations/12/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"body\":\"Holnap 17:00 jó?\",\"clientMessageId\":\"a3f\"}"))
                .andExpect(status().isOk());
    }

    /**
     * "Body or card" is the service's rule now — the body alone is no longer
     * {@code @NotBlank}, because a card is a complete message without one. The
     * 400 comes from the service's own exception, mapped by the chat advice.
     */
    @Test
    void send_withABlankBodyAndNoCard_isRejectedByTheService() throws Exception {
        when(chatService.sendMessage(eq(12L), any(SendMessageRequest.class)))
                .thenThrow(new InvalidMessageBodyException("Message body must not be blank"));

        mockMvc.perform(post("/api/v1/chat/conversations/12/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"body\":\"   \",\"clientMessageId\":\"a3f\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void send_withACardAndNoBody_isAccepted_andTheCardComesBack() throws Exception {
        when(chatService.sendMessage(eq(12L), any(SendMessageRequest.class)))
                .thenReturn(new SendMessageResult(cardMessage(), true));

        mockMvc.perform(post("/api/v1/chat/conversations/12/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientMessageId\":\"a3f\",\"card\":{\"kind\":\"PR\",\"sessionId\":481,"
                                + "\"occurredAt\":\"2026-10-03T07:12:00Z\",\"pr\":{\"exerciseName\":\"Bench press\","
                                + "\"prType\":\"MAX_WEIGHT\",\"value\":102.5,\"previousValue\":100,"
                                + "\"weightKg\":102.5,\"reps\":3}}}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.card.kind").value("PR"))
                .andExpect(jsonPath("$.card.sessionId").value(481))
                .andExpect(jsonPath("$.card.pr.exerciseName").value("Bench press"))
                .andExpect(jsonPath("$.card.pr.value").value(102.5))
                .andExpect(jsonPath("$.card.occurredAt").value("2026-10-03T07:12:00Z"));
    }

    @Test
    void send_withACardOutsideItsBounds_isRejectedBeforeTheService() throws Exception {
        // Negative duration: caught by bean validation on the nested record.
        mockMvc.perform(post("/api/v1/chat/conversations/12/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientMessageId\":\"a3f\",\"card\":{\"kind\":\"WORKOUT\","
                                + "\"occurredAt\":\"2026-10-03T07:12:00Z\",\"workout\":{\"workoutKind\":\"STRENGTH\","
                                + "\"durationSeconds\":-5}}}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void send_withACardWithoutAKind_isRejected() throws Exception {
        mockMvc.perform(post("/api/v1/chat/conversations/12/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"clientMessageId\":\"a3f\",\"card\":{\"occurredAt\":\"2026-10-03T07:12:00Z\"}}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void send_withoutAClientMessageId_isRejected() throws Exception {
        mockMvc.perform(post("/api/v1/chat/conversations/12/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"body\":\"hi\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/chat/messages/4310"))
                .andExpect(status().isNoContent());

        verify(chatService).deleteMessage(4310L);
    }

    private static MessageResponse message() {
        return new MessageResponse(4310L, 12L, 7L, "Holnap 17:00 jó?", "a3f",
                Instant.parse("2026-08-02T09:12:44Z"), null, null, null);
    }

    private static MessageResponse cardMessage() {
        MessageCard card = new MessageCard(MessageCard.Kind.PR, 481L, Instant.parse("2026-10-03T07:12:00Z"), null,
                new MessageCard.Pr("Bench press", MessageCard.PrType.MAX_WEIGHT, 102.5, 100.0, 102.5, 3));
        return new MessageResponse(4311L, 12L, 7L, null, "a3f",
                Instant.parse("2026-10-03T07:13:00Z"), null, null, card);
    }
}
