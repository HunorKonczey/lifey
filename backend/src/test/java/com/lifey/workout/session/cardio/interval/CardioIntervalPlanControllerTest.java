package com.lifey.workout.session.cardio.interval;

import com.lifey.workout.session.cardio.IntervalIntensity;
import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanResponse;
import com.lifey.workout.session.cardio.interval.dto.IntervalStepEntry;
import com.lifey.workout.session.cardio.interval.service.CardioIntervalPlanService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(CardioIntervalPlanController.class)
class CardioIntervalPlanControllerTest {

    private static final String FOUR_BY_FOUR_JSON = """
            {"name":"Kedd esti 4x4","steps":[
              {"type":"STEP","name":"Bemelegítés","intensity":"EASY","durationSeconds":300},
              {"type":"REPEAT","repeatCount":4,"children":[
                {"type":"STEP","name":"Kemény","intensity":"HARD","durationSeconds":240},
                {"type":"STEP","name":"Pihenő","intensity":"EASY","durationSeconds":180}]}]}
            """;

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    CardioIntervalPlanService cardioIntervalPlanService;

    @Test
    void create_returnsCreatedWithTheNestedSteps() throws Exception {
        when(cardioIntervalPlanService.create(any())).thenReturn(new CardioIntervalPlanResponse(
                9L, "Kedd esti 4x4",
                List.of(new IntervalStepEntry(IntervalStepType.STEP, "Bemelegítés", IntervalIntensity.EASY, 300, null, null),
                        new IntervalStepEntry(IntervalStepType.REPEAT, null, null, null, 4, List.of(
                                new IntervalStepEntry(IntervalStepType.STEP, "Kemény", IntervalIntensity.HARD, 240, null, null)))),
                Instant.parse("2026-08-19T08:00:00Z"), null));

        mockMvc.perform(post("/api/v1/cardio-interval-plans").contentType(MediaType.APPLICATION_JSON)
                        .content(FOUR_BY_FOUR_JSON))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9))
                .andExpect(jsonPath("$.steps[0].intensity").value("EASY"))
                .andExpect(jsonPath("$.steps[1].repeatCount").value(4))
                .andExpect(jsonPath("$.steps[1].children[0].durationSeconds").value(240));
    }

    @Test
    void create_blankNameOrNoStepsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/cardio-interval-plans").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"steps\":[]}"))
                .andExpect(status().isBadRequest());

        verify(cardioIntervalPlanService, never()).create(any());
    }

    @Test
    void create_stepWithoutATypeReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/cardio-interval-plans").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Terv\",\"steps\":[{\"intensity\":\"EASY\",\"durationSeconds\":300}]}"))
                .andExpect(status().isBadRequest());

        verify(cardioIntervalPlanService, never()).create(any());
    }

    @Test
    void create_negativeDurationReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/cardio-interval-plans").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Terv\",\"steps\":"
                                + "[{\"type\":\"STEP\",\"intensity\":\"EASY\",\"durationSeconds\":-30}]}"))
                .andExpect(status().isBadRequest());

        verify(cardioIntervalPlanService, never()).create(any());
    }

    @Test
    void get_withoutUpdatedSinceHitsTheListHandler() throws Exception {
        when(cardioIntervalPlanService.findAll()).thenReturn(List.of());

        mockMvc.perform(get("/api/v1/cardio-interval-plans"))
                .andExpect(status().isOk());

        verify(cardioIntervalPlanService).findAll();
        verify(cardioIntervalPlanService, never()).findDelta(any(), any());
    }

    @Test
    void get_withUpdatedSinceHitsTheDeltaHandler() throws Exception {
        Instant since = Instant.parse("2026-08-18T00:00:00Z");
        when(cardioIntervalPlanService.findDelta(eq(since), any())).thenReturn(new PageImpl<>(List.of()));

        mockMvc.perform(get("/api/v1/cardio-interval-plans").param("updatedSince", since.toString()))
                .andExpect(status().isOk());

        verify(cardioIntervalPlanService).findDelta(eq(since), any());
        verify(cardioIntervalPlanService, never()).findAll();
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/cardio-interval-plans/4"))
                .andExpect(status().isNoContent());

        verify(cardioIntervalPlanService).delete(4L);
    }
}
