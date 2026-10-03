package com.lifey.bodymeasurement.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.bodymeasurement.BodyMeasurement;
import com.lifey.bodymeasurement.BodyMeasurementRepository;
import com.lifey.bodymeasurement.MeasurementSite;
import com.lifey.bodymeasurement.dto.BodyMeasurementRequest;
import com.lifey.bodymeasurement.dto.BodyMeasurementResponse;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
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

@ExtendWith(MockitoExtension.class)
class BodyMeasurementServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    BodyMeasurementRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    BodyMeasurementServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void create_attachesCurrentUserAndMapsFields() {
        when(repository.save(any(BodyMeasurement.class))).thenAnswer(inv -> inv.getArgument(0));

        BodyMeasurementResponse response = service.create(
                new BodyMeasurementRequest(LocalDate.of(2026, 6, 18), MeasurementSite.CHEST, 101.5));

        ArgumentCaptor<BodyMeasurement> saved = ArgumentCaptor.forClass(BodyMeasurement.class);
        verify(repository).save(saved.capture());
        assertThat(saved.getValue().getUser()).isNotNull();
        assertThat(saved.getValue().getSite()).isEqualTo(MeasurementSite.CHEST);
        assertThat(response.valueCm()).isEqualTo(101.5);
    }

    @Test
    void delete_setsTombstoneInsteadOfRemoving() {
        BodyMeasurement entry = new BodyMeasurement();
        when(repository.findByIdAndUserId(7L, USER_ID)).thenReturn(Optional.of(entry));

        service.delete(7L);

        assertThat(entry.getDeletedAt()).isNotNull();
        verify(repository, never()).delete(any());
        verify(repository, never()).deleteById(any());
    }

    @Test
    void delete_foreignId_isRejected() {
        when(repository.findByIdAndUserId(7L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(7L)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void findAll_isScopedToCurrentUser() {
        when(repository.findAllByUserIdAndDeletedAtIsNullOrderByDateDescCreatedAtDesc(USER_ID))
                .thenReturn(List.of());

        assertThat(service.findAll()).isEmpty();
    }

    @Test
    void findDelta_usesFixedUpdatedAtIdOrdering_ignoringClientSort() {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        when(repository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        service.findDelta(since, PageRequest.of(2, 50, Sort.by(Sort.Order.desc("date"))));

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(repository).findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), pageable.capture());
        assertThat(pageable.getValue().getPageNumber()).isEqualTo(2);
        assertThat(pageable.getValue().getPageSize()).isEqualTo(50);
        assertThat(pageable.getValue().getSort())
                .isEqualTo(Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
    }
}
