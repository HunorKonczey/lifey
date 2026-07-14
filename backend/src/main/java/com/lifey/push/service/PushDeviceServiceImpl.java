package com.lifey.push.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.push.PushDevice;
import com.lifey.push.PushDeviceRepository;
import com.lifey.push.dto.PushDeviceRequest;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Service
@Transactional
@RequiredArgsConstructor
public class PushDeviceServiceImpl implements PushDeviceService {

    private final PushDeviceRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    /**
     * Upserts by token. A token already registered to another user (shared
     * device, logout then a different account logs in) is re-owned to the
     * current user rather than rejected — see docs/30-push-notifications-plan.md.
     */
    @Override
    public void register(PushDeviceRequest request) {
        Long userId = currentUserProvider.getUserId();
        PushDevice device = repository.findByToken(request.token()).orElseGet(PushDevice::new);
        device.setUser(userRepository.getReferenceById(userId));
        device.setToken(request.token());
        device.setPlatform(request.platform());
        device.setLastRegisteredAt(Instant.now());
        device.setDeletedAt(null);
        repository.save(device);
    }

    /**
     * Scoped to the current user's own token so a device re-registered to a
     * different account after a shared-device handoff can't be deleted by the
     * previous owner's delayed logout call. A no-op if the token isn't
     * (still) theirs, so a repeated or racing logout call is harmless.
     */
    @Override
    public void unregister(String token) {
        Long userId = currentUserProvider.getUserId();
        repository.findByTokenAndUserId(token, userId)
                .ifPresent(device -> device.setDeletedAt(Instant.now()));
    }
}
