package com.lifey.auth;

import com.lifey.auth.dto.AuthResponse;
import com.lifey.auth.dto.LoginRequest;
import com.lifey.auth.dto.RegisterRequest;
import com.lifey.auth.dto.UserResponse;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceImplTest {

    @Mock
    UserRepository userRepository;

    @Mock
    RefreshTokenRepository refreshTokenRepository;

    @Mock
    AuthenticationManager authenticationManager;

    @Mock
    PasswordEncoder passwordEncoder;

    @Mock
    JwtService jwtService;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    AuthServiceImpl authService;

    @Test
    void register_savesUserWithHashedPasswordAndDefaultRole() {
        RegisterRequest request = new RegisterRequest("new@example.com", "password123");
        when(userRepository.existsByEmailIgnoreCase("new@example.com")).thenReturn(false);
        when(passwordEncoder.encode("password123")).thenReturn("hashed-password");
        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        when(userRepository.save(captor.capture())).thenAnswer(inv -> {
            User saved = inv.getArgument(0);
            saved.setId(1L);
            return saved;
        });

        UserResponse response = authService.register(request);

        User saved = captor.getValue();
        assertThat(saved.getEmail()).isEqualTo("new@example.com");
        assertThat(saved.getPasswordHash()).isEqualTo("hashed-password");
        assertThat(saved.getRoles()).containsExactly(Role.ROLE_USER);
        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.email()).isEqualTo("new@example.com");
        assertThat(response.roles()).containsExactly(Role.ROLE_USER);
    }

    @Test
    void register_duplicateEmailThrowsAndDoesNotSave() {
        RegisterRequest request = new RegisterRequest("taken@example.com", "password123");
        when(userRepository.existsByEmailIgnoreCase("taken@example.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(request))
                .isInstanceOf(DuplicateResourceException.class);
        verify(userRepository, never()).save(any());
    }

    @Test
    void login_validCredentialsIssuesTokenPairAndPersistsRefreshToken() {
        LoginRequest request = new LoginRequest("user@example.com", "password123");
        User user = user(5L, "user@example.com", Role.ROLE_USER);
        UserPrincipal principal = UserPrincipal.from(user);
        when(authenticationManager.authenticate(any()))
                .thenReturn(new TestingAuthenticationToken(principal, null));
        when(userRepository.findById(5L)).thenReturn(Optional.of(user));
        when(jwtService.generateAccessToken(user)).thenReturn("access-token");
        when(jwtService.refreshTokenTtl()).thenReturn(Duration.ofDays(30));
        when(jwtService.accessTokenTtlSeconds()).thenReturn(900L);

        AuthResponse response = authService.login(request);

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.refreshToken()).isNotBlank();
        assertThat(response.expiresIn()).isEqualTo(900L);
        verify(refreshTokenRepository).save(any(RefreshToken.class));
    }

    @Test
    void login_badCredentialsThrowsInvalidCredentialsException() {
        LoginRequest request = new LoginRequest("user@example.com", "wrong-password");
        when(authenticationManager.authenticate(any())).thenThrow(new BadCredentialsException("bad"));

        assertThatThrownBy(() -> authService.login(request))
                .isInstanceOf(InvalidCredentialsException.class);
        verify(refreshTokenRepository, never()).save(any());
    }

    @Test
    void refresh_validTokenRevokesOldAndIssuesNewPair() {
        User user = user(5L, "user@example.com", Role.ROLE_USER);
        RefreshToken existing = refreshToken(user, false, Instant.now().plus(Duration.ofDays(1)));
        when(refreshTokenRepository.findByTokenHash(any())).thenReturn(Optional.of(existing));
        when(jwtService.generateAccessToken(user)).thenReturn("new-access-token");
        when(jwtService.refreshTokenTtl()).thenReturn(Duration.ofDays(30));
        when(jwtService.accessTokenTtlSeconds()).thenReturn(900L);

        AuthResponse response = authService.refresh("raw-refresh-token");

        assertThat(existing.isRevoked()).isTrue();
        assertThat(response.accessToken()).isEqualTo("new-access-token");
        assertThat(response.refreshToken()).isNotBlank();
        verify(refreshTokenRepository).save(any(RefreshToken.class));
    }

    @Test
    void refresh_unknownTokenThrowsInvalidTokenException() {
        when(refreshTokenRepository.findByTokenHash(any())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.refresh("unknown-token"))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void refresh_expiredTokenThrowsTokenExpiredException() {
        User user = user(5L, "user@example.com", Role.ROLE_USER);
        RefreshToken expired = refreshToken(user, false, Instant.now().minus(Duration.ofMinutes(1)));
        when(refreshTokenRepository.findByTokenHash(any())).thenReturn(Optional.of(expired));

        assertThatThrownBy(() -> authService.refresh("expired-token"))
                .isInstanceOf(TokenExpiredException.class);
        verify(refreshTokenRepository, never()).save(any());
    }

    @Test
    void refresh_revokedTokenThrowsTokenRevokedException() {
        User user = user(5L, "user@example.com", Role.ROLE_USER);
        RefreshToken revoked = refreshToken(user, true, Instant.now().plus(Duration.ofDays(1)));
        when(refreshTokenRepository.findByTokenHash(any())).thenReturn(Optional.of(revoked));

        assertThatThrownBy(() -> authService.refresh("revoked-token"))
                .isInstanceOf(TokenRevokedException.class);
        verify(refreshTokenRepository, never()).save(any());
    }

    @Test
    void logout_revokesMatchingToken() {
        User user = user(5L, "user@example.com", Role.ROLE_USER);
        RefreshToken token = refreshToken(user, false, Instant.now().plus(Duration.ofDays(1)));
        when(refreshTokenRepository.findByTokenHash(any())).thenReturn(Optional.of(token));

        authService.logout("raw-refresh-token");

        assertThat(token.isRevoked()).isTrue();
    }

    @Test
    void logout_unknownTokenIsANoOp() {
        when(refreshTokenRepository.findByTokenHash(any())).thenReturn(Optional.empty());

        authService.logout("unknown-token");
    }

    @Test
    void logoutAll_revokesEveryActiveTokenForCurrentUser() {
        User user = user(5L, "user@example.com", Role.ROLE_USER);
        RefreshToken tokenA = refreshToken(user, false, Instant.now().plus(Duration.ofDays(1)));
        RefreshToken tokenB = refreshToken(user, false, Instant.now().plus(Duration.ofDays(2)));
        when(currentUserProvider.getUserId()).thenReturn(5L);
        when(refreshTokenRepository.findAllByUserIdAndRevokedFalse(5L)).thenReturn(List.of(tokenA, tokenB));

        authService.logoutAll();

        assertThat(tokenA.isRevoked()).isTrue();
        assertThat(tokenB.isRevoked()).isTrue();
    }

    private static User user(Long id, String email, Role... roles) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        user.setPasswordHash("hashed");
        user.setCreatedAt(Instant.now());
        user.setRoles(Set.of(roles));
        return user;
    }

    private static RefreshToken refreshToken(User user, boolean revoked, Instant expiresAt) {
        RefreshToken token = new RefreshToken();
        token.setUser(user);
        token.setTokenHash("hash");
        token.setRevoked(revoked);
        token.setExpiresAt(expiresAt);
        token.setCreatedAt(Instant.now());
        return token;
    }
}
