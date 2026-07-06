package com.lifey.userdetails.service;

import com.lifey.userdetails.dto.SuggestGoalsRequest;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import com.lifey.userdetails.dto.UserDetailsPatchRequest;
import com.lifey.userdetails.dto.UserDetailsRequest;
import com.lifey.userdetails.dto.UserDetailsResponse;

public interface UserDetailsService {

    UserDetailsResponse get();

    UserDetailsResponse upsert(UserDetailsRequest request);

    /**
     * Persists only the fields the client selected (see {@link UserDetailsPatchRequest}),
     * then recalculates and applies the daily calorie/macro/water goals to settings.
     */
    UserDetailsResponse partialUpdate(UserDetailsPatchRequest request);

    SuggestGoalsResponse suggestGoals(SuggestGoalsRequest request);
}
