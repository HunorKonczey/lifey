package com.lifey.vitals;

/**
 * How a heart rate variability value was measured (docs/integrations/89 D-G8). iOS stores SDNN, Health Connect
 * stores RMSSD. The two are not comparable, so a client never mixes them in one trend.
 */
public enum HrvMethod {
    SDNN,
    RMSSD
}
