package com.lifey.nutrition.recipe;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "recipe_images")
public class RecipeImage extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipe_id", nullable = false, unique = true)
    private Recipe recipe;

    // Deliberately not @Lob — see UserAvatar#image for why (bytea vs oid on Postgres).
    @Column(nullable = false)
    private byte[] image;

    @Column(nullable = false)
    private byte[] thumbnail;

    @Column(name = "content_type", nullable = false, length = 50)
    private String contentType;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
