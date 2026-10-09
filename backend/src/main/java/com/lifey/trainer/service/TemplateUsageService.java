package com.lifey.trainer.service;

import com.lifey.trainer.dto.TemplateUsageResponse;

import java.util.List;

public interface TemplateUsageService {

    /**
     * Usage of every workout template of the current trainer that is used at all, in one answer (LIF-106) instead of one
     * request per template: assigned clients, and clients with it in a live schedule or program. Templates nobody uses
     * are left out.
     */
    List<TemplateUsageResponse> usageForCurrentTrainer();
}
