package com.lifey.nutrition.recipe;

import com.lifey.nutrition.recipe.service.RecipeImageService;
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
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "Recipe Images", description = "Recipe photo upload/download")
@RestController
@RequestMapping("/api/v1/recipes/{recipeId}/image")
@RequiredArgsConstructor
public class RecipeImageController {

    private final RecipeImageService service;

    @Operation(summary = "Get a recipe's photo",
            description = "Supports conditional GET via If-None-Match/ETag. 404 if no photo is set.")
    @GetMapping
    public ResponseEntity<byte[]> get(
            @PathVariable Long recipeId,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        RecipeImage image = service.find(recipeId);
        return respond(image, ifNoneMatch, image.getImage());
    }

    @Operation(summary = "Get a recipe's photo thumbnail",
            description = "256x256 center-cropped JPEG, for list/grid views. Supports conditional GET "
                    + "via If-None-Match/ETag. 404 if no photo is set.")
    @GetMapping("/thumbnail")
    public ResponseEntity<byte[]> getThumbnail(
            @PathVariable Long recipeId,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        RecipeImage image = service.find(recipeId);
        return respond(image, ifNoneMatch, image.getThumbnail());
    }

    @Operation(summary = "Upload or replace a recipe's photo",
            description = "Accepts JPEG/PNG up to 10MB; the server stores a resized (max 1024px long "
                    + "side) main image and a 256x256 center-cropped thumbnail, both re-encoded to JPEG "
                    + "with metadata stripped.")
    @PutMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void upload(@PathVariable Long recipeId, @RequestParam("file") MultipartFile file) {
        service.upload(recipeId, file);
    }

    @Operation(summary = "Remove a recipe's photo")
    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long recipeId) {
        service.delete(recipeId);
    }

    private ResponseEntity<byte[]> respond(RecipeImage image, String ifNoneMatch, byte[] body) {
        String etag = etagOf(image);
        if (etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).build();
        }
        return ResponseEntity.ok()
                .eTag(etag)
                .contentType(MediaType.parseMediaType(image.getContentType()))
                .cacheControl(CacheControl.noCache().cachePrivate())
                .body(body);
    }

    private String etagOf(RecipeImage image) {
        return "\"" + image.getUpdatedAt().toEpochMilli() + "\"";
    }
}
