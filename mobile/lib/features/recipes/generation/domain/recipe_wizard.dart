/// The wizard's answers (docs/23-ai-calorie-estimation-plan.md Phase 2). The
/// names match the backend's enums one-to-one; only the final Generate press
/// leaves the device.
enum RecipeDietType { vegetarian, vegan, meat, fish, anything;

  bool get allowsMeat => this != vegetarian && this != vegan;

  String get wireValue => switch (this) {
        RecipeDietType.vegetarian => 'VEGETARIAN',
        RecipeDietType.vegan => 'VEGAN',
        RecipeDietType.meat => 'MEAT',
        RecipeDietType.fish => 'FISH',
        RecipeDietType.anything => 'ANYTHING',
      };
}

enum RecipeMealType { breakfast, lunch, dinner, snack;

  String get wireValue => name.toUpperCase();
}

/// Calories per serving, not per recipe.
enum RecipeCalorieBand { under300, from300To500, from500To700, over700;

  String get wireValue => switch (this) {
        RecipeCalorieBand.under300 => 'UNDER_300',
        RecipeCalorieBand.from300To500 => 'FROM_300_TO_500',
        RecipeCalorieBand.from500To700 => 'FROM_500_TO_700',
        RecipeCalorieBand.over700 => 'OVER_700',
      };
}

enum RecipeMeatType { chicken, beef, pork, turkey, fish, any;

  String get wireValue => name.toUpperCase();
}

/// Answers collected so far. Immutable: each step returns a copy, so stepping
/// back and changing an answer can't leave a half-updated object behind.
class RecipeWizardAnswers {
  const RecipeWizardAnswers({
    this.dietType,
    this.mealType,
    this.calorieBand,
    this.meatType,
    this.extraRequest,
  });

  final RecipeDietType? dietType;
  final RecipeMealType? mealType;
  final RecipeCalorieBand? calorieBand;
  final RecipeMeatType? meatType;
  final String? extraRequest;

  RecipeWizardAnswers copyWith({
    RecipeDietType? dietType,
    RecipeMealType? mealType,
    RecipeCalorieBand? calorieBand,
    RecipeMeatType? meatType,
    String? extraRequest,
  }) {
    final diet = dietType ?? this.dietType;
    return RecipeWizardAnswers(
      dietType: diet,
      mealType: mealType ?? this.mealType,
      calorieBand: calorieBand ?? this.calorieBand,
      // Switching to a meatless diet drops a meat chosen earlier: the backend
      // rejects that combination, and it would be the wizard's bug, not the
      // user's mistake.
      meatType: diet != null && !diet.allowsMeat ? null : meatType ?? this.meatType,
      extraRequest: extraRequest ?? this.extraRequest,
    );
  }

  bool get isComplete => dietType != null && mealType != null && calorieBand != null;

  Map<String, dynamic> toJson() => {
        'dietType': dietType!.wireValue,
        'mealType': mealType!.wireValue,
        'calorieBand': calorieBand!.wireValue,
        if (meatType != null) 'meatType': meatType!.wireValue,
        if (extraRequest != null && extraRequest!.trim().isNotEmpty)
          'extraRequest': extraRequest!.trim(),
      };
}
