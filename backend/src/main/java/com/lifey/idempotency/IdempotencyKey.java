package com.lifey.idempotency;

import com.lifey.common.domain.BaseEntity;
import com.lifey.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * One claimed {@code Idempotency-Key} of a user: the request it belongs to and, once that request has answered
 * 2xx, the response a repeat is given back. Without a {@link #responseStatus} the request is still in flight.
 */
@Getter
@Setter
@Entity
@Table(name = "idempotency_keys")
public class IdempotencyKey extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "idem_key", nullable = false, length = 80)
    private String idemKey;

    @Column(nullable = false, length = 10)
    private String method;

    @Column(nullable = false, length = 500)
    private String path;

    @Column(name = "response_status")
    private Integer responseStatus;

    @Column(name = "response_content_type", length = 200)
    private String responseContentType;

    @Column(name = "response_body")
    private byte[] responseBody;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
}
