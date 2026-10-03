package com.lifey.progressphoto.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.InvalidImageException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.progressphoto.PhotoPose;
import com.lifey.progressphoto.ProgressPhoto;
import com.lifey.progressphoto.ProgressPhotoImage;
import com.lifey.progressphoto.ProgressPhotoImageRepository;
import com.lifey.progressphoto.ProgressPhotoRepository;
import com.lifey.progressphoto.dto.ProgressPhotoResponse;
import com.lifey.progressphoto.dto.ProgressPhotoUpdateRequest;
import com.lifey.progressphoto.exception.InvalidProgressPhotoException;
import com.lifey.user.User;
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
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProgressPhotoServiceImplTest {

    private static final Long USER_ID = 1L;
    private static final Long PHOTO_ID = 42L;

    @Mock
    ProgressPhotoRepository repository;

    @Mock
    ProgressPhotoImageRepository imageRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    ProgressPhotoServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
        lenient().when(repository.save(any(ProgressPhoto.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void create_storesBoundedMainAndSquareThumbnail_withoutUpscalingASmallSource() throws IOException {
        ArgumentCaptor<ProgressPhotoImage> captor = ArgumentCaptor.forClass(ProgressPhotoImage.class);

        service.create(upload(3200, 1600), LocalDate.now(), PhotoPose.FRONT, null);
        verify(imageRepository).save(captor.capture());
        BufferedImage big = decode(captor.getValue().getImage());
        assertThat(big.getWidth()).isEqualTo(1600);
        assertThat(big.getHeight()).isEqualTo(800);
        BufferedImage thumb = decode(captor.getValue().getThumbnail());
        assertThat(thumb.getWidth()).isEqualTo(256);
        assertThat(thumb.getHeight()).isEqualTo(256);
        assertThat(captor.getValue().getContentType()).isEqualTo("image/jpeg");
    }

    @Test
    void create_doesNotUpscaleASmallPhoto() throws IOException {
        ArgumentCaptor<ProgressPhotoImage> captor = ArgumentCaptor.forClass(ProgressPhotoImage.class);

        service.create(upload(400, 300), LocalDate.now(), PhotoPose.SIDE, null);
        verify(imageRepository).save(captor.capture());

        BufferedImage main = decode(captor.getValue().getImage());
        assertThat(main.getWidth()).isEqualTo(400);
        assertThat(main.getHeight()).isEqualTo(300);
    }

    @Test
    void create_strippedOfExifAndGps() throws IOException {
        ArgumentCaptor<ProgressPhotoImage> captor = ArgumentCaptor.forClass(ProgressPhotoImage.class);
        MockMultipartFile withExif = new MockMultipartFile("file", "p.jpg", "image/jpeg",
                jpegWithExifMarker(300, 300, "GPS-MARKER-12.34N"));

        service.create(withExif, LocalDate.now(), PhotoPose.BACK, null);
        verify(imageRepository).save(captor.capture());

        for (byte[] stored : List.of(captor.getValue().getImage(), captor.getValue().getThumbnail())) {
            String text = new String(stored, StandardCharsets.ISO_8859_1);
            assertThat(text).doesNotContain("Exif").doesNotContain("GPS-MARKER");
        }
    }

    @Test
    void create_attachesCurrentUser_defaultsPose_andBlankNoteBecomesNull() throws IOException {
        ArgumentCaptor<ProgressPhoto> captor = ArgumentCaptor.forClass(ProgressPhoto.class);

        ProgressPhotoResponse response = service.create(upload(10, 10), LocalDate.of(2026, 6, 18), null, "   ");

        verify(repository).save(captor.capture());
        assertThat(captor.getValue().getUser()).isNotNull();
        assertThat(captor.getValue().getPose()).isEqualTo(PhotoPose.OTHER);
        assertThat(captor.getValue().getNote()).isNull();
        assertThat(response.takenOn()).isEqualTo(LocalDate.of(2026, 6, 18));
    }

    @Test
    void create_rejectsUndecodableFile_andWritesNothing() {
        MockMultipartFile garbage = new MockMultipartFile("file", "x.jpg", "image/jpeg", "not an image".getBytes());

        assertThatThrownBy(() -> service.create(garbage, LocalDate.now(), PhotoPose.FRONT, null))
                .isInstanceOf(InvalidImageException.class);
        verify(repository, never()).save(any());
        verify(imageRepository, never()).save(any());
    }

    @Test
    void create_rejectsFutureDate_andOverlongNote() throws IOException {
        MockMultipartFile png = upload(10, 10);

        assertThatThrownBy(() -> service.create(png, LocalDate.now().plusDays(5), PhotoPose.FRONT, null))
                .isInstanceOf(InvalidProgressPhotoException.class);
        assertThatThrownBy(() -> service.create(png, LocalDate.now(), PhotoPose.FRONT, "x".repeat(501)))
                .isInstanceOf(InvalidProgressPhotoException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void foreignOrMissingId_isRejectedEverywhere() throws IOException {
        when(repository.findByIdAndUserId(PHOTO_ID, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findImage(PHOTO_ID)).isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.delete(PHOTO_ID)).isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.update(PHOTO_ID,
                new ProgressPhotoUpdateRequest(LocalDate.now(), PhotoPose.FRONT, null)))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(imageRepository, never()).findByPhotoId(any());
        verify(imageRepository, never()).deleteByPhotoId(any());
    }

    @Test
    void findImage_notFoundWhenOwnedPhotoHasNoImage() {
        when(repository.findByIdAndUserId(PHOTO_ID, USER_ID)).thenReturn(Optional.of(new ProgressPhoto()));
        when(imageRepository.findByPhotoId(PHOTO_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findImage(PHOTO_ID)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void update_replacesMetadata_andNullNoteClears() {
        ProgressPhoto photo = new ProgressPhoto();
        photo.setNote("old");
        when(repository.findByIdAndUserId(PHOTO_ID, USER_ID)).thenReturn(Optional.of(photo));

        service.update(PHOTO_ID, new ProgressPhotoUpdateRequest(LocalDate.of(2026, 5, 1), PhotoPose.SIDE, null));

        assertThat(photo.getTakenOn()).isEqualTo(LocalDate.of(2026, 5, 1));
        assertThat(photo.getPose()).isEqualTo(PhotoPose.SIDE);
        assertThat(photo.getNote()).isNull();
        assertThat(photo.getUpdatedAt()).isNotNull();
    }

    @Test
    void delete_removesImageThenPhoto() {
        ProgressPhoto photo = new ProgressPhoto();
        when(repository.findByIdAndUserId(PHOTO_ID, USER_ID)).thenReturn(Optional.of(photo));

        service.delete(PHOTO_ID);

        verify(imageRepository).deleteByPhotoId(PHOTO_ID);
        verify(repository).delete(photo);
    }

    @Test
    void findAll_isScopedToCurrentUser() {
        when(repository.findAllByUserIdOrderByTakenOnDescIdDesc(USER_ID)).thenReturn(List.of());

        assertThat(service.findAll()).isEmpty();
        verify(repository).findAllByUserIdOrderByTakenOnDescIdDesc(USER_ID);
    }

    private static BufferedImage decode(byte[] bytes) throws IOException {
        return ImageIO.read(new ByteArrayInputStream(bytes));
    }

    private static MockMultipartFile upload(int width, int height) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB), "png", out);
        return new MockMultipartFile("file", "p.png", "image/png", out.toByteArray());
    }

    /** A real JPEG with an APP1 "Exif" segment spliced in right after SOI, carrying [marker]. */
    private static byte[] jpegWithExifMarker(int width, int height, String marker) throws IOException {
        ByteArrayOutputStream jpeg = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB), "jpg", jpeg);
        byte[] base = jpeg.toByteArray();
        byte[] payload = ("Exif\0\0" + marker).getBytes(StandardCharsets.ISO_8859_1);
        int length = payload.length + 2;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(base, 0, 2); // SOI
        out.write(0xFF);
        out.write(0xE1);
        out.write(length >> 8);
        out.write(length & 0xFF);
        out.write(payload);
        out.write(base, 2, base.length - 2);
        return out.toByteArray();
    }
}
