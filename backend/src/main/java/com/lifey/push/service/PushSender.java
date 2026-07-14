package com.lifey.push.service;

import com.lifey.push.PushDevice;
import com.lifey.push.PushPlatform;

/**
 * Sends to one device on one platform (APNs, later FCM). Implementations
 * must never throw — any provider/network failure is caught internally and
 * reported as {@link PushSendResult#FAILED}, since a push must never break
 * the flow that triggered it. {@link PushServiceImpl} still catches
 * defensively, but that's a backstop, not the contract.
 */
public interface PushSender {

    PushSendResult send(PushDevice device, PushMessage message);

    boolean supports(PushPlatform platform);
}
