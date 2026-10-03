package com.lifey.progressphoto;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.progressphoto.dto.ProgressPhotoResponse;
import com.lifey.progressphoto.exception.InvalidProgressPhotoException;
import com.lifey.progressphoto.service.ProgressPhotoService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(ProgressPhotoController.class)
class ProgressPhotoControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    ProgressPhotoService service;

    private static ProgressPhotoResponse response(long id) {
        return new ProgressPhotoResponse(id, LocalDate.of(2026, 6, 18), PhotoPose.FRONT, "note",
                Instant.parse("2026-06-18T08:00:00Z"), Instant.parse("2026-06-18T08:00:00Z"));
    }

    private static ProgressPhotoImage image() {
        ProgressPhotoImage image = new ProgressPhotoImage();
        image.setImage(new byte[]{1, 2, 3});
        image.setThumbnail(new byte[]{9});
        image.setContentType("image/jpeg");
        image.setUpdatedAt(Instant.ofEpochMilli(1234));
        return image;
    }

    private static MockMultipartFile file() {
        return new MockMultipartFile("file", "p.jpg", "image/jpeg", new byte[]{1});
    }

    @Test
    void list_returnsOk() throws Exception {
        when(service.findAll()).thenReturn(List.of(response(1L)));

        mockMvc.perform(get("/api/v1/progress-photos"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].pose").value("FRONT"))
                .andExpect(jsonPath("$[0].takenOn").value("2026-06-18"));
    }

    @Test
    void upload_returnsCreated_withMetadata() throws Exception {
        when(service.create(any(), eq(LocalDate.of(2026, 6, 18)), eq(PhotoPose.SIDE), eq("hi")))
                .thenReturn(response(7L));

        mockMvc.perform(multipart("/api/v1/progress-photos").file(file())
                        .param("takenOn", "2026-06-18").param("pose", "SIDE").param("note", "hi"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(7));
    }

    @Test
    void upload_poseDefaultsToOther() throws Exception {
        when(service.create(any(), any(), eq(PhotoPose.OTHER), any())).thenReturn(response(7L));

        mockMvc.perform(multipart("/api/v1/progress-photos").file(file()).param("takenOn", "2026-06-18"))
                .andExpect(status().isCreated());
    }

    @Test
    void upload_rejectsMissingFileAndBadPose() throws Exception {
        mockMvc.perform(multipart("/api/v1/progress-photos").param("takenOn", "2026-06-18"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(multipart("/api/v1/progress-photos").file(file())
                        .param("takenOn", "2026-06-18").param("pose", "SIDEWAYS"))
                .andExpect(status().isBadRequest());
        verify(service, never()).create(any(), any(), any(), any());
    }

    @Test
    void upload_invalidMetadata_isBadRequest() throws Exception {
        when(service.create(any(), any(), any(), any())).thenThrow(new InvalidProgressPhotoException("future"));

        mockMvc.perform(multipart("/api/v1/progress-photos").file(file()).param("takenOn", "2999-01-01"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void image_returnsBytesWithEtag_andServes304OnMatch() throws Exception {
        when(service.findImage(5L)).thenReturn(image());

        mockMvc.perform(get("/api/v1/progress-photos/5/image"))
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ETAG, "\"1234\""))
                .andExpect(content().contentType(MediaType.IMAGE_JPEG))
                .andExpect(content().bytes(new byte[]{1, 2, 3}));

        mockMvc.perform(get("/api/v1/progress-photos/5/image").header(HttpHeaders.IF_NONE_MATCH, "\"1234\""))
                .andExpect(status().isNotModified());
    }

    @Test
    void thumbnail_returnsThumbnailBytes() throws Exception {
        when(service.findImage(5L)).thenReturn(image());

        mockMvc.perform(get("/api/v1/progress-photos/5/thumbnail"))
                .andExpect(status().isOk())
                .andExpect(content().bytes(new byte[]{9}));
    }

    @Test
    void image_foreignId_isNotFound() throws Exception {
        when(service.findImage(9L)).thenThrow(new ResourceNotFoundException("nope"));

        mockMvc.perform(get("/api/v1/progress-photos/9/image")).andExpect(status().isNotFound());
    }

    @Test
    void patch_validatesAndReturnsUpdated() throws Exception {
        when(service.update(eq(5L), any())).thenReturn(response(5L));

        mockMvc.perform(patch("/api/v1/progress-photos/5").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"takenOn\":\"2026-06-18\",\"pose\":\"BACK\",\"note\":null}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(5));

        mockMvc.perform(patch("/api/v1/progress-photos/5").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"takenOn\":\"2999-01-01\",\"pose\":\"BACK\"}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(patch("/api/v1/progress-photos/5").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"takenOn\":\"2026-06-18\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void delete_returnsNoContent_andUnknownIsNotFound() throws Exception {
        mockMvc.perform(delete("/api/v1/progress-photos/5")).andExpect(status().isNoContent());
        verify(service).delete(5L);

        doThrow(new ResourceNotFoundException("nope")).when(service).delete(9L);
        mockMvc.perform(delete("/api/v1/progress-photos/9")).andExpect(status().isNotFound());
    }
}
