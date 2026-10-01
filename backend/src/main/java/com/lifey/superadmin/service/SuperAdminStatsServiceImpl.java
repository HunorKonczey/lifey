package com.lifey.superadmin.service;

import com.lifey.auth.repository.RefreshTokenRepository;
import com.lifey.superadmin.dto.SuperAdminStatsResponse;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.request.TrainerRequestRepository;
import com.lifey.trainer.request.TrainerRequestStatus;
import com.lifey.user.Role;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;

/** The numbers above the super-admin user list: read-only counts, nothing is stored for them. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SuperAdminStatsServiceImpl implements SuperAdminStatsService {

    private static final Duration ACTIVE_WINDOW = Duration.ofDays(30);

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TrainerClientRepository trainerClientRepository;
    private final TrainerRequestRepository trainerRequestRepository;
    private final Clock clock;

    @Override
    public SuperAdminStatsResponse stats() {
        return new SuperAdminStatsResponse(
                userRepository.count(),
                refreshTokenRepository.countDistinctUsersSince(clock.instant().minus(ACTIVE_WINDOW)),
                userRepository.countByRole(Role.ROLE_TRAINER),
                trainerClientRepository.countDistinctClientsByStatus(TrainerClientStatus.ACTIVE),
                trainerRequestRepository.countByStatus(TrainerRequestStatus.PENDING),
                trainerRequestRepository.findOldestCreatedAt(TrainerRequestStatus.PENDING).orElse(null));
    }
}
