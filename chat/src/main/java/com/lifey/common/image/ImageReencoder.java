package com.lifey.common.image;

import com.lifey.common.exception.InvalidImageException;
import net.coobird.thumbnailator.Thumbnails;
import net.coobird.thumbnailator.geometry.Positions;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Shared re-encode pipeline for anything that stores an uploaded image
 * (user avatars, recipe photos): decoding via ImageIO doubles as validation
 * (malformed or non-image input simply fails to decode), and since only
 * decoded pixel data survives re-encoding, this also strips all metadata
 * (EXIF/GPS).
 */
public final class ImageReencoder {

    public static final String CONTENT_TYPE = "image/jpeg";

    private static final float JPEG_QUALITY = 0.85f;

    private ImageReencoder() {
    }

    /**
     * @throws InvalidImageException if the input can't be decoded as an image
     */
    public static BufferedImage decode(InputStream input) {
        BufferedImage source;
        try {
            source = ImageIO.read(input);
        } catch (IOException _) {
            throw new InvalidImageException("Could not read the image");
        }
        if (source == null) {
            throw new InvalidImageException("Not a valid JPEG or PNG image");
        }
        return source;
    }

    /** Center-cropped square, resized to {@code size}x{@code size}. */
    public static byte[] squareJpeg(BufferedImage source, int size) {
        int squareSide = Math.min(source.getWidth(), source.getHeight());
        return encode(Thumbnails.of(source)
                .sourceRegion(Positions.CENTER, squareSide, squareSide)
                .size(size, size));
    }

    /**
     * Resized so its longest side is {@code maxSide}, aspect ratio preserved.
     *
     * <p><b>This enlarges a smaller source</b> — it resizes <em>to</em> the
     * target, not within it. That is what the fixed-size recipe and avatar
     * slots want; anything that should leave a small picture alone wants
     * {@link #boundedJpeg} instead.
     */
    public static byte[] resizedJpeg(BufferedImage source, int maxSide) {
        return encode(Thumbnails.of(source).size(maxSide, maxSide).keepAspectRatio(true));
    }

    /**
     * Like {@link #resizedJpeg}, but never larger than the source: an image
     * that already fits is only re-encoded. For content whose natural size is
     * the right size — a photo someone sends in a chat — upscaling would cost
     * bytes and add no detail.
     */
    public static byte[] boundedJpeg(BufferedImage source, int maxSide) {
        if (Math.max(source.getWidth(), source.getHeight()) <= maxSide) {
            return encode(Thumbnails.of(source).scale(1.0));
        }
        return resizedJpeg(source, maxSide);
    }

    /** Convenience one-shot: {@link #decode} then {@link #squareJpeg}. */
    public static byte[] toSquareJpeg(InputStream input, int size) {
        return squareJpeg(decode(input), size);
    }

    private static byte[] encode(Thumbnails.Builder<BufferedImage> builder) {
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            builder.outputFormat("jpg").outputQuality(JPEG_QUALITY).toOutputStream(output);
            return output.toByteArray();
        } catch (IOException _) {
            throw new InvalidImageException("Could not process the image");
        }
    }
}
