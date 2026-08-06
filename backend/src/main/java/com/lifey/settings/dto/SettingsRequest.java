package com.lifey.settings.dto;

import com.lifey.settings.LanguagePreference;
import com.lifey.settings.ThemePreference;
import com.lifey.settings.UnitSystem;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.LocalTime;

public record SettingsRequest(

        @NotNull
        UnitSystem unitSystem,

        @PositiveOrZero
        Integer dailyCalorieGoal,

        @PositiveOrZero
        Integer dailyProteinGoal,

        @PositiveOrZero
        Integer dailyCarbsGoal,

        @PositiveOrZero
        Integer dailyFatGoal,

        @PositiveOrZero
        Double dailyWaterGoalLiters,

        @Positive
        Integer dailyStepGoal,

        @NotNull
        ThemePreference theme,

        @NotNull
        LanguagePreference language,

        @NotNull
        Boolean workoutReminderEnabled,

        @NotNull
        Boolean trainerCommentPushEnabled,

        @NotNull
        Boolean trainerGoalsPushEnabled,

        @NotNull
        Boolean programAssignedPushEnabled,

        /**
         * Nullable on purpose, unlike the push flags above: this field was
         * added after clients were already in the wild, and a {@code @NotNull}
         * would 400 every settings save coming from an app version that
         * predates it. Absent means "leave whatever is stored alone"
         * (docs/chat/40-trainer-chat-plan.md, I2).
         */
        Boolean chatPushEnabled,

        /**
         * Local-time window in which chat pushes are held back (§5.4). Nullable
         * for the same reason as {@code chatPushEnabled} — and additionally
         * because "no quiet hours" is itself a valid stored state, which is why
         * {@code chatQuietHoursSet} exists rather than treating null as "leave
         * alone" here.
         */
        LocalTime chatQuietHoursStart,

        LocalTime chatQuietHoursEnd,

        /**
         * Distinguishes "this client doesn't know about quiet hours" (absent →
         * leave the stored window alone) from "the user cleared their window"
         * (present and false → wipe it). Without it, an older app version's
         * save would silently delete a window set from the web, and a user
         * turning quiet hours off could never be told apart from an old client.
         */
        Boolean chatQuietHoursSet,

        @NotNull
        Boolean restTimerEnabled,

        @NotNull
        @Min(15)
        @Max(600)
        Integer defaultRestSeconds
) {
}
