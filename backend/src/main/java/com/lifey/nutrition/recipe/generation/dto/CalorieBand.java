package com.lifey.nutrition.recipe.generation.dto;

/** Calories <b>per serving</b>, not per recipe. */
public enum CalorieBand {
    UNDER_300("under 300 kcal"),
    FROM_300_TO_500("between 300 and 500 kcal"),
    FROM_500_TO_700("between 500 and 700 kcal"),
    OVER_700("over 700 kcal");

    private final String promptDescription;

    CalorieBand(String promptDescription) {
        this.promptDescription = promptDescription;
    }

    public String promptDescription() {
        return promptDescription;
    }
}
