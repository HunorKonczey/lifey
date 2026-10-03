package com.lifey.superadmin;

/**
 * The role a superadmin-list row is *shown* as, with the precedence the web table has always used
 * (docs/redesign-web/82 §2.1): {@code ADMIN} (ROLE_ADMIN or ROLE_SUPER_ADMIN) over {@code TRAINER} over {@code USER}.
 * A user holding two roles belongs to exactly one kind, so the server filter and the table agree.
 */
public enum UserRoleKind {
    USER, TRAINER, ADMIN
}
