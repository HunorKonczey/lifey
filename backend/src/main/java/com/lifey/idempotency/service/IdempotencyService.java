package com.lifey.idempotency.service;

/**
 * Claims, answers and releases a user's {@code Idempotency-Key}s for {@code IdempotencyFilter}. Every call is its
 * own short transaction: a claim must be visible to a concurrent duplicate straight away, not when the business
 * request that follows it commits.
 */
public interface IdempotencyService {

    Claim claim(Long userId, String key, String method, String path);

    /** Stores the 2xx answer of the request that owns the key, for repeats to be given back. */
    void complete(Long userId, String key, int status, String contentType, byte[] body);

    /** The owning request did not succeed: free the key so the retry runs again. */
    void release(Long userId, String key);

    /** Deletes the keys older than the retention window; returns how many. */
    int deleteExpired();

    enum Outcome {
        /** First time this key is seen (or its previous owner vanished): run the request, then complete or release. */
        OWNED,
        /** The request already succeeded: answer with {@link Claim#status()} / {@link Claim#body()}. */
        REPLAY,
        /** The same key is being processed right now. */
        IN_FLIGHT,
        /** The key was first used for a different method or path. */
        MISMATCH
    }

    record Claim(Outcome outcome, int status, String contentType, byte[] body) {

        static Claim of(Outcome outcome) {
            return new Claim(outcome, 0, null, null);
        }
    }
}
