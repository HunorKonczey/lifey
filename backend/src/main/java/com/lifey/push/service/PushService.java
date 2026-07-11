package com.lifey.push.service;

public interface PushService {

    /**
     * Fans out {@code message} to every non-deleted device registered for
     * {@code userId}. Never throws — failures are logged, and a device whose
     * token the provider reports as invalid is pruned (soft-deleted).
     */
    void sendToUser(Long userId, PushMessage message);
}
