package com.lifey.push;

import com.lifey.push.dto.PushDeviceRequest;
import com.lifey.push.service.PushDeviceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Push Devices", description = "Push notification device token registration")
@RestController
@RequestMapping("/api/v1/push/devices")
@RequiredArgsConstructor
public class PushDeviceController {

    private final PushDeviceService pushDeviceService;

    @Operation(summary = "Register (or re-register) a device push token for the current user")
    @PutMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void register(@Valid @RequestBody PushDeviceRequest request) {
        pushDeviceService.register(request);
    }

    @Operation(summary = "Unregister a device push token, e.g. on logout")
    @DeleteMapping("/{token}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unregister(@PathVariable String token) {
        pushDeviceService.unregister(token);
    }
}
