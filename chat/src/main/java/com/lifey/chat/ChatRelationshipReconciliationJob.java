package com.lifey.chat;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Layer 3 of the revoke story (docs/chat/44-chat-service-extraction-plan.md
 * §5.4): the sweep that catches whatever the webhook lost.
 *
 * <p>The monolith tells this service about a revoke over HTTP, and that call can
 * be dropped — a restart, a network blip, a deploy landing at the wrong moment.
 * Nothing retries it. This runs nightly, joins the chat's own conversations
 * against the relationship rows they were opened for, and archives any thread
 * whose relationship is no longer active.
 *
 * <p><b>It is also a health signal, not just a repair.</b> A working webhook
 * means this job archives nothing: {@code lifey.chat.relationship.reconciled}
 * staying at zero is what "the webhook is fine" looks like. If that counter
 * starts climbing, the webhook is failing and nobody has noticed — check the
 * monolith's logs for {@code ChatRevokeWebhook} before assuming this job is
 * doing its job.
 *
 * <p>One statement rather than select-then-update: the whole point is that it
 * runs against the same database the monolith writes, so it can express the
 * question as a join and let Postgres answer it (§4.1). This is the cheapest
 * thing Phase A buys.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ChatRelationshipReconciliationJob {

    private static final String SWEEP = """
            update chat_conversations c
               set archived_at = now()
              from trainer_clients tc
             where c.trainer_client_id = tc.id
               and c.archived_at is null
               and tc.status <> 'ACTIVE'
            """;

    private final JdbcClient jdbcClient;
    private final ChatMetrics metrics;

    @Scheduled(cron = "${lifey.jobs.chat-relationship-reconciliation.cron}")
    @Transactional
    public void archiveOrphanedThreads() {
        int archived = jdbcClient.sql(SWEEP).update();
        if (archived > 0) {
            // Warn, not info: every row here is a thread that should have been
            // frozen hours ago and was not.
            log.warn("Reconciliation archived {} chat thread(s) whose relationship was already revoked — "
                    + "the revoke webhook is probably not arriving", archived);
            metrics.relationshipsReconciled(archived);
        }
    }
}
