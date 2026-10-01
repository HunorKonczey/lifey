package com.lifey.superadmin.dto;

import java.time.Instant;

/**
 * {@code GET /api/v1/superadmin/stats}. {@code activeAccounts30d} counts distinct accounts that signed in or
 * refreshed their session in the last 30 days (the only activity the server records for every account);
 * {@code oldestPendingRequestAt} is null when no trainer request is waiting.
 */
public record SuperAdminStatsResponse(
        long totalUsers,
        long activeAccounts30d,
        long trainers,
        long clientsWithTrainer,
        long pendingRequests,
        Instant oldestPendingRequestAt
) {
}
