package com.lifey.common.domain;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * Base class for entities that participate in mobile delta sync (see
 * docs/16-delta-sync-rollout.md). {@code updatedAt} is bumped on every
 * insert/update by the lifecycle callbacks below rather than a DB trigger,
 * since every write to these entities already goes through JPA. {@code
 * deletedAt} is a tombstone, set only by each entity's own service on delete
 * — soft delete replaces the hard delete these entities used to have.
 */
@Getter
@Setter
@MappedSuperclass
public abstract class SyncableEntity extends BaseEntity {

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @PrePersist
    protected void onSyncableCreate() {
        updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onSyncableUpdate() {
        updatedAt = Instant.now();
    }
}
