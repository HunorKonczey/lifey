package com.lifey.auth.service;

import com.lifey.auth.*;
import com.lifey.auth.dto.AuthResponse;
import com.lifey.auth.entity.Provider;
import com.lifey.auth.entity.RefreshToken;
import com.lifey.auth.entity.UserIdentity;
import com.lifey.auth.exception.UnverifiedEmailException;
import com.lifey.auth.repository.RefreshTokenRepository;
import com.lifey.auth.repository.UserIdentityRepository;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Set;

@Service
@Transactional
@RequiredArgsConstructor
public class SocialAuthServiceImpl implements SocialAuthService {

    private final GoogleIdTokenVerifier googleIdTokenVerifier;
    private final UserIdentityRepository userIdentityRepository;
    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final JwtService jwtService;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    public AuthResponse loginWithGoogle(String idToken) {
        GoogleIdentity identity = googleIdTokenVerifier.verify(idToken);

        User user = userIdentityRepository.findByProviderAndProviderUserId(Provider.GOOGLE, identity.sub())
                .map(UserIdentity::getUser)
                .orElseGet(() -> linkOrCreateUser(identity));

        return issueTokenPair(user);
    }

    private AuthResponse issueTokenPair(User user) {
        String accessToken = jwtService.generateAccessToken(user);
        String rawRefreshToken = TokenHasher.generateOpaqueToken();

        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setUser(user);
        refreshToken.setTokenHash(TokenHasher.hash(rawRefreshToken));
        refreshToken.setCreatedAt(Instant.now());
        refreshToken.setExpiresAt(Instant.now().plus(jwtService.refreshTokenTtl()));
        refreshTokenRepository.save(refreshToken);

        return new AuthResponse(accessToken, rawRefreshToken, jwtService.accessTokenTtlSeconds());
    }

    private User linkOrCreateUser(GoogleIdentity identity) {
        User user = userRepository.findByEmailIgnoreCase(identity.email())
                .map(existing -> requireVerified(existing, identity))
                .orElseGet(() -> createUser(identity));

        UserIdentity link = new UserIdentity();
        link.setUser(user);
        link.setProvider(Provider.GOOGLE);
        link.setProviderUserId(identity.sub());
        link.setEmail(identity.email());
        link.setCreatedAt(Instant.now());
        userIdentityRepository.save(link);

        return user;
    }

    private User requireVerified(User existing, GoogleIdentity identity) {
        if (!identity.emailVerified()) {
            throw new UnverifiedEmailException("Email is not verified by the provider");
        }
        return existing;
    }

    private User createUser(GoogleIdentity identity) {
        User user = new User();
        user.setEmail(identity.email());
        user.setCreatedAt(Instant.now());
        user.setRoles(Set.of(Role.ROLE_USER));
        userRepository.save(user);
        eventPublisher.publishEvent(new UserRegisteredEvent(user.getId()));
        return user;
    }
}
