package com.lifey.progressphoto;

import com.lifey.progressphoto.dto.ProgressPhotoResponse;
import com.lifey.progressphoto.dto.ProgressPhotoUpdateRequest;
import com.lifey.progressphoto.service.ProgressPhotoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;

@Tag(name = "Progress Photos", description = "Private, dated body-progress photos (docs/80)")
@RestController
@RequestMapping("/api/v1/progress-photos")
@RequiredArgsConstructor
public class ProgressPhotoController {

    private final ProgressPhotoService service;

    @Operation(summary = "List progress photos (newest first)",
            description = "Metadata only — fetch the bytes from /{id}/image or /{id}/thumbnail.")
    @GetMapping
    public List<ProgressPhotoResponse> findAll() {
        return service.findAll();
    }

    @Operation(summary = "Upload a progress photo",
            description = "Accepts JPEG/PNG up to 10MB; the server stores a resized (max 1600px long "
                    + "side, never upscaled) main image and a 256x256 center-cropped thumbnail, both "
                    + "re-encoded to JPEG with all metadata (EXIF/GPS) stripped.")
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ProgressPhotoResponse create(
            @RequestParam("file") MultipartFile file,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate takenOn,
            @RequestParam(defaultValue = "OTHER") PhotoPose pose,
            @RequestParam(required = false) String note) {
        return service.create(file, takenOn, pose, note);
    }

    @Operation(summary = "Replace a photo's date, pose and note",
            description = "Full replacement of the metadata; a null note clears it. The image is not changed.")
    @PatchMapping("/{id}")
    public ProgressPhotoResponse update(@PathVariable Long id, @Valid @RequestBody ProgressPhotoUpdateRequest request) {
        return service.update(id, request);
    }

    @Operation(summary = "Get a progress photo",
            description = "Supports conditional GET via If-None-Match/ETag. 404 for a missing or foreign id.")
    @GetMapping("/{id}/image")
    public ResponseEntity<byte[]> getImage(
            @PathVariable Long id,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        ProgressPhotoImage image = service.findImage(id);
        return respond(image, ifNoneMatch, image.getImage());
    }

    @Operation(summary = "Get a progress photo thumbnail",
            description = "256x256 center-cropped JPEG for the timeline grid. Supports conditional GET.")
    @GetMapping("/{id}/thumbnail")
    public ResponseEntity<byte[]> getThumbnail(
            @PathVariable Long id,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        ProgressPhotoImage image = service.findImage(id);
        return respond(image, ifNoneMatch, image.getThumbnail());
    }

    @Operation(summary = "Delete a progress photo", description = "Hard delete of the photo and its image.")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        service.delete(id);
    }

    private ResponseEntity<byte[]> respond(ProgressPhotoImage image, String ifNoneMatch, byte[] body) {
        String etag = "\"" + image.getUpdatedAt().toEpochMilli() + "\"";
        if (etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).build();
        }
        return ResponseEntity.ok()
                .eTag(etag)
                .contentType(MediaType.parseMediaType(image.getContentType()))
                .cacheControl(CacheControl.noCache().cachePrivate())
                .body(body);
    }
}
