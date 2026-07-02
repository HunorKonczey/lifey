package com.lifey.auth;

import com.lifey.mail.MailService;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;

@Service
@Transactional
public class PasswordResetServiceImpl implements PasswordResetService {

    private static final Duration CODE_TTL = Duration.ofMinutes(15);
    private static final Duration RATE_LIMIT_WINDOW = Duration.ofHours(1);
    private static final int RATE_LIMIT_MAX_REQUESTS = 3;
    private static final int MAX_ATTEMPTS = 5;
    private static final String GENERIC_FAILURE_MESSAGE = "Invalid or expired code";

    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final MailService mailService;

    public PasswordResetServiceImpl(UserRepository userRepository,
                                    PasswordResetTokenRepository tokenRepository,
                                    RefreshTokenRepository refreshTokenRepository,
                                    PasswordEncoder passwordEncoder,
                                    MailService mailService) {
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.mailService = mailService;
    }

    @Override
    public void forgotPassword(String email) {
        userRepository.findByEmailIgnoreCase(email.trim()).ifPresent(this::issueResetCode);
    }

    /**
     * {@code noRollbackFor} is required here: on a wrong code this method throws
     * {@link InvalidResetCodeException}, and Spring's default policy rolls back
     * the whole transaction for any unchecked exception — which would silently
     * discard the {@code attempts} increment below and make the 5-attempt lockout
     * a no-op.
     */
    @Override
    @Transactional(noRollbackFor = InvalidResetCodeException.class)
    public void resetPassword(String email, String code, String newPassword) {
        User user = userRepository.findByEmailIgnoreCase(email.trim())
                .orElseThrow(() -> new InvalidResetCodeException(GENERIC_FAILURE_MESSAGE));

        PasswordResetToken token = tokenRepository
                .findFirstByUserIdAndUsedAtIsNullOrderByCreatedAtDesc(user.getId())
                .orElseThrow(() -> new InvalidResetCodeException(GENERIC_FAILURE_MESSAGE));

        if (token.isExpired() || token.getAttempts() >= MAX_ATTEMPTS) {
            throw new InvalidResetCodeException(GENERIC_FAILURE_MESSAGE);
        }

        if (!token.getCodeHash().equals(TokenHasher.hash(code))) {
            token.setAttempts(token.getAttempts() + 1);
            throw new InvalidResetCodeException(GENERIC_FAILURE_MESSAGE);
        }

        token.setUsedAt(Instant.now());
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        refreshTokenRepository.findAllByUserIdAndRevokedFalse(user.getId())
                .forEach(refreshToken -> refreshToken.setRevoked(true));
    }

    private void issueResetCode(User user) {
        Instant windowStart = Instant.now().minus(RATE_LIMIT_WINDOW);
        if (tokenRepository.countByUserIdAndCreatedAtAfter(user.getId(), windowStart) >= RATE_LIMIT_MAX_REQUESTS) {
            return;
        }

        tokenRepository.deleteByUserIdAndUsedAtIsNull(user.getId());

        String code = generateCode();
        PasswordResetToken token = new PasswordResetToken();
        token.setUser(user);
        token.setCodeHash(TokenHasher.hash(code));
        token.setExpiresAt(Instant.now().plus(CODE_TTL));
        token.setCreatedAt(Instant.now());
        tokenRepository.save(token);

        mailService.sendPasswordResetEmail(user, code);
    }

    private static String generateCode() {
        return String.format("%06d", RANDOM.nextInt(1_000_000));
    }
}
