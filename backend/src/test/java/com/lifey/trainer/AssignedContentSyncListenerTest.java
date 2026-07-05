package com.lifey.trainer;

import com.lifey.nutrition.recipe.RecipeUpdatedEvent;
import com.lifey.trainer.service.ContentAssignmentService;
import com.lifey.workout.template.WorkoutTemplateUpdatedEvent;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class AssignedContentSyncListenerTest {

    @Mock
    ContentAssignmentService contentAssignmentService;

    @InjectMocks
    AssignedContentSyncListener listener;

    @Test
    void onWorkoutTemplateUpdated_delegatesToPropagateTemplateUpdate() {
        listener.onWorkoutTemplateUpdated(new WorkoutTemplateUpdatedEvent(1L, 7L));

        verify(contentAssignmentService).propagateTemplateUpdate(1L, 7L);
    }

    @Test
    void onRecipeUpdated_delegatesToPropagateRecipeUpdate() {
        listener.onRecipeUpdated(new RecipeUpdatedEvent(1L, 12L));

        verify(contentAssignmentService).propagateRecipeUpdate(1L, 12L);
    }
}
