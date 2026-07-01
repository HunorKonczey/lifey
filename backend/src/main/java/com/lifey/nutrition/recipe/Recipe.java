package com.lifey.nutrition.recipe;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

/**
 * Only the parent Recipe is delta-synced (see docs/16-delta-sync-rollout.md)
 * — ingredients are never independently tombstoned, so any ingredient-only
 * edit must explicitly bump {@code updatedAt} (see RecipeServiceImpl#update,
 * which cannot rely on Hibernate dirty-checking a Recipe scalar field when
 * only the ingredient collection changed).
 */
@Getter
@Setter
@Entity
@Table(name = "recipes")
public class Recipe extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String name;

    @Column(length = 2000)
    private String description;

    private boolean favorite;

    @Column(nullable = false)
    private int servings = 1;

    @OneToMany(mappedBy = "recipe", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<RecipeIngredient> ingredients = new ArrayList<>();
}
