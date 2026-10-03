package com.lifey.settings;

/** Who last changed a user's nutrition goals (docs/redesign-web/82 section 2.4). */
public enum GoalsSource {
    /** Never recorded: a row from before the attribution existed. No date is invented for it. */
    UNKNOWN,
    /** The user themself, in the app or through the suggested-goals recalculation. */
    SELF,
    /** A trainer, through the trainer's goals endpoint (the account may since have been deleted). */
    TRAINER
}
