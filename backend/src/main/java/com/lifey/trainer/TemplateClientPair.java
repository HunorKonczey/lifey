package com.lifey.trainer;

/** A workout template of a trainer and one client who uses it - the row shape of the usage queries (LIF-106). */
public interface TemplateClientPair {

    Long getTemplateId();

    Long getClientId();
}
