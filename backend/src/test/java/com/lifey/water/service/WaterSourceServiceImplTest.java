package com.lifey.water.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.water.WaterSource;
import com.lifey.water.WaterSourceRepository;
import com.lifey.water.dto.WaterSourceRequest;
import com.lifey.water.dto.WaterSourceResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WaterSourceServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    WaterSourceRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    WaterSourceServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void findAll_mapsSourcesToResponses() {
        when(repository.findAllByUserId(USER_ID))
                .thenReturn(List.of(source(1L, "Creatine Shake", 0.9)));

        List<WaterSourceResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.name()).isEqualTo("Creatine Shake");
            assertThat(r.volumeLiters()).isEqualTo(0.9);
        });
    }

    @Test
    void create_savesAndReturnsResponse() {
        when(repository.save(any(WaterSource.class))).thenAnswer(inv -> {
            WaterSource s = inv.getArgument(0);
            s.setId(5L);
            return s;
        });
        WaterSourceRequest request = new WaterSourceRequest("Water Bottle", 0.75);

        WaterSourceResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(5L);
        assertThat(result.name()).isEqualTo("Water Bottle");
        assertThat(result.volumeLiters()).isEqualTo(0.75);
    }

    @Test
    void update_replacesNameAndVolume() {
        WaterSource existing = source(5L, "Old name", 0.5);
        when(repository.findByIdAndUserId(5L, USER_ID)).thenReturn(Optional.of(existing));

        WaterSourceResponse result =
                service.update(5L, new WaterSourceRequest("Protein Shake", 0.4));

        assertThat(result.name()).isEqualTo("Protein Shake");
        assertThat(result.volumeLiters()).isEqualTo(0.4);
    }

    @Test
    void update_throwsWhenMissing() {
        when(repository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update(99L, new WaterSourceRequest("X", 1.0)))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Water source not found: 99");
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.existsByIdAndUserId(99L, USER_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    private static WaterSource source(Long id, String name, double volume) {
        WaterSource s = new WaterSource();
        s.setId(id);
        s.setName(name);
        s.setVolumeLiters(volume);
        return s;
    }
}
