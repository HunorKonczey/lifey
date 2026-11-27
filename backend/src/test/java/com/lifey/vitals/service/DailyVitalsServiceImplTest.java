package com.lifey.vitals.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.common.util.DateRanges;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.vitals.DailyVitals;
import com.lifey.vitals.DailyVitalsRepository;
import com.lifey.vitals.HrvMethod;
import com.lifey.vitals.dto.DailyVitalsRequest;
import com.lifey.vitals.dto.DailyVitalsResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

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

/** docs/integrations/89 G3.1: ownership, the per-day upsert and the delta feed of daily vitals. */
@ExtendWith(MockitoExtension.class)
class DailyVitalsServiceImplTest {

    private static final Long USER_ID = 1L;
    private static final LocalDate DAY = LocalDate.parse("2026-11-21");

    @Mock
    DailyVitalsRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    DailyVitalsServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
        lenient().when(repository.save(any(DailyVitals.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void create_aNewDayAttachesTheCurrentUserAndMapsEveryValue() {
        when(repository.findByUserIdAndDate(USER_ID, DAY)).thenReturn(Optional.empty());

        DailyVitalsResponse response = service.create(new DailyVitalsRequest(DAY, 52, 48.5, HrvMethod.RMSSD));

        ArgumentCaptor<DailyVitals> saved = ArgumentCaptor.forClass(DailyVitals.class);
        verify(repository).save(saved.capture());
        assertThat(saved.getValue().getUser()).isNotNull();
        assertThat(response.date()).isEqualTo(DAY);
        assertThat(response.restingHr()).isEqualTo(52);
        assertThat(response.hrvMs()).isEqualTo(48.5);
        assertThat(response.hrvMethod()).isEqualTo(HrvMethod.RMSSD);
    }

    @Test
    void create_aStoredDayIsOverwrittenWholeAndRevived() {
        DailyVitals stored = new DailyVitals();
        stored.setDate(DAY);
        stored.setRestingHr(60);
        stored.setHrvMs(30.0);
        stored.setHrvMethod(HrvMethod.SDNN);
        stored.setDeletedAt(Instant.parse("2026-11-21T09:00:00Z"));
        when(repository.findByUserIdAndDate(USER_ID, DAY)).thenReturn(Optional.of(stored));

        service.create(new DailyVitalsRequest(DAY, 55, null, null));

        assertThat(stored.getRestingHr()).isEqualTo(55);
        // The request is the whole day: an HRV it leaves out is cleared, not kept.
        assertThat(stored.getHrvMs()).isNull();
        assertThat(stored.getHrvMethod()).isNull();
        assertThat(stored.getDeletedAt()).isNull();
    }

    @Test
    void findAll_withAnOpenBoundUsesTheDistantDates() {
        when(repository.findByUserIdAndDeletedAtIsNullAndDateRange(USER_ID, DAY, DateRanges.DISTANT_FUTURE))
                .thenReturn(List.of());

        assertThat(service.findAll(DAY, null)).isEmpty();
    }

    @Test
    void findDelta_forcesTheUpdatedAtIdOrderWhateverTheClientAsked() {
        Instant since = Instant.parse("2026-11-20T00:00:00Z");
        when(repository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        service.findDelta(since, PageRequest.of(2, 50, Sort.by("date").descending()));

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(repository).findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), pageable.capture());
        assertThat(pageable.getValue().getPageNumber()).isEqualTo(2);
        assertThat(pageable.getValue().getSort()).isEqualTo(Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
    }

    @Test
    void update_aDeletedOrForeignDayIsNotFound() {
        DailyVitals deleted = new DailyVitals();
        deleted.setDeletedAt(Instant.now());
        when(repository.findByIdAndUserId(7L, USER_ID)).thenReturn(Optional.of(deleted));
        when(repository.findByIdAndUserId(8L, USER_ID)).thenReturn(Optional.empty());

        DailyVitalsRequest request = new DailyVitalsRequest(DAY, 50, null, null);
        assertThatThrownBy(() -> service.update(7L, request)).isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.update(8L, request)).isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void delete_setsATombstoneInsteadOfRemoving() {
        DailyVitals vitals = new DailyVitals();
        when(repository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(vitals));

        service.delete(9L);

        assertThat(vitals.getDeletedAt()).isNotNull();
        verify(repository, never()).delete(any());
    }

    @Test
    void delete_anotherUsersDayIsNotFound() {
        when(repository.findByIdAndUserId(10L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(10L)).isInstanceOf(ResourceNotFoundException.class);
    }
}
