package com.lifey.chat;

import com.lifey.chat.controller.ChatMessageController;
import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.MessageResponse;
import com.lifey.chat.dto.SendMessageRequest;
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

    @Test
    void send_withABlankBody_isRejected() throws Exception {
        mockMvc.perform(post("/api/v1/chat/conversations/12/messages")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"body\":\"   \",\"clientMessageId\":\"a3f\"}"))
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
                Instant.parse("2026-08-02T09:12:44Z"), null);
    }
}
