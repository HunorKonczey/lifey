/**
 * The read side of the shared database (docs/chat/44-chat-service-extraction-plan.md §4.4).
 *
 * <p>Phase A of the extraction keeps one Neon database with two owners: this
 * service writes only {@code chat_*}, and reads three of the monolith's tables
 * through the narrow projections in this package. The Postgres grants make that
 * more than a convention — the {@code lifey_chat} role has {@code select} and
 * nothing else on them (devops/chat-database-split.md).
 *
 * <p><b>Hand-written SQL, not JPA entities</b>, and the reason matters: mapping
 * {@code User} or {@code TrainerClient} here would mean re-declaring another
 * service's schema, and then quietly inheriting every change to it. A projection
 * that names five columns breaks loudly if one of them disappears, which is the
 * failure mode we want. The columns are pinned on the other side too — see the
 * class comments on {@code User}, {@code UserSettings} and {@code TrainerClient}
 * in the monolith.
 *
 * <p>These are the classes that change if the extraction ever moves to Phase B
 * (a separate database, §4.5): the interfaces above them stay, and the
 * implementation becomes an HTTP call or an event-driven replica. Nothing in
 * {@code com.lifey.chat.service} would notice.
 */
package com.lifey.chat.spi.jdbc;
