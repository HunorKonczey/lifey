package com.lifey.progressphoto;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

/**
 * Metadata of one progress photo (docs/80). The bytes are in
 * {@link ProgressPhotoImage}, deliberately a separate entity with no
 * association from here, so loading the timeline never touches image data.
 */
@Getter
@Setter
@Entity
@Table(name = "progress_photos")
public class ProgressPhoto extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "taken_on", nullable = false)
    private LocalDate takenOn;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private PhotoPose pose;

    @Column(length = 500)
    private String note;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
