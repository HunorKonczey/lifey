package com.lifey.user;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

@Getter
@Setter
@Entity
@Table(name = "users")
public class User extends BaseEntity {

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "first_name")
    private String firstName;

    @Column(name = "last_name")
    private String lastName;

    /**
     * BCrypt hash; never the plaintext password. Named distinctly from a generic
     * "password" field so it's obvious at every call site that this is a hash.
     */
    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    /**
     * Minutes east of UTC (e.g. Budapest summer time = 120), refreshed from the
     * client on every register/login/refresh so day-boundary calculations (meal
     * lists, statistics) can use the user's own local day instead of the server's.
     */
    @Column(name = "utc_offset_minutes", nullable = false)
    private int utcOffsetMinutes = 0;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "user_roles", joinColumns = @JoinColumn(name = "user_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 20)
    private Set<Role> roles = new HashSet<>();
}
