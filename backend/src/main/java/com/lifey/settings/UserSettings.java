package com.lifey.settings;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * One row per user, created lazily (with defaults) on first access rather than
 * at registration time, so the auth module stays unaware of this feature.
 */
@Getter
@Setter
@Entity
@Table(name = "user_settings")
public class UserSettings extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "unit_system", nullable = false, length = 20)
    private UnitSystem unitSystem = UnitSystem.METRIC;

    @Column(name = "daily_calorie_goal")
    private Integer dailyCalorieGoal;

    @Column(name = "daily_protein_goal")
    private Integer dailyProteinGoal;

    @Column(name = "daily_carbs_goal")
    private Integer dailyCarbsGoal;

    @Column(name = "daily_fat_goal")
    private Integer dailyFatGoal;

    @Column(name = "daily_water_goal_liters")
    private Double dailyWaterGoalLiters;

    @Column(name = "daily_step_goal")
    private Integer dailyStepGoal;

    @Enumerated(EnumType.STRING)
    @Column(name = "theme", nullable = false, length = 20)
    private ThemePreference theme = ThemePreference.SYSTEM;

    @Enumerated(EnumType.STRING)
    @Column(name = "language", nullable = false, length = 20)
    private LanguagePreference language = LanguagePreference.SYSTEM;
}
