package com.lifey.idempotency.service;

import com.lifey.idempotency.IdempotencyKey;
import com.lifey.idempotency.IdempotencyKeyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class IdempotencyServiceImpl implements IdempotencyService {

    /** A request silent for this long never finished (its server died); the next one with the key may take over. */
    static final Duration ABANDONED_AFTER = Duration.ofMinutes(2);

    /** Past this a client has long given up retrying. */
    static final Duration RETENTION = Duration.ofDays(7);

    private final IdempotencyKeyRepository repository;

    @Override
    @Transactional
    public Claim claim(Long userId, String key, String method, String path) {
        Instant now = Instant.now();
        // A row can vanish between the failed insert and the read (a release or the sweep): claim again.
        for (int attempt = 0; attempt < 3; attempt++) {
            if (repository.claim(userId, key, method, path, now) == 1) {
                return Claim.of(Outcome.OWNED);
            }
            Optional<IdempotencyKey> existing = repository.findByUserIdAndIdemKey(userId, key);
            if (existing.isEmpty()) {
                continue;
            }
            IdempotencyKey row = existing.get();
            if (!row.getMethod().equals(method) || !row.getPath().equals(path)) {
                return Claim.of(Outcome.MISMATCH);
            }
            if (row.getResponseStatus() != null) {
                return new Claim(Outcome.REPLAY, row.getResponseStatus(), row.getResponseContentType(), row.getResponseBody());
            }
            return repository.takeOverAbandoned(userId, key, now.minus(ABANDONED_AFTER), now) == 1
                    ? Claim.of(Outcome.OWNED)
                    : Claim.of(Outcome.IN_FLIGHT);
        }
        return Claim.of(Outcome.IN_FLIGHT);
    }

    @Override
    @Transactional
    public void complete(Long userId, String key, int status, String contentType, byte[] body) {
        repository.complete(userId, key, status, contentType, body);
    }

    @Override
    @Transactional
    public void release(Long userId, String key) {
        repository.release(userId, key);
    }

    @Override
    @Transactional
    public int deleteExpired() {
        return repository.deleteOlderThan(Instant.now().minus(RETENTION));
    }
}
