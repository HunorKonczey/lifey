package com.lifey.user.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.AvatarSource;
import com.lifey.user.InvalidImageException;
import com.lifey.user.User;
import com.lifey.user.UserAvatar;
import com.lifey.user.UserAvatarRepository;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserAvatarServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    UserAvatarRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    UserAvatarServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
    }

    @Test
    void find_throwsWhenMissing() {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.find()).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void find_returnsExisting() {
        UserAvatar avatar = new UserAvatar();
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(avatar));

        assertThat(service.find()).isSameAs(avatar);
    }

    @Test
    void upload_createsNewAvatarAsReencodedJpeg() throws IOException {
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.empty());
        when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
        ArgumentCaptor<UserAvatar> captor = ArgumentCaptor.forClass(UserAvatar.class);
        when(repository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        service.upload(pngUpload(200, 100));

        UserAvatar saved = captor.getValue();
        assertThat(saved.getContentType()).isEqualTo("image/jpeg");
        assertThat(saved.getSource()).isEqualTo(AvatarSource.UPLOAD);
        assertThat(saved.getUpdatedAt()).isNotNull();
        assertThat(saved.getImage()).isNotEmpty();

        BufferedImage reencoded = ImageIO.read(new java.io.ByteArrayInputStream(saved.getImage()));
        assertThat(reencoded.getWidth()).isEqualTo(512);
        assertThat(reencoded.getHeight()).isEqualTo(512);
    }

    @Test
    void upload_replacesExistingAvatarInPlace() throws IOException {
        UserAvatar existing = new UserAvatar();
        existing.setSource(AvatarSource.GOOGLE);
        when(repository.findByUserId(USER_ID)).thenReturn(Optional.of(existing));
        when(repository.save(existing)).thenReturn(existing);

        service.upload(pngUpload(64, 64));

        assertThat(existing.getSource()).isEqualTo(AvatarSource.UPLOAD);
        verify(userRepository, org.mockito.Mockito.never()).getReferenceById(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void upload_rejectsUndecodableFile() {
        MockMultipartFile garbage = new MockMultipartFile("file", "not-an-image.jpg",
                "image/jpeg", "definitely not an image".getBytes());

        assertThatThrownBy(() -> service.upload(garbage)).isInstanceOf(InvalidImageException.class);
    }

    @Test
    void delete_removesRow() {
        service.delete();

        verify(repository).deleteByUserId(USER_ID);
    }

    private static MockMultipartFile pngUpload(int width, int height) throws IOException {
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(image, "png", out);
        return new MockMultipartFile("file", "avatar.png", "image/png", out.toByteArray());
    }
}
