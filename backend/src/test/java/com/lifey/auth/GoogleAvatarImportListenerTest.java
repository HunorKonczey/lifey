package com.lifey.auth;

import com.lifey.user.AvatarSource;
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
import org.springframework.http.HttpStatusCode;
import org.springframework.mock.http.client.MockClientHttpResponse;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.test.web.client.match.MockRestRequestMatchers;
import org.springframework.test.web.client.response.MockRestResponseCreators;
import org.springframework.web.client.RestClient;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class GoogleAvatarImportListenerTest {

    private static final Long USER_ID = 1L;

    @Mock
    UserAvatarRepository userAvatarRepository;

    @Mock
    UserRepository userRepository;

    RestClient googleAvatarRestClient;
    MockRestServiceServer mockServer;

    GoogleAvatarImportListener listener;

    @BeforeEach
    void setUp() {
        RestClient.Builder builder = RestClient.builder();
        mockServer = MockRestServiceServer.bindTo(builder).build();
        googleAvatarRestClient = builder.build();
        listener = new GoogleAvatarImportListener(userAvatarRepository, userRepository, googleAvatarRestClient);
    }

    @Test
    void skipsWhenAvatarAlreadyExists() {
        when(userAvatarRepository.existsByUserId(USER_ID)).thenReturn(true);

        listener.onGoogleAvatarCandidate(new GoogleAvatarCandidateEvent(USER_ID,
                "https://lh3.googleusercontent.com/a/abc=s96-c"));

        verify(userAvatarRepository, never()).save(any());
    }

    @Test
    void skipsUntrustedHost() {
        when(userAvatarRepository.existsByUserId(USER_ID)).thenReturn(false);

        listener.onGoogleAvatarCandidate(new GoogleAvatarCandidateEvent(USER_ID, "https://evil.example.com/pic.jpg"));

        verify(userAvatarRepository, never()).save(any());
    }

    @Test
    void downloadsRewritesSizeAndSavesAsGoogleSource() throws IOException {
        when(userAvatarRepository.existsByUserId(USER_ID)).thenReturn(false);
        mockServer.expect(MockRestRequestMatchers.requestTo(
                        URI.create("https://lh3.googleusercontent.com/a/abc=s512-c")))
                .andRespond(MockRestResponseCreators.withSuccess(pngBytes(200, 100), org.springframework.http.MediaType.IMAGE_PNG));

        ArgumentCaptor<UserAvatar> captor = ArgumentCaptor.forClass(UserAvatar.class);
        when(userAvatarRepository.save(captor.capture())).thenAnswer(inv -> inv.getArgument(0));

        listener.onGoogleAvatarCandidate(new GoogleAvatarCandidateEvent(USER_ID,
                "https://lh3.googleusercontent.com/a/abc=s96-c"));

        UserAvatar saved = captor.getValue();
        assertThat(saved.getSource()).isEqualTo(AvatarSource.GOOGLE);
        assertThat(saved.getContentType()).isEqualTo("image/jpeg");
        assertThat(saved.getImage()).isNotEmpty();
        mockServer.verify();
    }

    @Test
    void downloadFailure_isCaughtAndNotPropagated() {
        when(userAvatarRepository.existsByUserId(USER_ID)).thenReturn(false);
        mockServer.expect(MockRestRequestMatchers.requestTo(
                        URI.create("https://lh3.googleusercontent.com/a/abc=s512-c")))
                .andRespond(request -> new MockClientHttpResponse(new byte[0], HttpStatusCode.valueOf(500)));

        assertThatCode(() -> listener.onGoogleAvatarCandidate(new GoogleAvatarCandidateEvent(USER_ID,
                "https://lh3.googleusercontent.com/a/abc=s96-c")))
                .doesNotThrowAnyException();

        verify(userAvatarRepository, never()).save(any());
    }

    private static byte[] pngBytes(int width, int height) throws IOException {
        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(image, "png", out);
        return out.toByteArray();
    }
}
