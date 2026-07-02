package com.lifey.auth.entity;

import com.lifey.auth.TokenHasher;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * A single-use, 15-minute password reset code. Only the SHA-256 hash of the
 * 6-digit code is stored ({@link #codeHash}, via {@link TokenHasher}) so a
 * database leak alone can't be used to reset a password. {@link #attempts}
 * caps guessing at 5 tries before the code is burned.
 */
@Getter
@Setter
@Entity
@Table(name = "password_reset_tokens")
public class PasswordResetToken {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "code_hash", nullable = false)
    private String codeHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "used_at")
    private Instant usedAt;

    @Column(nullable = false)
    private int attempts = 0;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    public boolean isExpired() {
        return expiresAt.isBefore(Instant.now());
    }

    public boolean isUsed() {
        return usedAt != null;
    }
}
