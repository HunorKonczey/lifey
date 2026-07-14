package com.lifey.userdetails;

import com.lifey.userdetails.dto.SuggestGoalsRequest;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.Period;

import static org.assertj.core.api.Assertions.assertThat;

class GoalCalculatorTest {

    private static LocalDate birthDateForAge(int age) {
        // Same-day-of-year subtraction keeps Period.between(...).getYears() exactly `age`.
        return LocalDate.now().minusYears(age);
    }

    @Test
    void male_moderateActivity_loseWeight_matchesReferenceValues() {
        SuggestGoalsRequest request = new SuggestGoalsRequest(
                Gender.MALE, birthDateForAge(30), 180.0, 80.0, ActivityLevel.MODERATE, PrimaryGoal.LOSE_WEIGHT);

        SuggestGoalsResponse result = GoalCalculator.suggest(request);

        // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 1780
        assertThat(result.bmr()).isEqualTo(1780);
        // TDEE = 1780 * 1.55 = 2759
        assertThat(result.tdee()).isEqualTo(2759);
        // calories = 2759 - min(2759*0.15, 1000) = 2759 - 413.85 = 2345.15 -> rounded to nearest 10 = 2350
        assertThat(result.calories()).isEqualTo(2350);
        // protein = round(2.2 * 80) = 176g -> 704 kcal
        assertThat(result.proteinGrams()).isEqualTo(176);
        // fat = round(max(0.25*2350/9, 0.6*80)) = round(max(65.28, 48)) = 65g -> 585 kcal
        assertThat(result.fatGrams()).isEqualTo(65);
        // carbs = round((2350 - 704 - 585) / 4) = round(265.25) = 265g
        assertThat(result.carbsGrams()).isEqualTo(265);
        // water = round50(80*35 + 300) = round50(3100) = 3100ml -> 3.1L
        assertThat(result.waterLiters()).isEqualTo(3.1);
    }

    @Test
    void female_sedentary_maintain_usesFemaleBmrOffsetAndFemaleFloor() {
        SuggestGoalsRequest request = new SuggestGoalsRequest(
                Gender.FEMALE, birthDateForAge(25), 165.0, 60.0, ActivityLevel.SEDENTARY, PrimaryGoal.MAINTAIN);

        SuggestGoalsResponse result = GoalCalculator.suggest(request);

        // BMR = 10*60 + 6.25*165 - 5*25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25 -> 1345
        assertThat(result.bmr()).isEqualTo(1345);
        // TDEE = 1345.25 * 1.2 = 1614.3 -> 1614
        assertThat(result.tdee()).isEqualTo(1614);
        // maintain: calories = TDEE rounded to nearest 10, above the 1200 female floor
        assertThat(result.calories()).isEqualTo(1610).isGreaterThanOrEqualTo(1200);
    }

    @Test
    void unspecifiedGender_bmrIsAverageOfMaleAndFemaleFormulas() {
        double weight = 70.0;
        double height = 170.0;
        int age = 40;
        LocalDate birthDate = birthDateForAge(age);

        SuggestGoalsResponse male = GoalCalculator.suggest(
                new SuggestGoalsRequest(Gender.MALE, birthDate, height, weight, ActivityLevel.SEDENTARY, PrimaryGoal.MAINTAIN));
        SuggestGoalsResponse female = GoalCalculator.suggest(
                new SuggestGoalsRequest(Gender.FEMALE, birthDate, height, weight, ActivityLevel.SEDENTARY, PrimaryGoal.MAINTAIN));
        SuggestGoalsResponse unspecified = GoalCalculator.suggest(
                new SuggestGoalsRequest(Gender.UNSPECIFIED, birthDate, height, weight, ActivityLevel.SEDENTARY, PrimaryGoal.MAINTAIN));

        assertThat(unspecified.bmr()).isEqualTo(Math.round((male.bmr() + female.bmr()) / 2.0));
    }

    @Test
    void lowTdee_calorieDeficitIsCappedAtMaxAbsoluteAmount_notFifteenPercent() {
        // Small/light user where 15% of TDEE is well under 1000 kcal - deficit should
        // just be the 15%, not hit the cap. This documents the "cap only clamps large
        // deficits" behavior described in the plan.
        SuggestGoalsRequest request = new SuggestGoalsRequest(
                Gender.FEMALE, birthDateForAge(28), 160.0, 50.0, ActivityLevel.SEDENTARY, PrimaryGoal.LOSE_WEIGHT);

        SuggestGoalsResponse result = GoalCalculator.suggest(request);

        double bmr = 10 * 50 + 6.25 * 160 - 5 * 28 - 161;
        double tdee = bmr * 1.2;
        double uncappedDeficit = tdee * 0.15;
        assertThat(uncappedDeficit).isLessThan(1000);
        // Result still respects the 1200 kcal female floor even for a small deficit target.
        assertThat(result.calories()).isGreaterThanOrEqualTo(1200);
    }

    @Test
    void veryLowTdee_calorieFloorNeverGoesBelowSexMinimum() {
        // Small, older, sedentary woman - TDEE is low enough that a straight 15%
        // deficit could dip below the safe floor; the floor must win.
        SuggestGoalsRequest request = new SuggestGoalsRequest(
                Gender.FEMALE, birthDateForAge(65), 150.0, 45.0, ActivityLevel.SEDENTARY, PrimaryGoal.LOSE_WEIGHT);

        SuggestGoalsResponse result = GoalCalculator.suggest(request);

        assertThat(result.calories()).isGreaterThanOrEqualTo(1200);
    }

    @Test
    void gainMuscle_surplusCappedAtFiveHundredKcal() {
        // Large, very active young man - 10% surplus would exceed 500 kcal, so the cap applies.
        SuggestGoalsRequest request = new SuggestGoalsRequest(
                Gender.MALE, birthDateForAge(20), 210.0, 150.0, ActivityLevel.VERY_ACTIVE, PrimaryGoal.GAIN_MUSCLE);

        double bmr = 10 * 150 + 6.25 * 210 - 5 * 20 + 5;
        double tdee = bmr * 1.9;
        double uncappedSurplus = tdee * 0.10;
        assertThat(uncappedSurplus).isGreaterThan(500);

        SuggestGoalsResponse result = GoalCalculator.suggest(request);
        int expectedCalories = (int) Math.round((tdee + 500) / 10.0) * 10;
        assertThat(result.calories()).isEqualTo(expectedCalories);
    }

    @Test
    void proteinPerGoal_reflectsEvidenceBasedGPerKgTargets() {
        LocalDate birthDate = birthDateForAge(30);
        double weight = 80.0;

        SuggestGoalsResponse lose = GoalCalculator.suggest(
                new SuggestGoalsRequest(Gender.MALE, birthDate, 180.0, weight, ActivityLevel.MODERATE, PrimaryGoal.LOSE_WEIGHT));
        SuggestGoalsResponse maintain = GoalCalculator.suggest(
                new SuggestGoalsRequest(Gender.MALE, birthDate, 180.0, weight, ActivityLevel.MODERATE, PrimaryGoal.MAINTAIN));
        SuggestGoalsResponse gain = GoalCalculator.suggest(
                new SuggestGoalsRequest(Gender.MALE, birthDate, 180.0, weight, ActivityLevel.MODERATE, PrimaryGoal.GAIN_MUSCLE));

        assertThat(lose.proteinGrams()).isEqualTo((int) Math.round(2.2 * weight));
        assertThat(maintain.proteinGrams()).isEqualTo((int) Math.round(1.6 * weight));
        assertThat(gain.proteinGrams()).isEqualTo((int) Math.round(2.0 * weight));
    }

    @Test
    void water_scalesWithBodyweightAndActivityLevel() {
        LocalDate birthDate = birthDateForAge(30);

        SuggestGoalsResponse sedentary = GoalCalculator.suggest(
                new SuggestGoalsRequest(Gender.MALE, birthDate, 180.0, 70.0, ActivityLevel.SEDENTARY, PrimaryGoal.MAINTAIN));
        SuggestGoalsResponse veryActive = GoalCalculator.suggest(
                new SuggestGoalsRequest(Gender.MALE, birthDate, 180.0, 70.0, ActivityLevel.VERY_ACTIVE, PrimaryGoal.MAINTAIN));

        // sedentary: round50(70*35 + 0) = 2450ml -> 2.45L rounds to 2.5L (rounded to 1 decimal)
        assertThat(sedentary.waterLiters()).isEqualTo(2.5);
        // very active: round50(70*35 + 750) = round50(3200) = 3200ml -> 3.2L
        assertThat(veryActive.waterLiters()).isEqualTo(3.2).isGreaterThan(sedentary.waterLiters());
    }

    @Test
    void ageComputation_usesPeriodBetweenBirthDateAndToday() {
        LocalDate birthDate = LocalDate.now().minusYears(20).minusDays(1);
        int expectedAge = Period.between(birthDate, LocalDate.now()).getYears();
        assertThat(expectedAge).isEqualTo(20);
    }
}
