package com.lifey.sleep.service;

import com.lifey.sleep.dto.SleepSessionRequest;
import com.lifey.sleep.dto.SleepSessionResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

/**
 * The current user's sleep sessions (docs/integrations/89 M2, D-G7). Imported values are measurements, so there is
 * no update: a session is created once and can only be deleted.
 */
public interface SleepSessionService {

    /** Live sessions, newest end first. */
    List<SleepSessionResponse> findAll();

    /** Delta-sync feed: rows changed at or after {@code updatedSince}, tombstones included, ordered by updatedAt, id. */
    Page<SleepSessionResponse> findDelta(Instant updatedSince, Pageable pageable);

    /**
     * Creates a session.
     *
     * @throws com.lifey.common.exception.DuplicateResourceException (409) when the user already has a session for
     *         the same {@code healthRecordId}, deleted ones included
     */
    SleepSessionResponse create(SleepSessionRequest request);

    /** Soft delete: the row stays as a tombstone so the delta feed can tell the other devices. */
    void delete(Long id);
}
