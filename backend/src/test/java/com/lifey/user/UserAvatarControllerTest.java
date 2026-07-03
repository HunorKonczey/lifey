package com.lifey.user;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.service.UserAvatarService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(UserAvatarController.class)
class UserAvatarControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    UserAvatarService service;

    @Test
    void get_returnsImageBytesWithEtag() throws Exception {
        when(service.find()).thenReturn(avatar(1L, "2026-07-01T00:00:00Z"));

        mockMvc.perform(get("/api/v1/users/me/avatar"))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "image/jpeg"))
                .andExpect(header().exists("ETag"));
    }

    @Test
    void get_returns304WhenEtagMatches() throws Exception {
        when(service.find()).thenReturn(avatar(1L, "2026-07-01T00:00:00Z"));
        Instant updatedAt = Instant.parse("2026-07-01T00:00:00Z");
        String etag = "\"" + updatedAt.toEpochMilli() + "\"";

        mockMvc.perform(get("/api/v1/users/me/avatar").header("If-None-Match", etag))
                .andExpect(status().isNotModified());
    }

    @Test
    void get_returns404WhenMissing() throws Exception {
        when(service.find()).thenThrow(new ResourceNotFoundException("No profile picture set"));

        mockMvc.perform(get("/api/v1/users/me/avatar"))
                .andExpect(status().isNotFound());
    }

    @Test
    void upload_returnsNoContent() throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", "avatar.png", "image/png", new byte[]{1, 2, 3});

        mockMvc.perform(multipart("/api/v1/users/me/avatar").file(file).with(req -> {
                    req.setMethod("PUT");
                    return req;
                }))
                .andExpect(status().isNoContent());

        verify(service).upload(any());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/users/me/avatar"))
                .andExpect(status().isNoContent());

        verify(service).delete();
    }

    private static UserAvatar avatar(Long id, String updatedAt) {
        UserAvatar avatar = new UserAvatar();
        avatar.setId(id);
        avatar.setContentType("image/jpeg");
        avatar.setImage(new byte[]{1, 2, 3});
        avatar.setSource(AvatarSource.UPLOAD);
        avatar.setUpdatedAt(Instant.parse(updatedAt));
        return avatar;
    }
}
