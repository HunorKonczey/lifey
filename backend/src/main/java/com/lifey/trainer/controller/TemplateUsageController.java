package com.lifey.trainer.controller;

import com.lifey.trainer.dto.TemplateUsageResponse;
import com.lifey.trainer.service.TemplateUsageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Trainer template usage")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer/templates")
public class TemplateUsageController {

    private final TemplateUsageService service;

    @Operation(summary = "Who uses each of this trainer's workout templates",
            description = "One row per template that is used: the clients it was assigned to, and the clients with it in a "
                    + "schedule or a program that is still running. Templates nobody uses are not listed.")
    @GetMapping("/usage")
    public List<TemplateUsageResponse> usage() {
        return service.usageForCurrentTrainer();
    }
}
