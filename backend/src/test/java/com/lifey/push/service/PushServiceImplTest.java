package com.lifey.push.service;

import com.lifey.push.PushDevice;
import com.lifey.push.PushDeviceRepository;
import com.lifey.push.PushPlatform;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PushServiceImplTest {

    private static final Long USER_ID = 1L;
    private static final PushMessage MESSAGE = new PushMessage("Title", "Body", Map.of("type", "test"));

    @Mock
    PushDeviceRepository pushDeviceRepository;

    @Mock
    PushSender iosSender;

    PushDevice iosDevice;
    PushDevice androidDevice;

    @BeforeEach
    void setUp() {
        iosDevice = new PushDevice();
        iosDevice.setId(1L);
        iosDevice.setPlatform(PushPlatform.IOS);
        iosDevice.setToken("ios-token");

        androidDevice = new PushDevice();
        androidDevice.setId(2L);
        androidDevice.setPlatform(PushPlatform.ANDROID);
        androidDevice.setToken("android-token");
    }

    @Test
    void sendToUser_sendsToEachDeviceViaTheMatchingSender() {
        when(iosSender.supports(PushPlatform.IOS)).thenReturn(true);
        when(iosSender.send(iosDevice, MESSAGE)).thenReturn(PushSendResult.DELIVERED);
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(USER_ID)).thenReturn(List.of(iosDevice));
        PushServiceImpl service = new PushServiceImpl(pushDeviceRepository, List.of(iosSender));

        service.sendToUser(USER_ID, MESSAGE);

        verify(iosSender).send(iosDevice, MESSAGE);
        assertThat(iosDevice.getDeletedAt()).isNull();
    }

    @Test
    void sendToUser_prunesDevice_whenSenderReportsTokenInvalid() {
        when(iosSender.supports(PushPlatform.IOS)).thenReturn(true);
        when(iosSender.send(iosDevice, MESSAGE)).thenReturn(PushSendResult.TOKEN_INVALID);
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(USER_ID)).thenReturn(List.of(iosDevice));
        PushServiceImpl service = new PushServiceImpl(pushDeviceRepository, List.of(iosSender));

        service.sendToUser(USER_ID, MESSAGE);

        assertThat(iosDevice.getDeletedAt()).isNotNull();
    }

    @Test
    void sendToUser_leavesDeviceAlone_onPlainFailure() {
        when(iosSender.supports(PushPlatform.IOS)).thenReturn(true);
        when(iosSender.send(iosDevice, MESSAGE)).thenReturn(PushSendResult.FAILED);
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(USER_ID)).thenReturn(List.of(iosDevice));
        PushServiceImpl service = new PushServiceImpl(pushDeviceRepository, List.of(iosSender));

        service.sendToUser(USER_ID, MESSAGE);

        assertThat(iosDevice.getDeletedAt()).isNull();
    }

    @Test
    void sendToUser_skipsDevice_whenNoSenderSupportsItsPlatform() {
        // No sender registered for ANDROID at all (e.g. FCM not implemented yet).
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(USER_ID)).thenReturn(List.of(androidDevice));
        PushServiceImpl service = new PushServiceImpl(pushDeviceRepository, List.of());

        service.sendToUser(USER_ID, MESSAGE);

        assertThat(androidDevice.getDeletedAt()).isNull();
    }

    @Test
    void sendToUser_swallowsUnexpectedException_fromASender() {
        when(iosSender.supports(PushPlatform.IOS)).thenReturn(true);
        when(iosSender.send(iosDevice, MESSAGE)).thenThrow(new RuntimeException("boom"));
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(USER_ID)).thenReturn(List.of(iosDevice));
        PushServiceImpl service = new PushServiceImpl(pushDeviceRepository, List.of(iosSender));

        service.sendToUser(USER_ID, MESSAGE);

        assertThat(iosDevice.getDeletedAt()).isNull();
    }

    @Test
    void sendToUser_fansOutToMultipleDevices() {
        PushDevice secondIosDevice = new PushDevice();
        secondIosDevice.setId(3L);
        secondIosDevice.setPlatform(PushPlatform.IOS);
        secondIosDevice.setToken("ios-token-2");

        when(iosSender.supports(PushPlatform.IOS)).thenReturn(true);
        when(iosSender.send(any(PushDevice.class), eq(MESSAGE))).thenReturn(PushSendResult.DELIVERED);
        when(pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(USER_ID))
                .thenReturn(List.of(iosDevice, secondIosDevice));
        PushServiceImpl service = new PushServiceImpl(pushDeviceRepository, List.of(iosSender));

        service.sendToUser(USER_ID, MESSAGE);

        verify(iosSender).send(iosDevice, MESSAGE);
        verify(iosSender).send(secondIosDevice, MESSAGE);
    }
}
