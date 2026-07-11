package com.lifey.push.dto;

import com.lifey.push.PushPlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record PushDeviceRequest(

        @NotNull
        PushPlatform platform,

        @NotBlank
        @Size(max = 200)
        String token
) {
}
