package com.lifey.weight;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
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
        when(repository.findAllByUserIdOrderByDateDescRecordedAtDesc(USER_ID))
                .thenReturn(List.of(entry(1L, LocalDate.of(2026, 6, 18), 80.0)));

        List<WeightResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.date()).isEqualTo(LocalDate.of(2026, 6, 18));
            assertThat(r.weight()).isEqualTo(80.0);
        });
    }

    @Test
    void create_savesWithServerStampedRecordedAt() {
        WeightRequest request = new WeightRequest(LocalDate.of(2026, 6, 18), 80.0);
        ArgumentCaptor<WeightEntry> captor = ArgumentCaptor.forClass(WeightEntry.class);
        when(repository.save(captor.capture())).thenAnswer(inv -> {
            WeightEntry e = inv.getArgument(0);
            e.setId(5L);
            return e;
        });

        WeightResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(5L);
        assertThat(result.date()).isEqualTo(LocalDate.of(2026, 6, 18));
        assertThat(result.weight()).isEqualTo(80.0);
        // The recording instant is stamped server-side so same-day entries stay ordered.
        assertThat(captor.getValue().getRecordedAt()).isNotNull();
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.existsByIdAndUserId(99L, USER_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).deleteByIdAndUserId(99L, USER_ID);
    }

    @Test
    void delete_removesWhenExists() {
        when(repository.existsByIdAndUserId(1L, USER_ID)).thenReturn(true);

        service.delete(1L);

        verify(repository).deleteByIdAndUserId(1L, USER_ID);
    }

    private static WeightEntry entry(Long id, LocalDate date, double weight) {
        WeightEntry e = new WeightEntry();
        e.setId(id);
        e.setDate(date);
        e.setWeight(weight);
        return e;
    }
}
