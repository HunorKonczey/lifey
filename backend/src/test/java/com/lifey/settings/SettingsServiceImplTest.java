package com.lifey.settings;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SettingsServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    UserSettingsRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    SettingsServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void get_createsDefaultRowWithSystemLanguageWhenNoneExists() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsResponse result = service.get();

        assertThat(result.language()).isEqualTo(LanguagePreference.SYSTEM);
        assertThat(result.theme()).isEqualTo(ThemePreference.SYSTEM);
    }

    @Test
    void update_withHungarianPersistsAndReturnsIt() {
        UserSettings existing = new UserSettings();
        existing.setUser(new User());
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        SettingsRequest request = new SettingsRequest(UnitSystem.METRIC, null, null, null, null, null,
                ThemePreference.SYSTEM, LanguagePreference.HUNGARIAN);

        SettingsResponse result = service.update(request);

        assertThat(result.language()).isEqualTo(LanguagePreference.HUNGARIAN);
    }
}
