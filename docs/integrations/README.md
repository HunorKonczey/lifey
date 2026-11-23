# Integrations

Getting data in from other apps and devices: the health stores (Apple Health, Health Connect) and direct third-party connections (Garmin; Strava later). The base health-store work is in [../16-apple-health-integration-plan.md](../16-apple-health-integration-plan.md) and [../26-android-health-connect-integration-plan.md](../26-android-health-connect-integration-plan.md). This folder holds what builds on it.

## Reading order

| File | What it covers | For |
|---|---|---|
| [89-garmin-health-data-plan.md](89-garmin-health-data-plan.md) | Cardio import, sleep and daily vitals from the health stores (M1–M3), then the direct Garmin API connection (M4–M5, parked until a company exists) | Start here. Backend · mobile · web |

## Milestones at a glance

| # | Name | Status | Gate |
|---|---|---|---|
| M1 | Cardio import from the health store | planned | none |
| M2 | Sleep from the health store | planned | none |
| M3 | Resting HR and HRV from the health store | planned | none |
| M4 | Direct Garmin connection | parked | company + Garmin Starter approval |
| M5 | Garmin-only data (stress, Body Battery, Training API) | parked | M4 |
