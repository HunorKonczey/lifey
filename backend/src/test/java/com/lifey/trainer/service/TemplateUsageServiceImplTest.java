package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.trainer.ContentAssignmentRepository;
import com.lifey.trainer.ContentType;
import com.lifey.trainer.ProgramAssignmentRepository;
import com.lifey.trainer.TemplateClientPair;
import com.lifey.trainer.WorkoutScheduleRepository;
import com.lifey.trainer.dto.TemplateUsageResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TemplateUsageServiceImplTest {

    private static final Long TRAINER_ID = 1L;

    @Mock
    ContentAssignmentRepository contentAssignmentRepository;

    @Mock
    WorkoutScheduleRepository workoutScheduleRepository;

    @Mock
    ProgramAssignmentRepository programAssignmentRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    TemplateUsageServiceImpl service;

    @BeforeEach
    void setUp() {
        // Every source starts empty; each test fills the ones it is about.
        lenient().when(currentUserProvider.getUserId()).thenReturn(TRAINER_ID);
        lenient().when(contentAssignmentRepository.findAssignedPairs(TRAINER_ID, ContentType.TEMPLATE)).thenReturn(List.of());
        lenient().when(workoutScheduleRepository.findLivePairs(eq(TRAINER_ID), any(LocalDate.class))).thenReturn(List.of());
        lenient().when(programAssignmentRepository.findLivePairs(eq(TRAINER_ID), any(LocalDate.class))).thenReturn(List.of());
    }

    private static TemplateClientPair pair(long template, long client) {
        return new TemplateClientPair() {
            @Override
            public Long getTemplateId() {
                return template;
            }

            @Override
            public Long getClientId() {
                return client;
            }
        };
    }

    @Test
    void nothingUsed_isAnEmptyList() {
        assertThat(service.usageForCurrentTrainer()).isEmpty();
    }

    @Test
    void groupsAssignedAndScheduledClientsPerTemplate_andLeavesOutTheUnused() {
        when(contentAssignmentRepository.findAssignedPairs(TRAINER_ID, ContentType.TEMPLATE))
                .thenReturn(List.of(pair(10, 100), pair(10, 101), pair(11, 100)));
        when(workoutScheduleRepository.findLivePairs(eq(TRAINER_ID), any(LocalDate.class)))
                .thenReturn(List.of(pair(10, 100), pair(12, 102)));

        List<TemplateUsageResponse> result = service.usageForCurrentTrainer();

        assertThat(result).extracting(TemplateUsageResponse::templateId).containsExactly(10L, 11L, 12L);
        assertThat(result.get(0).assignedClientIds()).containsExactly(100L, 101L);
        assertThat(result.get(0).scheduledClientIds()).containsExactly(100L);
        assertThat(result.get(1).assignedClientIds()).containsExactly(100L);
        assertThat(result.get(1).scheduledClientIds()).isEmpty();
        // Scheduled without an assignment row (it was revoked while the schedule kept running) still counts as used.
        assertThat(result.get(2).assignedClientIds()).isEmpty();
        assertThat(result.get(2).scheduledClientIds()).containsExactly(102L);
    }

    @Test
    void aClientReachedThroughAScheduleAndAProgramCountsOnce() {
        when(workoutScheduleRepository.findLivePairs(eq(TRAINER_ID), any(LocalDate.class))).thenReturn(List.of(pair(10, 100)));
        when(programAssignmentRepository.findLivePairs(eq(TRAINER_ID), any(LocalDate.class)))
                .thenReturn(List.of(pair(10, 100), pair(10, 103), pair(10, 103)));

        assertThat(service.usageForCurrentTrainer()).singleElement()
                .satisfies(u -> assertThat(u.scheduledClientIds()).containsExactly(100L, 103L));
    }
}
