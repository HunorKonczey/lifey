package com.lifey.push.service;

public enum PushSendResult {
    DELIVERED,
    /** The provider reports the token as permanently invalid — the caller should prune it. */
    TOKEN_INVALID,
    FAILED
}
