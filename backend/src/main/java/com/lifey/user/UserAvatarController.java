package com.lifey.user;

import com.lifey.user.service.UserAvatarService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "User Avatar", description = "Profile picture upload/download")
@RestController
@RequestMapping("/api/v1/users/me/avatar")
@RequiredArgsConstructor
public class UserAvatarController {

    private final UserAvatarService service;

    @Operation(summary = "Get the current user's profile picture",
            description = "Supports conditional GET via If-None-Match/ETag. 404 if no picture is set.")
    @GetMapping
    public ResponseEntity<byte[]> get(
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        UserAvatar avatar = service.find();
        String etag = etagOf(avatar);
        if (etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).build();
        }
        return ResponseEntity.ok()
                .eTag(etag)
                .contentType(MediaType.parseMediaType(avatar.getContentType()))
                .cacheControl(CacheControl.noCache().cachePrivate())
                .body(avatar.getImage());
    }

    @Operation(summary = "Upload or replace the current user's profile picture",
            description = "Accepts JPEG/PNG up to 5MB; the server re-encodes it to a "
                    + "center-cropped 512x512 JPEG, stripping metadata.")
    @PutMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void upload(@RequestParam("file") MultipartFile file) {
        service.upload(file);
    }

    @Operation(summary = "Remove the current user's profile picture")
    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete() {
        service.delete();
    }

    private String etagOf(UserAvatar avatar) {
        return "\"" + avatar.getUpdatedAt().toEpochMilli() + "\"";
    }
}
