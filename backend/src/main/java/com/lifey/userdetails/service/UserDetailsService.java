package com.lifey.userdetails.service;

import com.lifey.userdetails.dto.SuggestGoalsRequest;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import com.lifey.userdetails.dto.UserDetailsRequest;
import com.lifey.userdetails.dto.UserDetailsResponse;

public interface UserDetailsService {

    UserDetailsResponse get();

    UserDetailsResponse upsert(UserDetailsRequest request);

    SuggestGoalsResponse suggestGoals(SuggestGoalsRequest request);
}
