package com.lifey.trainer.entity;

import com.lifey.common.domain.BaseEntity;
import com.lifey.trainer.ContentType;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * The fact log of what a trainer assigned to a client — the source of a
 * trainer's "kiosztott tervek" view and the re-assignment warning (see
 * docs/personal_trainer/02-domain-es-migraciok.md, "Változás 3"). Distinct
 * from the {@code origin_source_id}/{@code origin_trainer_id} columns on the
 * copy itself: this table records the assignment action, those record the
 * copy's provenance.
 */
@Getter
@Setter
@Entity
@Table(name = "content_assignments")
public class ContentAssignment extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "trainer_id", nullable = false)
    private User trainer;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "client_id", nullable = false)
    private User client;

    @Enumerated(EnumType.STRING)
    @Column(name = "content_type", nullable = false, length = 16)
    private ContentType contentType;

    /** Not an FK: the trainer's original may be soft-deleted after the assignment. */
    @Column(name = "source_id", nullable = false)
    private Long sourceId;

    @Column(name = "copied_id", nullable = false)
    private Long copiedId;

    @Column(name = "assigned_at", nullable = false)
    private Instant assignedAt;
}
