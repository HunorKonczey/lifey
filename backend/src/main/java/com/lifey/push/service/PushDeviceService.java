package com.lifey.push.service;

import com.lifey.push.dto.PushDeviceRequest;

public interface PushDeviceService {

    void register(PushDeviceRequest request);

    void unregister(String token);
}
