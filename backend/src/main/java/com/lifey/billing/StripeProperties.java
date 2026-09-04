package com.lifey.billing;

import com.lifey.billing.dto.BillingInterval;
import com.lifey.billing.entity.TrainerPlan;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.Optional;

/**
 * Bound from {@code lifey.billing.stripe.*} (see application.yml). The six
 * price ids are created once in the Stripe dashboard and referenced by id —
 * never created from code (64 §5.1). Empty by default so the application
 * starts without a Stripe account configured; {@code StripeBillingServiceImpl}
 * is only ever called from a {@code ROLE_TRAINER} checkout/portal request, and
 * {@code webhookSecret} being empty just means signature verification always
 * fails closed (64 §5.3).
 */
@ConfigurationProperties(prefix = "lifey.billing.stripe")
public record StripeProperties(
        String secretKey,
        String webhookSecret,
        String successUrl,
        String cancelUrl,
        String portalReturnUrl,
        String starterMonthlyPriceId,
        String starterYearlyPriceId,
        String proMonthlyPriceId,
        String proYearlyPriceId,
        String studioMonthlyPriceId,
        String studioYearlyPriceId
) {

    public String priceId(TrainerPlan plan, BillingInterval interval) {
        boolean yearly = interval == BillingInterval.YEARLY;
        return switch (plan) {
            case STARTER -> yearly ? starterYearlyPriceId : starterMonthlyPriceId;
            case PRO -> yearly ? proYearlyPriceId : proMonthlyPriceId;
            case STUDIO -> yearly ? studioYearlyPriceId : studioMonthlyPriceId;
        };
    }

    /** The reverse of {@link #priceId} — how {@code customer.subscription.*} events recover the plan (64 §5.4). */
    public Optional<TrainerPlan> planFor(String priceId) {
        if (priceId == null) {
            return Optional.empty();
        }
        if (priceId.equals(starterMonthlyPriceId) || priceId.equals(starterYearlyPriceId)) {
            return Optional.of(TrainerPlan.STARTER);
        }
        if (priceId.equals(proMonthlyPriceId) || priceId.equals(proYearlyPriceId)) {
            return Optional.of(TrainerPlan.PRO);
        }
        if (priceId.equals(studioMonthlyPriceId) || priceId.equals(studioYearlyPriceId)) {
            return Optional.of(TrainerPlan.STUDIO);
        }
        return Optional.empty();
    }
}
