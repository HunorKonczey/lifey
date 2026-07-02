/// Domain enums for onboarding biometrics — values map 1:1 onto the
/// backend's `com.lifey.userdetails` enums (see
/// docs/21-onboarding-user-details-plan.md).
enum Gender { male, female, unspecified }

Gender genderFromJson(String value) => switch (value) {
      'MALE' => Gender.male,
      'FEMALE' => Gender.female,
      _ => Gender.unspecified,
    };

String genderToJson(Gender value) => switch (value) {
      Gender.male => 'MALE',
      Gender.female => 'FEMALE',
      Gender.unspecified => 'UNSPECIFIED',
    };

/// Standard Katch activity multipliers — see the backend's ActivityLevel enum.
enum ActivityLevel { sedentary, light, moderate, active, veryActive }

ActivityLevel activityLevelFromJson(String value) => switch (value) {
      'SEDENTARY' => ActivityLevel.sedentary,
      'LIGHT' => ActivityLevel.light,
      'MODERATE' => ActivityLevel.moderate,
      'ACTIVE' => ActivityLevel.active,
      'VERY_ACTIVE' => ActivityLevel.veryActive,
      _ => ActivityLevel.moderate,
    };

String activityLevelToJson(ActivityLevel value) => switch (value) {
      ActivityLevel.sedentary => 'SEDENTARY',
      ActivityLevel.light => 'LIGHT',
      ActivityLevel.moderate => 'MODERATE',
      ActivityLevel.active => 'ACTIVE',
      ActivityLevel.veryActive => 'VERY_ACTIVE',
    };

enum PrimaryGoal { loseWeight, maintain, gainMuscle }

PrimaryGoal primaryGoalFromJson(String value) => switch (value) {
      'LOSE_WEIGHT' => PrimaryGoal.loseWeight,
      'GAIN_MUSCLE' => PrimaryGoal.gainMuscle,
      _ => PrimaryGoal.maintain,
    };

String primaryGoalToJson(PrimaryGoal value) => switch (value) {
      PrimaryGoal.loseWeight => 'LOSE_WEIGHT',
      PrimaryGoal.maintain => 'MAINTAIN',
      PrimaryGoal.gainMuscle => 'GAIN_MUSCLE',
    };

/// `yyyy-MM-dd`, matching the backend's LocalDate wire format.
String formatDateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Domain model for `/user-details` — onboarding biometrics/profile. Current
/// weight is deliberately NOT here: weight history lives in the weight
/// feature (weight_entries).
class UserDetails {
  const UserDetails({
    required this.gender,
    required this.birthDate,
    required this.heightCm,
    required this.activityLevel,
    required this.primaryGoal,
    this.targetWeightKg,
  });

  final Gender gender;
  final DateTime birthDate;
  final double heightCm;
  final ActivityLevel activityLevel;
  final PrimaryGoal primaryGoal;
  final double? targetWeightKg;

  factory UserDetails.fromJson(Map<String, dynamic> json) => UserDetails(
        gender: genderFromJson(json['gender'] as String),
        birthDate: DateTime.parse(json['birthDate'] as String),
        heightCm: (json['heightCm'] as num).toDouble(),
        activityLevel: activityLevelFromJson(json['activityLevel'] as String),
        primaryGoal: primaryGoalFromJson(json['primaryGoal'] as String),
        targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'gender': genderToJson(gender),
        'birthDate': formatDateOnly(birthDate),
        'heightCm': heightCm,
        'activityLevel': activityLevelToJson(activityLevel),
        'primaryGoal': primaryGoalToJson(primaryGoal),
        'targetWeightKg': targetWeightKg,
      };

  UserDetails copyWith({
    Gender? gender,
    DateTime? birthDate,
    double? heightCm,
    ActivityLevel? activityLevel,
    PrimaryGoal? primaryGoal,
    double? targetWeightKg,
    bool clearTargetWeight = false,
  }) {
    return UserDetails(
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      activityLevel: activityLevel ?? this.activityLevel,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      targetWeightKg: clearTargetWeight ? null : (targetWeightKg ?? this.targetWeightKg),
    );
  }
}

/// Result of `POST /user-details/suggest-goals` — see GoalCalculator on the
/// backend for the full BMR/TDEE/macro methodology.
class SuggestGoalsResult {
  const SuggestGoalsResult({
    required this.bmr,
    required this.tdee,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.waterLiters,
  });

  final int bmr;
  final int tdee;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final double waterLiters;

  factory SuggestGoalsResult.fromJson(Map<String, dynamic> json) => SuggestGoalsResult(
        bmr: json['bmr'] as int,
        tdee: json['tdee'] as int,
        calories: json['calories'] as int,
        proteinGrams: json['proteinGrams'] as int,
        carbsGrams: json['carbsGrams'] as int,
        fatGrams: json['fatGrams'] as int,
        waterLiters: (json['waterLiters'] as num).toDouble(),
      );
}
