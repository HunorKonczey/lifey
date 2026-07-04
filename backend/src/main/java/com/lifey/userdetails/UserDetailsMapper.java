package com.lifey.userdetails;

import com.lifey.userdetails.dto.UserDetailsPatchRequest;
import com.lifey.userdetails.dto.UserDetailsRequest;
import com.lifey.userdetails.dto.UserDetailsResponse;

/**
 * Maps between {@link UserDetails} entities and user-details DTOs.
 */
public final class UserDetailsMapper {

    private UserDetailsMapper() {
    }

    public static void applyRequest(UserDetails entity, UserDetailsRequest request) {
        entity.setGender(request.gender());
        entity.setBirthDate(request.birthDate());
        entity.setHeightCm(request.heightCm());
        entity.setActivityLevel(request.activityLevel());
        entity.setPrimaryGoal(request.primaryGoal());
        entity.setTargetWeightKg(request.targetWeightKg());
    }

    /**
     * Applies only the fields the client selected via {@link UserDetailsPatchRequest#fields()};
     * everything else keeps its existing value on {@code entity}.
     */
    public static void applyPatch(UserDetails entity, UserDetailsPatchRequest request) {
        var fields = request.fields();
        if (fields.contains(UserDetailsField.GENDER)) entity.setGender(request.gender());
        if (fields.contains(UserDetailsField.BIRTH_DATE)) entity.setBirthDate(request.birthDate());
        if (fields.contains(UserDetailsField.HEIGHT_CM)) entity.setHeightCm(request.heightCm());
        if (fields.contains(UserDetailsField.ACTIVITY_LEVEL)) entity.setActivityLevel(request.activityLevel());
        if (fields.contains(UserDetailsField.PRIMARY_GOAL)) entity.setPrimaryGoal(request.primaryGoal());
        if (fields.contains(UserDetailsField.TARGET_WEIGHT_KG)) entity.setTargetWeightKg(request.targetWeightKg());
    }

    public static UserDetailsResponse toResponse(UserDetails entity) {
        return new UserDetailsResponse(
                entity.getGender(),
                entity.getBirthDate(),
                entity.getHeightCm(),
                entity.getActivityLevel(),
                entity.getPrimaryGoal(),
                entity.getTargetWeightKg(),
                entity.getOnboardingCompletedAt(),
                entity.getUpdatedAt()
        );
    }
}
