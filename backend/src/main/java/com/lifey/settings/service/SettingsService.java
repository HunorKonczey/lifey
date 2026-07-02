package com.lifey.settings.service;

import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;

public interface SettingsService {

    SettingsResponse get();

    SettingsResponse update(SettingsRequest request);
}
