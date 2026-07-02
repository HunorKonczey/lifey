package com.lifey.auth.entity;

import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * Links a Lifey {@link User} to a third-party identity (provider + stable
 * subject id) so a later login with the same provider account resolves back
 * to the same user, per docs/20-social-login-plan.md.
 */
@Getter
@Setter
@Entity
@Table(name = "user_identities")
public class UserIdentity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Provider provider;

    @Column(name = "provider_user_id", nullable = false)
    private String providerUserId;

    @Column
    private String email;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
}
