from PIL import Image

def convert_background_to_mif(
    input_path,
    output_mif="background.mif",
    output_preview="background_preview.png",
    width=256,
    height=480
):
    img = Image.open(input_path).convert("RGB")
    print("Original:", img.size, img.mode)

    # Resize/crop to exact ROM size
    img = img.resize((width, height), Image.Resampling.NEAREST)
    img.save(output_preview)

    depth = width * height

    with open(output_mif, "w") as f:
        f.write("WIDTH=12;\n")
        f.write(f"DEPTH={depth};\n\n")
        f.write("ADDRESS_RADIX=UNS;\n")
        f.write("DATA_RADIX=HEX;\n\n")
        f.write("CONTENT BEGIN\n")

        addr = 0
        for y in range(height):
            for x in range(width):
                r, g, b = img.getpixel((x, y))

                # RGB888 -> RGB444
                r4 = r >> 4
                g4 = g >> 4
                b4 = b >> 4

                # 12-bit pixel: RRRRGGGGBBBB
                pixel_hex = f"{r4:X}{g4:X}{b4:X}"

                f.write(f"{addr} : {pixel_hex};\n")
                addr += 1

        f.write("END;\n")

    print("Done.")
    print("MIF saved to:", output_mif)
    print("Preview saved to:", output_preview)
    print("Depth:", depth)
    print("Width:", 12, "bits")


if __name__ == "__main__":
    convert_background_to_mif(
        input_path="bg.png",
        output_mif="background.mif",
        output_preview="background_preview.png",
        width=256,
        height=480
    )