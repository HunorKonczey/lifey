package com.lifey.userdetails;

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
