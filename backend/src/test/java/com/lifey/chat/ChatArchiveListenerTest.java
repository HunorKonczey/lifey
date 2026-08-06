package com.lifey.chat;

import com.lifey.chat.service.ChatService;
import com.lifey.trainer.TrainerClientRevokedEvent;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

import static org.mockito.Mockito.verify;

/**
 * The listener itself is trivial; what's worth pinning down is that it really
 * is subscribed to {@link TrainerClientRevokedEvent} — an archive that silently
 * stops firing would leave revoked relationships writable.
 */
@ExtendWith(MockitoExtension.class)
class ChatArchiveListenerTest {

    @Mock
    ChatService chatService;

    @InjectMocks
    ChatArchiveListener listener;

    @Test
    void onTrainerClientRevoked_archivesThePairsThread() {
        listener.onTrainerClientRevoked(new TrainerClientRevokedEvent(1L, 2L));

        verify(chatService).archiveForPair(1L, 2L);
    }

    @Test
    void isRegisteredAsAnEventListener() {
        try (AnnotationConfigApplicationContext context = new AnnotationConfigApplicationContext()) {
            context.registerBean(ChatService.class, () -> chatService);
            context.register(ChatArchiveListener.class);
            context.refresh();

            context.publishEvent(new TrainerClientRevokedEvent(3L, 4L));

            verify(chatService).archiveForPair(3L, 4L);
        }
    }
}
