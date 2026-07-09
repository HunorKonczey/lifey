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
        } catch (IOException e) {
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

    /** Resized so its longest side is at most {@code maxSide}, aspect ratio preserved. */
    public static byte[] resizedJpeg(BufferedImage source, int maxSide) {
        return encode(Thumbnails.of(source).size(maxSide, maxSide).keepAspectRatio(true));
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
        } catch (IOException e) {
            throw new InvalidImageException("Could not process the image");
        }
    }
}
