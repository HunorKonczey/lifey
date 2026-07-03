package com.lifey.user;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "user_avatars")
public class UserAvatar extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    // Deliberately not @Lob: on PostgreSQL that maps byte[] to oid (a large
    // object reference), not bytea. Plain byte[] maps to bytea directly,
    // matching the Flyway column type — see V39__user_avatars.sql.
    @Column(nullable = false)
    private byte[] image;

    @Column(name = "content_type", nullable = false, length = 50)
    private String contentType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AvatarSource source;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
