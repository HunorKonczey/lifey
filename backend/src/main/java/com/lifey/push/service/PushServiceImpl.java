package com.lifey.push.service;

import com.lifey.push.PushDevice;
import com.lifey.push.PushDeviceRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

/**
 * Fans a message out across all of a user's registered devices, one
 * {@link PushSender} per platform (see {@code ApnsPushSender}). Runs on the
 * dedicated {@code pushTaskExecutor} (see {@link com.lifey.push.PushConfig})
 * so a slow provider round-trip never blocks the calling request/job thread.
 */
@Service
@Transactional
@RequiredArgsConstructor
public class PushServiceImpl implements PushService {

    private static final Logger log = LoggerFactory.getLogger(PushServiceImpl.class);

    private final PushDeviceRepository pushDeviceRepository;
    private final List<PushSender> pushSenders;

    @Override
    @Async("pushTaskExecutor")
    public void sendToUser(Long userId, PushMessage message) {
        List<PushDevice> devices = pushDeviceRepository.findAllByUserIdAndDeletedAtIsNull(userId);
        for (PushDevice device : devices) {
            sendToDevice(device, message);
        }
    }

    private void sendToDevice(PushDevice device, PushMessage message) {
        PushSender sender = pushSenders.stream()
                .filter(candidate -> candidate.supports(device.getPlatform()))
                .findFirst()
                .orElse(null);
        if (sender == null) {
            // No sender configured for this platform (e.g. APNs disabled locally,
            // or Android push not yet implemented — see roadmap #8's FCM follow-up).
            return;
        }
        try {
            PushSendResult result = sender.send(device, message);
            if (result == PushSendResult.TOKEN_INVALID) {
                device.setDeletedAt(Instant.now());
            }
        } catch (RuntimeException e) {
            // Backstop only — PushSender implementations must already catch their
            // own provider/network failures (see the PushSender contract).
            log.error("Push send threw unexpectedly for device {}", device.getId(), e);
        }
    }
}
