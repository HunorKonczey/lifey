package com.lifey.chat;

import com.lifey.chat.controller.ChatConversationController;
import com.lifey.chat.dto.ChatPeerResponse;
import com.lifey.chat.dto.ChatPeerRole;
import com.lifey.chat.dto.ConversationListResponse;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.MessageResponse;
import com.lifey.chat.service.ChatService;
import com.lifey.chat.service.OpenConversationResult;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ChatConversationController.class)
class ChatConversationControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    ChatService chatService;

    @Test
    void list_returnsConversationsWithPeerAndUnreadCount() throws Exception {
        when(chatService.getConversations()).thenReturn(new ConversationListResponse(List.of(conversation())));

        mockMvc.perform(get("/api/v1/chat/conversations"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(12))
                .andExpect(jsonPath("$.items[0].peer.role").value("CLIENT"))
                .andExpect(jsonPath("$.items[0].peer.displayName").value("Kiss Anna"))
                .andExpect(jsonPath("$.items[0].unreadCount").value(2))
                .andExpect(jsonPath("$.items[0].lastMessage.body").value("Holnap 17:00 jó?"));
    }

    @Test
    void open_returnsCreatedForANewThread() throws Exception {
        when(chatService.openConversation(55L)).thenReturn(new OpenConversationResult(conversation(), true));

        mockMvc.perform(post("/api/v1/chat/conversations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"trainerClientId\":55}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(12));
    }

    @Test
    void open_returnsOkWhenTheThreadAlreadyExisted() throws Exception {
        when(chatService.openConversation(55L)).thenReturn(new OpenConversationResult(conversation(), false));

        mockMvc.perform(post("/api/v1/chat/conversations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"trainerClientId\":55}"))
                .andExpect(status().isOk());
    }

    @Test
    void open_withoutARelationshipId_isRejected() throws Exception {
        mockMvc.perform(post("/api/v1/chat/conversations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void openWithUser_usesThePeerUserIdEntryPoint() throws Exception {
        when(chatService.openConversationWithUser(88L)).thenReturn(new OpenConversationResult(conversation(), true));

        mockMvc.perform(post("/api/v1/chat/conversations/with-user/88"))
                .andExpect(status().isCreated());
    }

    @Test
    void markRead_returnsNoContent() throws Exception {
        mockMvc.perform(post("/api/v1/chat/conversations/12/read")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lastReadMessageId\":4310}"))
                .andExpect(status().isNoContent());

        verify(chatService).markRead(eq(12L), eq(4310L));
    }

    @Test
    void markRead_withoutACursor_isRejected() throws Exception {
        mockMvc.perform(post("/api/v1/chat/conversations/12/read")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    private static ConversationResponse conversation() {
        MessageResponse lastMessage = new MessageResponse(4310L, 12L, 7L, "Holnap 17:00 jó?", "a3f",
                Instant.parse("2026-08-02T09:12:44Z"), null);
        return new ConversationResponse(
                12L,
                new ChatPeerResponse(88L, "Kiss Anna", "anna@example.com", ChatPeerRole.CLIENT),
                lastMessage,
                2L,
                null);
    }
}
