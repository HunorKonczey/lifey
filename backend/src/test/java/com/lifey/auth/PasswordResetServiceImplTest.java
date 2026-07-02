package com.lifey.auth;

import com.lifey.mail.MailService;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PasswordResetServiceImplTest {

    @Mock
    UserRepository userRepository;

    @Mock
    PasswordResetTokenRepository tokenRepository;

    @Mock
    RefreshTokenRepository refreshTokenRepository;

    @Mock
    PasswordEncoder passwordEncoder;

    @Mock
    MailService mailService;

    private PasswordResetServiceImpl service;

    private PasswordResetServiceImpl service() {
        return new PasswordResetServiceImpl(userRepository, tokenRepository, refreshTokenRepository,
                passwordEncoder, mailService);
    }

    @Test
    void forgotPassword_unknownEmail_doesNothingButDoesNotThrow() {
        service = service();
        when(userRepository.findByEmailIgnoreCase("unknown@example.com")).thenReturn(Optional.empty());

        service.forgotPassword("unknown@example.com");

        verify(tokenRepository, never()).save(any());
        verify(mailService, never()).sendPasswordResetEmail(any(), any());
    }

    @Test
    void forgotPassword_knownEmail_invalidatesPreviousCodesAndSendsNewOne() {
        service = service();
        User user = user(1L, "user@example.com");
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(tokenRepository.countByUserIdAndCreatedAtAfter(eq(1L), any())).thenReturn(0L);

        service.forgotPassword("user@example.com");

        verify(tokenRepository).deleteByUserIdAndUsedAtIsNull(1L);
        verify(tokenRepository).save(any(PasswordResetToken.class));
        verify(mailService).sendPasswordResetEmail(eq(user), any());
    }

    @Test
    void forgotPassword_rateLimited_swallowsExtraRequest() {
        service = service();
        User user = user(1L, "user@example.com");
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(tokenRepository.countByUserIdAndCreatedAtAfter(eq(1L), any())).thenReturn(3L);

        service.forgotPassword("user@example.com");

        verify(tokenRepository, never()).save(any());
        verify(mailService, never()).sendPasswordResetEmail(any(), any());
    }

    @Test
    void resetPassword_happyPath_updatesPasswordMarksCodeUsedAndRevokesAllSessions() {
        service = service();
        User user = user(1L, "user@example.com");
        PasswordResetToken token = activeToken(user, "123456", Instant.now().plusSeconds(600), 0);
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(tokenRepository.findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(1L))
                .thenReturn(Optional.of(token));
        when(passwordEncoder.encode("newpassword123")).thenReturn("hashed-new-password");
        RefreshToken sessionA = session(user, false);
        RefreshToken sessionB = session(user, false);
        when(refreshTokenRepository.findAllByUserIdAndRevokedFalse(1L)).thenReturn(List.of(sessionA, sessionB));

        service.resetPassword("user@example.com", "123456", "newpassword123");

        assertThat(user.getPasswordHash()).isEqualTo("hashed-new-password");
        assertThat(token.isUsed()).isTrue();
        assertThat(sessionA.isRevoked()).isTrue();
        assertThat(sessionB.isRevoked()).isTrue();
    }

    @Test
    void resetPassword_unknownEmail_throwsGenericException() {
        service = service();
        when(userRepository.findByEmailIgnoreCase("unknown@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.resetPassword("unknown@example.com", "123456", "newpassword123"))
                .isInstanceOf(InvalidResetCodeException.class);
        verify(refreshTokenRepository, never()).findAllByUserIdAndRevokedFalse(anyLong());
    }

    @Test
    void resetPassword_expiredCode_throwsGenericException() {
        service = service();
        User user = user(1L, "user@example.com");
        PasswordResetToken token = activeToken(user, "123456", Instant.now().minus(1, ChronoUnit.MINUTES), 0);
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(tokenRepository.findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(1L))
                .thenReturn(Optional.of(token));

        assertThatThrownBy(() -> service.resetPassword("user@example.com", "123456", "newpassword123"))
                .isInstanceOf(InvalidResetCodeException.class);
        assertThat(user.getPasswordHash()).isNull();
    }

    @Test
    void resetPassword_noActiveCode_throwsGenericException() {
        service = service();
        User user = user(1L, "user@example.com");
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(tokenRepository.findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(1L))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.resetPassword("user@example.com", "123456", "newpassword123"))
                .isInstanceOf(InvalidResetCodeException.class);
    }

    @Test
    void resetPassword_wrongCode_incrementsAttemptsAndThrows() {
        service = service();
        User user = user(1L, "user@example.com");
        PasswordResetToken token = activeToken(user, "123456", Instant.now().plusSeconds(600), 0);
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(tokenRepository.findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(1L))
                .thenReturn(Optional.of(token));

        assertThatThrownBy(() -> service.resetPassword("user@example.com", "000000", "newpassword123"))
                .isInstanceOf(InvalidResetCodeException.class);
        assertThat(token.getAttempts()).isEqualTo(1);
        assertThat(token.isUsed()).isFalse();
    }

    @Test
    void resetPassword_attemptsExhausted_rejectsEvenCorrectCode() {
        service = service();
        User user = user(1L, "user@example.com");
        PasswordResetToken token = activeToken(user, "123456", Instant.now().plusSeconds(600), 5);
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(tokenRepository.findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(1L))
                .thenReturn(Optional.of(token));

        assertThatThrownBy(() -> service.resetPassword("user@example.com", "123456", "newpassword123"))
                .isInstanceOf(InvalidResetCodeException.class);
        assertThat(user.getPasswordHash()).isNull();
    }

    @Test
    void resetPassword_codeCannotBeReusedAfterSuccess() {
        service = service();
        User user = user(1L, "user@example.com");
        PasswordResetToken token = activeToken(user, "123456", Instant.now().plusSeconds(600), 0);
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(tokenRepository.findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(1L))
                .thenReturn(Optional.of(token), Optional.empty());
        when(refreshTokenRepository.findAllByUserIdAndRevokedFalse(1L)).thenReturn(List.of());

        service.resetPassword("user@example.com", "123456", "newpassword123");

        assertThatThrownBy(() -> service.resetPassword("user@example.com", "123456", "newpassword123"))
                .isInstanceOf(InvalidResetCodeException.class);
    }

    private static User user(Long id, String email) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        return user;
    }

    private static PasswordResetToken activeToken(User user, String code, Instant expiresAt, int attempts) {
        PasswordResetToken token = new PasswordResetToken();
        token.setUser(user);
        token.setCodeHash(TokenHasher.hash(code));
        token.setExpiresAt(expiresAt);
        token.setAttempts(attempts);
        token.setCreatedAt(Instant.now());
        return token;
    }

    private static RefreshToken session(User user, boolean revoked) {
        RefreshToken token = new RefreshToken();
        token.setUser(user);
        token.setTokenHash("hash-" + Math.random());
        token.setRevoked(revoked);
        token.setExpiresAt(Instant.now().plusSeconds(600));
        token.setCreatedAt(Instant.now());
        return token;
    }
}
