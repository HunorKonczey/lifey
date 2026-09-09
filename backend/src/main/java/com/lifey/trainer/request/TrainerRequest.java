package com.lifey.trainer.request;

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

/**
 * A user's request for {@code ROLE_TRAINER} (docs/landing_page/66-trainer-billing-web-plan.md
 * §2, D-T1) — role granting stays a super-admin action; this row is what the
 * super admin decides on. At most one {@code PENDING} row per user (V77's
 * partial unique index enforces it, not this class).
 */
@Getter
@Setter
@Entity
@Table(name = "trainer_request")
public class TrainerRequest extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private TrainerRequestStatus status;

    /** Free text from the request form; DB column is {@code text} (unbounded). */
    @Column
    private String motivation;

    @Column(name = "client_count")
    private Integer clientCount;

    /** Attribution captured again at request time — may differ from {@code User.signupSource} (65 D-W8). */
    @Column(name = "signup_source")
    private String signupSource;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "decided_at")
    private Instant decidedAt;

    /** The deciding super admin's user id; null while {@code PENDING}. */
    @Column(name = "decided_by")
    private Long decidedBy;
}
