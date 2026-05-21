from PIL import Image, ImageOps, ImageEnhance

def convert_image_to_32x32_binary(
    input_path,
    output_txt="sprite_32x32.txt",
    output_preview="sprite_32x32_preview.png",
    threshold=128,
    invert=True,
    resize_method="nearest"
):
    # 1. Open image
    img = Image.open(input_path).convert("RGBA")
    print("Original:", img.size, img.mode)

    # 2. Put transparent background on white
    white_bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
    img = Image.alpha_composite(white_bg, img)

    # 3. Convert to greyscale
    img = img.convert("L")

    # 4. Improve contrast before shrinking
    img = ImageOps.autocontrast(img)
    img = ImageEnhance.Contrast(img).enhance(1.8)

    # 5. Resize/compress to 32x32
    if resize_method.lower() == "nearest":
        resample = Image.Resampling.NEAREST
    elif resize_method.lower() == "lanczos":
        resample = Image.Resampling.LANCZOS
    else:
        resample = Image.Resampling.BOX

    img = img.resize((32, 32), resample)
    print("Compressed to:", img.size)

    # 6. Go row by row, column by column, convert pixels to binary
    rows = []
    preview = Image.new("1", (32, 32), color=1)
    preview_pixels = preview.load()

    for row in range(32):
        bit_row = ""

        for col in range(32):
            pixel = img.getpixel((col, row))

            if invert:
                # dark pixel = visible sprite
                bit = 1 if pixel < threshold else 0
            else:
                # bright pixel = visible sprite
                bit = 1 if pixel >= threshold else 0

            bit_row += str(bit)

            # Preview: 1-bit image uses 0 black, 1 white
            preview_pixels[col, row] = 0 if bit == 1 else 1

        rows.append(bit_row)
        print(f"Row {row:02d}: {bit_row}")

    # 7. Save text output for VHDL array
    with open(output_txt, "w") as f:
        for row in rows:
            f.write(f'"{row}",\n')

    # 8. Save preview BMP/PNG so you can check it visually
    preview.save(output_preview)

    print("\nDone.")
    print("Binary rows saved to:", output_txt)
    print("Preview saved to:", output_preview)


if __name__ == "__main__":
    convert_image_to_32x32_binary(
        input_path="Scientist_average-modified.png",
        output_txt="bird_sprite_32x32.txt",
        output_preview="bird_sprite_32x32_preview.png",
        threshold=128,
        invert=True,
        resize_method="nearest"
    )