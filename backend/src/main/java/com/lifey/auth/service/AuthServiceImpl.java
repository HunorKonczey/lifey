package com.lifey.auth.service;

import com.lifey.auth.*;
import com.lifey.auth.dto.*;
import com.lifey.auth.entity.RefreshToken;
import com.lifey.auth.exception.*;
import com.lifey.auth.repository.RefreshTokenRepository;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.user.UserUtcOffsetUpdater;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Set;

@Service
@Transactional
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AuthenticationManager authenticationManager;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final CurrentUserProvider currentUserProvider;
    private final ApplicationEventPublisher eventPublisher;
    private final UserUtcOffsetUpdater userUtcOffsetUpdater;

    @Override
    public UserResponse register(RegisterRequest request, Integer utcOffsetMinutes) {
        String email = request.email().trim();
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new DuplicateResourceException("An account with email '" + email + "' already exists");
        }

        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setFirstName(request.firstName().trim());
        user.setLastName(request.lastName().trim());
        user.setCreatedAt(Instant.now());
        user.setRoles(Set.of(Role.ROLE_USER));
        userUtcOffsetUpdater.apply(user, utcOffsetMinutes);
        userRepository.save(user);
        eventPublisher.publishEvent(new UserRegisteredEvent(user.getId()));

        return toUserResponse(user);
    }

    @Override
    public AuthResponse login(LoginRequest request, Integer utcOffsetMinutes) {
        UserPrincipal principal;
        try {
            var authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.email().trim(), request.password()));
            principal = (UserPrincipal) authentication.getPrincipal();
        } catch (BadCredentialsException _) {
            // Same message regardless of whether the email exists, so login can't be
            // used to enumerate registered accounts.
            throw new InvalidCredentialsException("Invalid email or password");
        }
        if (principal == null) {
            // Authentication#getPrincipal() is nullable per its contract, though a
            // successful authenticate() call never actually returns one here in
            // practice — guard explicitly rather than let a raw NPE surface.
            throw new InvalidCredentialsException("Invalid email or password");
        }

        User user = userRepository.findById(principal.id())
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password"));
        userUtcOffsetUpdater.apply(user, utcOffsetMinutes);
        return issueTokenPair(user);
    }

    @Override
    public AuthResponse refresh(String rawRefreshToken, Integer utcOffsetMinutes) {
        RefreshToken token = refreshTokenRepository.findByTokenHash(TokenHasher.hash(rawRefreshToken))
                .orElseThrow(() -> new InvalidTokenException("Invalid refresh token"));

        if (token.isExpired()) {
            throw new TokenExpiredException("Refresh token expired");
        }
        if (token.isRevoked()) {
            // Rotation already consumed this value once - reuse suggests it leaked.
            // Revoking the whole family would be the next step; logging out the
            // single token is the conservative default until that's needed.
            throw new TokenRevokedException("Refresh token has been revoked");
        }

        token.setRevoked(true);
        userUtcOffsetUpdater.apply(token.getUser(), utcOffsetMinutes);
        return issueTokenPair(token.getUser());
    }

    @Override
    public void logout(String rawRefreshToken) {
        refreshTokenRepository.findByTokenHash(TokenHasher.hash(rawRefreshToken))
                .ifPresent(token -> token.setRevoked(true));
    }

    @Override
    public AuthResponse changePassword(ChangePasswordRequest request) {
        Long userId = currentUserProvider.getUserId();
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalStateException("Authenticated user " + userId + " not found"));

        if (!passwordEncoder.matches(request.currentPassword(), user.getPasswordHash())) {
            throw new IncorrectPasswordException("Current password is incorrect");
        }
        if (passwordEncoder.matches(request.newPassword(), user.getPasswordHash())) {
            throw new SamePasswordException("New password must be different from the current password");
        }

        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
        refreshTokenRepository.findAllByUserIdAndRevokedFalse(userId)
                .forEach(token -> token.setRevoked(true));

        return issueTokenPair(user);
    }

    @Override
    public void logoutAll() {
        Long userId = currentUserProvider.getUserId();
        refreshTokenRepository.findAllByUserIdAndRevokedFalse(userId)
                .forEach(token -> token.setRevoked(true));
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

    private UserResponse toUserResponse(User user) {
        return new UserResponse(
                user.getId(), user.getEmail(), user.getFirstName(), user.getLastName(),
                user.getRoles(), user.getCreatedAt());
    }
}
