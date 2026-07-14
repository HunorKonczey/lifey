package com.lifey.nutrition.recipe.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.InvalidImageException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.recipe.Recipe;
import com.lifey.nutrition.recipe.RecipeImage;
import com.lifey.nutrition.recipe.RecipeImageRepository;
import com.lifey.nutrition.recipe.RecipeRepository;
import com.lifey.nutrition.recipe.RecipeUpdatedEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.mock.web.MockMultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RecipeImageServiceImplTest {

    private static final Long USER_ID = 1L;
    private static final Long RECIPE_ID = 42L;

    @Mock
    RecipeImageRepository repository;

    @Mock
    RecipeRepository recipeRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    ApplicationEventPublisher eventPublisher;

    @InjectMocks
    RecipeImageServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
    }

    @Test
    void find_throwsWhenRecipeNotOwned() {
        when(recipeRepository.findByIdAndUserId(RECIPE_ID, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.find(RECIPE_ID)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void find_throwsWhenNoImageSet() {
        when(recipeRepository.findByIdAndUserId(RECIPE_ID, USER_ID)).thenReturn(Optional.of(new Recipe()));
        when(repository.findByRecipeId(RECIPE_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.find(RECIPE_ID)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void upload_createsReencodedMainAndThumbnail() throws IOException {
        Recipe recipe = recipeWithId(RECIPE_ID);
        when(recipeRepository.findByIdAndUserId(RECIPE_ID, USER_ID)).thenReturn(Optional.of(recipe));
        when(repository.findByRecipeId(RECIPE_ID)).thenReturn(Optional.empty());
        ArgumentCaptor<RecipeImage> captor = ArgumentCaptor.forClass(RecipeImage.class);
        when(repository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        service.upload(RECIPE_ID, pngUpload(2000, 1000));

        RecipeImage saved = captor.getValue();
        assertThat(saved.getContentType()).isEqualTo("image/jpeg");
        assertThat(saved.getUpdatedAt()).isNotNull();

        BufferedImage main = ImageIO.read(new java.io.ByteArrayInputStream(saved.getImage()));
        assertThat(main.getWidth()).isEqualTo(1024);
        assertThat(main.getHeight()).isEqualTo(512);

        BufferedImage thumbnail = ImageIO.read(new java.io.ByteArrayInputStream(saved.getThumbnail()));
        assertThat(thumbnail.getWidth()).isEqualTo(256);
        assertThat(thumbnail.getHeight()).isEqualTo(256);

        assertThat(recipe.getImageUpdatedAt()).isNotNull();
        verify(eventPublisher).publishEvent(new RecipeUpdatedEvent(USER_ID, RECIPE_ID));
    }

    @Test
    void upload_rejectsUndecodableFile() {
        when(recipeRepository.findByIdAndUserId(RECIPE_ID, USER_ID)).thenReturn(Optional.of(recipeWithId(RECIPE_ID)));
        MockMultipartFile garbage = new MockMultipartFile("file", "not-an-image.jpg",
                "image/jpeg", "definitely not an image".getBytes());

        assertThatThrownBy(() -> service.upload(RECIPE_ID, garbage)).isInstanceOf(InvalidImageException.class);
    }

    @Test
    void upload_throwsWhenRecipeNotOwned() {
        when(recipeRepository.findByIdAndUserId(RECIPE_ID, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.upload(RECIPE_ID, pngUpload(10, 10)))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void delete_removesRowAndClearsImageUpdatedAt() {
        Recipe recipe = recipeWithId(RECIPE_ID);
        recipe.setImageUpdatedAt(java.time.Instant.now());
        when(recipeRepository.findByIdAndUserId(RECIPE_ID, USER_ID)).thenReturn(Optional.of(recipe));

        service.delete(RECIPE_ID);

        verify(repository).deleteByRecipeId(RECIPE_ID);
        assertThat(recipe.getImageUpdatedAt()).isNull();
        verify(eventPublisher).publishEvent(new RecipeUpdatedEvent(USER_ID, RECIPE_ID));
    }

    private static Recipe recipeWithId(Long id) {
        Recipe recipe = new Recipe();
        recipe.setId(id);
        return recipe;
    }

    private static MockMultipartFile pngUpload(int width, int height) throws IOException {
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(image, "png", out);
        return new MockMultipartFile("file", "recipe.png", "image/png", out.toByteArray());
    }
}
