package com.lifey.userdetails;

import com.lifey.userdetails.dto.SuggestGoalsRequest;
import com.lifey.userdetails.dto.SuggestGoalsResponse;

import java.time.LocalDate;
import java.time.Period;

/**
 * Suggested daily calorie/macro/water goals from onboarding biometrics.
 *
 * Methodology (see docs/21-onboarding-user-details-plan.md "Derived output" for the
 * full rationale and citations):
 * <ol>
 *     <li>BMR via Mifflin-St Jeor (most accurate general-purpose predictor per
 *     Frankenfield et al. 2005).</li>
 *     <li>TDEE = BMR x activity multiplier.</li>
 *     <li>Calorie target = TDEE +/- goal adjustment, clamped to an absolute kcal
 *     range and floored at a per-sex minimum safe intake.</li>
 *     <li>Protein in g/kg bodyweight (ISSN position stand / Helms et al.), not a
 *     fixed percentage of calories.</li>
 *     <li>Fat as a percentage of calories with a g/kg hormonal-health floor.</li>
 *     <li>Carbs fill the remaining calories.</li>
 *     <li>Water from a bodyweight formula plus an activity-level bonus.</li>
 * </ol>
 */
public final class GoalCalculator {

    private static final int MAX_DEFICIT_KCAL = 1000;
    private static final int MAX_SURPLUS_KCAL = 500;
    private static final int MIN_CALORIES_MALE = 1500;
    private static final int MIN_CALORIES_FEMALE = 1200;
    private static final int MIN_CALORIES_UNSPECIFIED = 1350;

    private static final double PROTEIN_G_PER_KG_LOSE = 2.2;
    private static final double PROTEIN_G_PER_KG_MAINTAIN = 1.6;
    private static final double PROTEIN_G_PER_KG_GAIN = 2.0;

    private static final double FAT_CALORIE_SHARE = 0.25;
    private static final double FAT_G_PER_KG_FLOOR = 0.6;

    private static final double WATER_ML_PER_KG = 35.0;

    private GoalCalculator() {
    }

    public static SuggestGoalsResponse suggest(SuggestGoalsRequest request) {
        double weightKg = request.weightKg();
        double heightCm = request.heightCm();
        int age = age(request.birthDate());

        double bmr = bmr(request.gender(), weightKg, heightCm, age);
        double tdee = bmr * request.activityLevel().getTdeeMultiplier();
        int calories = calorieTarget(tdee, request.primaryGoal(), request.gender());

        int proteinGrams = (int) Math.round(proteinGPerKg(request.primaryGoal()) * weightKg);
        int proteinKcal = proteinGrams * 4;

        int fatGrams = (int) Math.round(Math.max(
                FAT_CALORIE_SHARE * calories / 9.0,
                FAT_G_PER_KG_FLOOR * weightKg));
        int fatKcal = fatGrams * 9;

        int carbsGrams = (int) Math.round(Math.max(0, calories - proteinKcal - fatKcal) / 4.0);

        double waterLiters = roundToNearest(weightKg * WATER_ML_PER_KG + activityWaterBonusMl(request.activityLevel()), 50)
                / 1000.0;

        return new SuggestGoalsResponse(
                (int) Math.round(bmr),
                (int) Math.round(tdee),
                calories,
                proteinGrams,
                carbsGrams,
                fatGrams,
                Math.round(waterLiters * 10) / 10.0
        );
    }

    private static int age(LocalDate birthDate) {
        return Period.between(birthDate, LocalDate.now()).getYears();
    }

    private static double bmr(Gender gender, double weightKg, double heightCm, int age) {
        double base = 10 * weightKg + 6.25 * heightCm - 5 * age;
        return switch (gender) {
            case MALE -> base + 5;
            case FEMALE -> base - 161;
            case UNSPECIFIED -> base - 78; // average of the male (+5) and female (-161) offsets
        };
    }

    private static int calorieTarget(double tdee, PrimaryGoal goal, Gender gender) {
        double target = switch (goal) {
            case LOSE_WEIGHT -> tdee - Math.min(tdee * 0.15, MAX_DEFICIT_KCAL);
            case MAINTAIN -> tdee;
            case GAIN_MUSCLE -> tdee + Math.min(tdee * 0.10, MAX_SURPLUS_KCAL);
        };
        target = Math.max(target, minCalories(gender));
        return roundToNearest(target, 10);
    }

    private static int minCalories(Gender gender) {
        return switch (gender) {
            case MALE -> MIN_CALORIES_MALE;
            case FEMALE -> MIN_CALORIES_FEMALE;
            case UNSPECIFIED -> MIN_CALORIES_UNSPECIFIED;
        };
    }

    private static double proteinGPerKg(PrimaryGoal goal) {
        return switch (goal) {
            case LOSE_WEIGHT -> PROTEIN_G_PER_KG_LOSE;
            case MAINTAIN -> PROTEIN_G_PER_KG_MAINTAIN;
            case GAIN_MUSCLE -> PROTEIN_G_PER_KG_GAIN;
        };
    }

    private static double activityWaterBonusMl(ActivityLevel activityLevel) {
        return switch (activityLevel) {
            case SEDENTARY -> 0;
            case LIGHT -> 150;
            case MODERATE -> 300;
            case ACTIVE -> 500;
            case VERY_ACTIVE -> 750;
        };
    }

    private static int roundToNearest(double value, int step) {
        return (int) (Math.round(value / step) * step);
    }
}
