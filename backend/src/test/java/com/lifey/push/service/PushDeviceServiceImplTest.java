package com.lifey.push.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.push.PushDevice;
import com.lifey.push.PushDeviceRepository;
import com.lifey.push.PushPlatform;
import com.lifey.push.dto.PushDeviceRequest;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PushDeviceServiceImplTest {

    private static final Long USER_ID = 1L;
    private static final Long OTHER_USER_ID = 2L;
    private static final String TOKEN = "device-token-abc";

    @Mock
    PushDeviceRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    PushDeviceServiceImpl service;

    @BeforeEach
    void stubCommon() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);

        User user = new User();
        user.setId(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(user);

        lenient().when(repository.save(any(PushDevice.class))).thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test
    void register_createsNewDevice_whenTokenUnknown() {
        when(repository.findByToken(TOKEN)).thenReturn(Optional.empty());

        service.register(new PushDeviceRequest(PushPlatform.IOS, TOKEN));

        ArgumentCaptor<PushDevice> captor = ArgumentCaptor.forClass(PushDevice.class);
        verify(repository).save(captor.capture());
        PushDevice saved = captor.getValue();
        assertThat(saved.getUser().getId()).isEqualTo(USER_ID);
        assertThat(saved.getPlatform()).isEqualTo(PushPlatform.IOS);
        assertThat(saved.getToken()).isEqualTo(TOKEN);
        assertThat(saved.getLastRegisteredAt()).isNotNull();
        assertThat(saved.getDeletedAt()).isNull();
    }

    @Test
    void register_reOwnsExistingDevice_registeredToAnotherUser() {
        User previousOwner = new User();
        previousOwner.setId(OTHER_USER_ID);
        PushDevice existing = new PushDevice();
        existing.setId(99L);
        existing.setUser(previousOwner);
        existing.setToken(TOKEN);
        existing.setPlatform(PushPlatform.ANDROID);
        when(repository.findByToken(TOKEN)).thenReturn(Optional.of(existing));

        service.register(new PushDeviceRequest(PushPlatform.IOS, TOKEN));

        assertThat(existing.getUser().getId()).isEqualTo(USER_ID);
        assertThat(existing.getPlatform()).isEqualTo(PushPlatform.IOS);
        verify(repository).save(existing);
    }

    @Test
    void register_undeletesAPreviouslySoftDeletedDevice() {
        PushDevice existing = new PushDevice();
        existing.setId(99L);
        User owner = new User();
        owner.setId(USER_ID);
        existing.setUser(owner);
        existing.setToken(TOKEN);
        existing.setDeletedAt(java.time.Instant.now());
        when(repository.findByToken(TOKEN)).thenReturn(Optional.of(existing));

        service.register(new PushDeviceRequest(PushPlatform.IOS, TOKEN));

        assertThat(existing.getDeletedAt()).isNull();
    }

    @Test
    void unregister_softDeletes_whenOwnedByCurrentUser() {
        PushDevice device = new PushDevice();
        device.setId(99L);
        when(repository.findByTokenAndUserId(TOKEN, USER_ID)).thenReturn(Optional.of(device));

        service.unregister(TOKEN);

        assertThat(device.getDeletedAt()).isNotNull();
    }

    @Test
    void unregister_isNoOp_whenTokenNotOwnedByCurrentUser() {
        when(repository.findByTokenAndUserId(TOKEN, USER_ID)).thenReturn(Optional.empty());

        service.unregister(TOKEN);

        verify(repository, never()).save(any());
    }
}
