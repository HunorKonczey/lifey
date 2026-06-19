package com.lifey.auth;

import com.lifey.auth.dto.AuthResponse;
import com.lifey.auth.dto.LoginRequest;
import com.lifey.auth.dto.RegisterRequest;
import com.lifey.auth.dto.UserResponse;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
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
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final AuthenticationManager authenticationManager;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final CurrentUserProvider currentUserProvider;

    public AuthServiceImpl(UserRepository userRepository,
                           RefreshTokenRepository refreshTokenRepository,
                           AuthenticationManager authenticationManager,
                           PasswordEncoder passwordEncoder,
                           JwtService jwtService,
                           CurrentUserProvider currentUserProvider) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.authenticationManager = authenticationManager;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    public UserResponse register(RegisterRequest request) {
        String email = request.email().trim();
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new DuplicateResourceException("An account with email '" + email + "' already exists");
        }

        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setCreatedAt(Instant.now());
        user.setRoles(Set.of(Role.ROLE_USER));
        userRepository.save(user);

        return toUserResponse(user);
    }

    @Override
    public AuthResponse login(LoginRequest request) {
        UserPrincipal principal;
        try {
            var authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.email().trim(), request.password()));
            principal = (UserPrincipal) authentication.getPrincipal();
        } catch (BadCredentialsException ex) {
            // Same message regardless of whether the email exists, so login can't be
            // used to enumerate registered accounts.
            throw new InvalidCredentialsException("Invalid email or password");
        }

        User user = userRepository.findById(principal.id())
                .orElseThrow(() -> new InvalidCredentialsException("Invalid email or password"));
        return issueTokenPair(user);
    }

    @Override
    public AuthResponse refresh(String rawRefreshToken) {
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
        return issueTokenPair(token.getUser());
    }

    @Override
    public void logout(String rawRefreshToken) {
        refreshTokenRepository.findByTokenHash(TokenHasher.hash(rawRefreshToken))
                .ifPresent(token -> token.setRevoked(true));
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
        return new UserResponse(user.getId(), user.getEmail(), user.getRoles(), user.getCreatedAt());
    }
}
