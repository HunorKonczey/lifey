package com.lifey.steps;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DailyStepCountServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    DailyStepCountRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    DailyStepCountServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void findAll_mapsEntriesToResponses() {
        when(repository.findAllByUserIdAndDeletedAtIsNullOrderByDateDesc(USER_ID))
                .thenReturn(List.of(entry(1L, LocalDate.of(2026, 6, 18), 8200)));

        List<DailyStepCountResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.date()).isEqualTo(LocalDate.of(2026, 6, 18));
            assertThat(r.steps()).isEqualTo(8200);
        });
    }

    @Test
    void create_insertsWhenNoRowForDate() {
        LocalDate date = LocalDate.of(2026, 6, 18);
        when(repository.findByUserIdAndDate(USER_ID, date)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> {
            DailyStepCount e = inv.getArgument(0);
            e.setId(5L);
            return e;
        });

        DailyStepCountResponse result = service.create(new DailyStepCountRequest(date, 8200));

        assertThat(result.id()).isEqualTo(5L);
        assertThat(result.date()).isEqualTo(date);
        assertThat(result.steps()).isEqualTo(8200);
    }

    @Test
    void create_upsertsExistingRowForSameDate() {
        LocalDate date = LocalDate.of(2026, 6, 18);
        DailyStepCount existing = entry(7L, date, 8200);
        when(repository.findByUserIdAndDate(USER_ID, date)).thenReturn(Optional.of(existing));
        ArgumentCaptor<DailyStepCount> captor = ArgumentCaptor.forClass(DailyStepCount.class);
        when(repository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        // Re-posting the same date with a higher total updates the existing row.
        DailyStepCountResponse result = service.create(new DailyStepCountRequest(date, 11000));

        assertThat(captor.getValue().getId()).isEqualTo(7L);
        assertThat(captor.getValue().getSteps()).isEqualTo(11000);
        assertThat(result.id()).isEqualTo(7L);
        assertThat(result.steps()).isEqualTo(11000);
        // No second user lookup — we reuse the existing row, not a fresh entity.
        verify(userRepository, never()).getReferenceById(any());
    }

    @Test
    void create_revivesSoftDeletedRowForSameDate() {
        LocalDate date = LocalDate.of(2026, 6, 18);
        DailyStepCount existing = entry(7L, date, 8200);
        existing.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));
        when(repository.findByUserIdAndDate(USER_ID, date)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.create(new DailyStepCountRequest(date, 9000));

        assertThat(existing.getDeletedAt()).isNull();
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        DailyStepCount existing = entry(1L, LocalDate.of(2026, 6, 18), 8200);
        when(repository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(existing));

        service.delete(1L);

        assertThat(existing.getDeletedAt()).isNotNull();
    }

    @Test
    void findDelta_isUserScopedAndIncludesTombstones() {
        DailyStepCount deleted = entry(2L, LocalDate.of(2026, 6, 18), 8200);
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<DailyStepCount> page = new PageImpl<>(List.of(deleted));
        when(repository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<DailyStepCountResponse> result = service.findDelta(since, requested);

        assertThat(result.getContent()).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(2L);
            assertThat(r.deletedAt()).isEqualTo(deleted.getDeletedAt());
        });
    }

    private static DailyStepCount entry(Long id, LocalDate date, int steps) {
        DailyStepCount e = new DailyStepCount();
        e.setId(id);
        e.setDate(date);
        e.setSteps(steps);
        return e;
    }
}
