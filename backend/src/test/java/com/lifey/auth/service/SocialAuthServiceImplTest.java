package com.lifey.auth.service;

import com.lifey.auth.GoogleAvatarCandidateEvent;
import com.lifey.auth.GoogleIdTokenVerifier;
import com.lifey.auth.GoogleIdentity;
import com.lifey.auth.JwtService;
import com.lifey.auth.UserRegisteredEvent;
import com.lifey.auth.dto.AuthResponse;
import com.lifey.auth.entity.Provider;
import com.lifey.auth.entity.UserIdentity;
import com.lifey.auth.exception.UnverifiedEmailException;
import com.lifey.auth.repository.RefreshTokenRepository;
import com.lifey.auth.repository.UserIdentityRepository;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import java.time.Duration;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SocialAuthServiceImplTest {

    private static final String ID_TOKEN = "google-id-token";
    private static final String SUB = "google-user-123";

    @Mock
    GoogleIdTokenVerifier googleIdTokenVerifier;

    @Mock
    UserIdentityRepository userIdentityRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    RefreshTokenRepository refreshTokenRepository;

    @Mock
    JwtService jwtService;

    @Mock
    ApplicationEventPublisher eventPublisher;

    @InjectMocks
    SocialAuthServiceImpl socialAuthService;

    @Test
    void loginWithGoogle_existingIdentity_logsInWithoutTouchingUserOrIdentityTables() {
        User user = existingUser(7L, "user@example.com");
        UserIdentity link = new UserIdentity();
        link.setUser(user);

        when(googleIdTokenVerifier.verify(ID_TOKEN))
                .thenReturn(new GoogleIdentity(SUB, "user@example.com", true, null, "Jane", "Doe"));
        when(userIdentityRepository.findByProviderAndProviderUserId(Provider.GOOGLE, SUB))
                .thenReturn(Optional.of(link));
        stubTokenIssuance(user);

        AuthResponse response = socialAuthService.loginWithGoogle(ID_TOKEN);

        assertThat(response.accessToken()).isEqualTo("access-token");
        verify(userRepository, never()).save(any());
        verify(userIdentityRepository, never()).save(any());
    }

    @Test
    void loginWithGoogle_noIdentityNoUser_createsUserAndIdentityAndPublishesEvent() {
        when(googleIdTokenVerifier.verify(ID_TOKEN))
                .thenReturn(new GoogleIdentity(SUB, "new@example.com", true, null, "Jane", "Doe"));
        when(userIdentityRepository.findByProviderAndProviderUserId(Provider.GOOGLE, SUB))
                .thenReturn(Optional.empty());
        when(userRepository.findByEmailIgnoreCase("new@example.com")).thenReturn(Optional.empty());

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        when(userRepository.save(userCaptor.capture())).thenAnswer(inv -> {
            User saved = inv.getArgument(0);
            saved.setId(9L);
            return saved;
        });
        ArgumentCaptor<UserIdentity> identityCaptor = ArgumentCaptor.forClass(UserIdentity.class);
        when(userIdentityRepository.save(identityCaptor.capture())).thenAnswer(inv -> inv.getArgument(0));
        stubTokenIssuance(null);

        socialAuthService.loginWithGoogle(ID_TOKEN);

        User created = userCaptor.getValue();
        assertThat(created.getEmail()).isEqualTo("new@example.com");
        assertThat(created.getPasswordHash()).isNull();
        assertThat(created.getFirstName()).isEqualTo("Jane");
        assertThat(created.getLastName()).isEqualTo("Doe");
        assertThat(created.getRoles()).containsExactly(Role.ROLE_USER);

        UserIdentity savedLink = identityCaptor.getValue();
        assertThat(savedLink.getProvider()).isEqualTo(Provider.GOOGLE);
        assertThat(savedLink.getProviderUserId()).isEqualTo(SUB);
        assertThat(savedLink.getUser()).isSameAs(created);

        verify(eventPublisher).publishEvent(any(UserRegisteredEvent.class));
    }

    @Test
    void loginWithGoogle_pictureClaimPresent_publishesAvatarCandidateEventWithResolvedUserId() {
        User user = existingUser(7L, "user@example.com");
        UserIdentity link = new UserIdentity();
        link.setUser(user);

        when(googleIdTokenVerifier.verify(ID_TOKEN))
                .thenReturn(new GoogleIdentity(SUB, "user@example.com", true, "https://example.com/pic.jpg", "Jane", "Doe"));
        when(userIdentityRepository.findByProviderAndProviderUserId(Provider.GOOGLE, SUB))
                .thenReturn(Optional.of(link));
        stubTokenIssuance(user);

        socialAuthService.loginWithGoogle(ID_TOKEN);

        ArgumentCaptor<GoogleAvatarCandidateEvent> captor = ArgumentCaptor.forClass(GoogleAvatarCandidateEvent.class);
        verify(eventPublisher).publishEvent(captor.capture());
        assertThat(captor.getValue().userId()).isEqualTo(7L);
        assertThat(captor.getValue().pictureUrl()).isEqualTo("https://example.com/pic.jpg");
    }

    @Test
    void loginWithGoogle_noIdentityVerifiedEmailMatchesExistingUser_linksWithoutCreatingUser() {
        User existing = existingUser(3L, "user@example.com");

        when(googleIdTokenVerifier.verify(ID_TOKEN))
                .thenReturn(new GoogleIdentity(SUB, "user@example.com", true, null, "Jane", "Doe"));
        when(userIdentityRepository.findByProviderAndProviderUserId(Provider.GOOGLE, SUB))
                .thenReturn(Optional.empty());
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(existing));

        ArgumentCaptor<UserIdentity> identityCaptor = ArgumentCaptor.forClass(UserIdentity.class);
        when(userIdentityRepository.save(identityCaptor.capture())).thenAnswer(inv -> inv.getArgument(0));
        stubTokenIssuance(existing);

        socialAuthService.loginWithGoogle(ID_TOKEN);

        verify(userRepository, never()).save(any());
        verify(eventPublisher, never()).publishEvent(any());
        assertThat(identityCaptor.getValue().getUser()).isSameAs(existing);
    }

    @Test
    void loginWithGoogle_noIdentityUnverifiedEmailMatchesExistingUser_rejectsWithoutLinking() {
        User existing = existingUser(3L, "user@example.com");

        when(googleIdTokenVerifier.verify(ID_TOKEN))
                .thenReturn(new GoogleIdentity(SUB, "user@example.com", false, null, "Jane", "Doe"));
        when(userIdentityRepository.findByProviderAndProviderUserId(Provider.GOOGLE, SUB))
                .thenReturn(Optional.empty());
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> socialAuthService.loginWithGoogle(ID_TOKEN))
                .isInstanceOf(UnverifiedEmailException.class);

        verify(userIdentityRepository, never()).save(any());
        verify(refreshTokenRepository, never()).save(any());
    }

    private User existingUser(Long id, String email) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        user.setRoles(Set.of(Role.ROLE_USER));
        return user;
    }

    private void stubTokenIssuance(User ignoredUser) {
        when(jwtService.generateAccessToken(any())).thenReturn("access-token");
        when(jwtService.refreshTokenTtl()).thenReturn(Duration.ofDays(30));
        when(jwtService.accessTokenTtlSeconds()).thenReturn(900L);
    }
}
