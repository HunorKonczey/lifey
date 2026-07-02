package com.lifey.userdetails;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.time.LocalDate;

/**
 * Biometric/profile data collected at onboarding. One row per user. Current
 * weight is deliberately NOT here: weight history lives in weight_entries.
 */
@Getter
@Setter
@Entity
@Table(name = "user_details")
public class UserDetails extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "gender", nullable = false, length = 20)
    private Gender gender;

    @Column(name = "birth_date", nullable = false)
    private LocalDate birthDate;

    @Column(name = "height_cm", nullable = false)
    private double heightCm;

    @Enumerated(EnumType.STRING)
    @Column(name = "activity_level", nullable = false, length = 20)
    private ActivityLevel activityLevel;

    @Enumerated(EnumType.STRING)
    @Column(name = "primary_goal", nullable = false, length = 20)
    private PrimaryGoal primaryGoal;

    @Column(name = "target_weight_kg")
    private Double targetWeightKg;

    @Column(name = "onboarding_completed_at", nullable = false)
    private Instant onboardingCompletedAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        if (onboardingCompletedAt == null) {
            onboardingCompletedAt = now;
        }
        updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
