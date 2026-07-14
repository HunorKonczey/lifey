package com.lifey.weight.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.domain.BaseEntity;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.common.util.DateRanges;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
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
import java.time.Month;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WeightServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    WeightEntryRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    WeightServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void findAll_mapsEntriesToResponses() {
        when(repository.findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(USER_ID))
                .thenReturn(List.of(entry(1L, LocalDate.of(2026, Month.JUNE, 18), 80.0)));

        List<WeightResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.date()).isEqualTo(LocalDate.of(2026, Month.JUNE, 18));
            assertThat(r.weight()).isEqualTo(80.0);
        });
    }

    @Test
    void findAll_withRange_delegatesToRangeQuery() {
        LocalDate from = LocalDate.of(2026, Month.JUNE, 1);
        LocalDate to = LocalDate.of(2026, Month.JUNE, 30);
        when(repository.findByUserIdAndDeletedAtIsNullAndDateRange(USER_ID, from, to))
                .thenReturn(List.of(entry(1L, LocalDate.of(2026, Month.JUNE, 18), 80.0)));

        List<WeightResponse> result = service.findAll(from, to);

        assertThat(result).singleElement().satisfies(r -> assertThat(r.weight()).isEqualTo(80.0));
    }

    @Test
    void findAllForUser_resolvesNullBoundsToSentinelDates() {
        // Repository query uses a plain >=/<= comparison (no "is null or ..."
        // branch — see WeightEntryRepository's Javadoc for why), so a null
        // bound must be resolved to a sentinel before reaching it, not passed
        // through as null.
        when(repository.findByUserIdAndDeletedAtIsNullAndDateRange(99L, DateRanges.DISTANT_PAST, DateRanges.DISTANT_FUTURE))
                .thenReturn(List.of(entry(2L, LocalDate.of(2026, Month.JUNE, 18), 60.0)));

        List<WeightResponse> result = service.findAllForUser(99L, null, null);

        assertThat(result).singleElement().satisfies(r -> assertThat(r.id()).isEqualTo(2L));
    }

    @Test
    void create_savesWithServerStampedRecordedAt() {
        WeightRequest request = new WeightRequest(LocalDate.of(2026, Month.JUNE, 18), 80.0);
        ArgumentCaptor<WeightEntry> captor = ArgumentCaptor.forClass(WeightEntry.class);
        when(repository.save(captor.capture())).thenAnswer(inv -> withId(inv.getArgument(0), 5L));

        WeightResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(5L);
        assertThat(result.date()).isEqualTo(LocalDate.of(2026, Month.JUNE, 18));
        assertThat(result.weight()).isEqualTo(80.0);
        // The recording instant is stamped server-side so same-day entries stay ordered.
        assertThat(captor.getValue().getRecordedAt()).isNotNull();
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        WeightEntry e = entry(1L, LocalDate.of(2026, Month.JUNE, 18), 80.0);
        when(repository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(e));

        service.delete(1L);

        assertThat(e.getDeletedAt()).isNotNull();
    }

    @Test
    void findDelta_isUserScopedAndIncludesTombstones() {
        WeightEntry deleted = entry(2L, LocalDate.of(2026, Month.JUNE, 18), 80.0);
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<WeightEntry> page = new PageImpl<>(List.of(deleted));
        when(repository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<WeightResponse> result = service.findDelta(since, requested);

        assertThat(result.getContent()).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(2L);
            assertThat(r.deletedAt()).isEqualTo(deleted.getDeletedAt());
        });
    }

    private static WeightEntry entry(Long id, LocalDate date, double weight) {
        WeightEntry e = new WeightEntry();
        e.setId(id);
        e.setDate(date);
        e.setWeight(weight);
        return e;
    }

    private static <T extends BaseEntity> T withId(T entity, Long id) {
        entity.setId(id);
        return entity;
    }
}
