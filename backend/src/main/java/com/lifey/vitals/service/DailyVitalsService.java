package com.lifey.vitals.service;

import com.lifey.vitals.dto.DailyVitalsRequest;
import com.lifey.vitals.dto.DailyVitalsResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/** The current user's daily vitals (docs/integrations/89 G3.1, D-G8). */
public interface DailyVitalsService {

    /** Every live day, newest first. */
    List<DailyVitalsResponse> findAll();

    /** Live days within the inclusive range; either bound may be null for an open end. */
    List<DailyVitalsResponse> findAll(LocalDate from, LocalDate to);

    /** Delta-sync feed, tombstones included, ordered by updatedAt then id whatever the client asked. */
    Page<DailyVitalsResponse> findDelta(Instant updatedSince, Pageable pageable);

    /**
     * Upserts the day: a day already stored (deleted ones included) is overwritten and revived. Both values are
     * replaced, so the client sends the whole day, not one value.
     */
    DailyVitalsResponse create(DailyVitalsRequest request);

    DailyVitalsResponse update(Long id, DailyVitalsRequest request);

    /** Soft delete: sets the tombstone. */
    void delete(Long id);
}
