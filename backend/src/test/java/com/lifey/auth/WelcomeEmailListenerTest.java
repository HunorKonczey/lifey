package com.lifey.auth;

import com.lifey.mail.service.MailService;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WelcomeEmailListenerTest {

    @Mock
    UserRepository userRepository;

    @Mock
    MailService mailService;

    @InjectMocks
    WelcomeEmailListener listener;

    @Test
    void onUserRegistered_sendsWelcomeEmailForCommittedUser() {
        User user = new User();
        user.setId(1L);
        user.setEmail("new@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        listener.onUserRegistered(new UserRegisteredEvent(1L));

        verify(mailService).sendWelcomeEmail(user);
    }

    @Test
    void onUserRegistered_userMissingIsANoOp() {
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        listener.onUserRegistered(new UserRegisteredEvent(1L));

        verify(mailService, never()).sendWelcomeEmail(any());
    }

    @Test
    void onUserRegistered_mailServiceThrows_isCaughtAndNotPropagated() {
        User user = new User();
        user.setId(1L);
        user.setEmail("new@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));
        doThrow(new RuntimeException("boom")).when(mailService).sendWelcomeEmail(user);

        assertThatCode(() -> listener.onUserRegistered(new UserRegisteredEvent(1L)))
                .doesNotThrowAnyException();
    }
}
