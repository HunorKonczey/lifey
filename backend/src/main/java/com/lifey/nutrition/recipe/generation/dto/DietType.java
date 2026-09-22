package com.lifey.nutrition.recipe.generation.dto;

public enum DietType {
    VEGETARIAN("vegetarian: no meat or fish, dairy and eggs are fine"),
    VEGAN("vegan: no animal products at all, including dairy, eggs and honey"),
    MEAT("contains meat"),
    FISH("pescatarian: fish or seafood, no other meat"),
    ANYTHING("no dietary restriction");

    private final String promptDescription;

    DietType(String promptDescription) {
        this.promptDescription = promptDescription;
    }

    public String promptDescription() {
        return promptDescription;
    }

    public boolean allowsMeat() {
        return this == MEAT || this == FISH || this == ANYTHING;
    }
}
