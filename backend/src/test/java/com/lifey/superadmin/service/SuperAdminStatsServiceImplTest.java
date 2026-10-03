package com.lifey.superadmin.service;

import com.lifey.superadmin.dto.SuperAdminStatsResponse;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.request.TrainerRequestRepository;
import com.lifey.trainer.request.TrainerRequestStatus;
import com.lifey.user.Role;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SuperAdminStatsServiceImplTest {

    private static final Instant NOW = Instant.parse("2026-10-01T12:00:00Z");

    @Mock
    UserRepository userRepository;
    @Mock
    TrainerClientRepository trainerClientRepository;
    @Mock
    TrainerRequestRepository trainerRequestRepository;

    private SuperAdminStatsServiceImpl service() {
        return new SuperAdminStatsServiceImpl(userRepository, trainerClientRepository,
                trainerRequestRepository, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Test
    void stats_collectsTheCounts_andCountsActivityOverTheLastThirtyDays() {
        when(userRepository.count()).thenReturn(120L);
        when(userRepository.countActiveSince(Instant.parse("2026-09-01T12:00:00Z"))).thenReturn(64L);
        when(userRepository.countByRole(Role.ROLE_TRAINER)).thenReturn(9L);
        when(trainerClientRepository.countDistinctClientsByStatus(TrainerClientStatus.ACTIVE)).thenReturn(41L);
        when(trainerRequestRepository.countByStatus(TrainerRequestStatus.PENDING)).thenReturn(3L);
        when(trainerRequestRepository.findOldestCreatedAt(TrainerRequestStatus.PENDING))
                .thenReturn(Optional.of(Instant.parse("2026-09-28T08:00:00Z")));

        SuperAdminStatsResponse stats = service().stats();

        assertThat(stats).isEqualTo(new SuperAdminStatsResponse(120, 64, 9, 41, 3, Instant.parse("2026-09-28T08:00:00Z")));
    }

    @Test
    void stats_noPendingRequest_hasNoOldestDate() {
        when(trainerRequestRepository.findOldestCreatedAt(TrainerRequestStatus.PENDING)).thenReturn(Optional.empty());

        assertThat(service().stats().oldestPendingRequestAt()).isNull();
        assertThat(service().stats().pendingRequests()).isZero();
    }
}
