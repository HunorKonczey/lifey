"""One-off script to generate the Lifey app icon (teal background, white
dumbbell) and write it into every Android/iOS launcher-icon slot. Not part of
the app build — safe to delete after running.
"""
from PIL import Image, ImageDraw

SIZE = 1024
BG_TOP = (0, 137, 123)      # teal 700
BG_BOTTOM = (0, 105, 92)    # teal 800
FG = (255, 255, 255)


def make_master():
    img = Image.new("RGB", (SIZE, SIZE), BG_TOP)
    draw = ImageDraw.Draw(img)

    # Vertical gradient background.
    for y in range(SIZE):
        t = y / (SIZE - 1)
        r = round(BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t)
        g = round(BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t)
        b = round(BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

    # Rounded-square mask (squircle-ish), so the bitmap looks good even on
    # platforms/launchers that don't apply their own icon mask.
    radius = round(SIZE * 0.22)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=radius, fill=255)
    bg = Image.new("RGB", (SIZE, SIZE), BG_BOTTOM)
    bg.paste(img, (0, 0), mask)
    img = bg
    draw = ImageDraw.Draw(img)

    # Dumbbell: a horizontal bar with a rounded-square plate at each end and a
    # smaller inner collar, all bold and simplified so it stays legible at
    # 20x20px.
    cx, cy = SIZE // 2, SIZE // 2
    bar_half_len = round(SIZE * 0.20)
    bar_h = round(SIZE * 0.085)
    draw.rounded_rectangle(
        [cx - bar_half_len, cy - bar_h // 2, cx + bar_half_len, cy + bar_h // 2],
        radius=bar_h // 2, fill=FG,
    )

    plate_w = round(SIZE * 0.16)
    plate_h = round(SIZE * 0.46)
    plate_r = round(plate_w * 0.30)
    collar_w = round(SIZE * 0.075)
    collar_h = round(SIZE * 0.30)

    for side in (-1, 1):
        plate_cx = cx + side * (bar_half_len + collar_w // 2)
        draw.rounded_rectangle(
            [plate_cx - collar_w // 2, cy - collar_h // 2,
             plate_cx + collar_w // 2, cy + collar_h // 2],
            radius=round(collar_w * 0.3), fill=FG,
        )
        plate_cx = cx + side * (bar_half_len + collar_w + plate_w // 2)
        draw.rounded_rectangle(
            [plate_cx - plate_w // 2, cy - plate_h // 2,
             plate_cx + plate_w // 2, cy + plate_h // 2],
            radius=plate_r, fill=FG,
        )

    return img


def main():
    master = make_master()
    master.save("icon_master_1024.png")

    android_dir = "android/app/src/main/res"
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        resized = master.resize((size, size), Image.LANCZOS)
        resized.save(f"{android_dir}/{folder}/ic_launcher.png")

    ios_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for filename, size in ios_sizes.items():
        resized = master.resize((size, size), Image.LANCZOS)
        resized.save(f"{ios_dir}/{filename}")

    print("Done.")


if __name__ == "__main__":
    main()
