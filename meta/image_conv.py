import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


MAX_PALETTE_COLORS = 8
TRANSPARENT_COLOR_4BIT = (1, 0, 0)
MIF_WIDTH = 12


@dataclass(frozen=True)
class Palette:
    colors: tuple[tuple[int, int, int], ...]

    @classmethod
    def from_pixels(cls, pixels_rgba: list[tuple[int, int, int, int]]) -> "Palette":
        unique_colors: set[tuple[int, int, int]] = set()

        for r8, g8, b8, a8 in pixels_rgba:
            color = rgba_to_4bit_rgb(r8, g8, b8, a8)
            unique_colors.add(color)

        if len(unique_colors) > MAX_PALETTE_COLORS:
            raise ValueError(
                "Image has more than 8 unique 4-bit colors after conversion"
            )

        return cls(colors=tuple(sorted(unique_colors)))

    def index_of(self, color: tuple[int, int, int]) -> int:
        try:
            return self.colors.index(color)
        except ValueError as exc:
            raise ValueError(f"Color {color} not present in palette") from exc


def quantize_channel_4bit(value_8bit: int) -> int:
    return (value_8bit * 15 + 127) // 255


def rgba_to_4bit_rgb(r8: int, g8: int, b8: int, a8: int) -> tuple[int, int, int]:
    if a8 == 0:
        return TRANSPARENT_COLOR_4BIT
    return (
        quantize_channel_4bit(r8),
        quantize_channel_4bit(g8),
        quantize_channel_4bit(b8),
    )


def convert_image_to_palette_indexes(image_path: Path) -> tuple[Palette, list[list[int]]]:
    with Image.open(image_path) as image:
        rgba_image = image.convert("RGBA")
        width, height = rgba_image.size
        pixels = list(rgba_image.getdata())

    palette = Palette.from_pixels(pixels)

    index_rows: list[list[int]] = []
    for y in range(height):
        row: list[int] = []
        for x in range(width):
            r8, g8, b8, a8 = pixels[y * width + x]
            color = rgba_to_4bit_rgb(r8, g8, b8, a8)
            row.append(palette.index_of(color))
        index_rows.append(row)

    return palette, index_rows


def write_image_mif(
    output_path: Path,
    palette: Palette,
    index_rows: list[list[int]],
) -> None:
    if len(palette.colors) > MAX_PALETTE_COLORS:
        raise ValueError("Palette exceeds 8 colors")

    height = len(index_rows)
    width = len(index_rows[0]) if height else 0

    depth = width * height

    with output_path.open("w", encoding="utf-8") as mif_file:
        mif_file.write(f"WIDTH={MIF_WIDTH};\n")
        mif_file.write(f"DEPTH={depth};\n\n")
        mif_file.write("ADDRESS_RADIX=UNS;\n")
        mif_file.write("DATA_RADIX=HEX;\n\n")
        mif_file.write("CONTENT BEGIN\n")

        address = 0
        for y, row in enumerate(index_rows):
            for color_index in row:
                mif_file.write(f"{address}:{color_index:03X};\n")
                address += 1

        mif_file.write("END;\n")


def rgb444_hex(color: tuple[int, int, int]) -> str:
    red, green, blue = color
    return f"{red:X}{green:X}{blue:X}"


def write_vhdl_palette(
    output_path: Path,
    palette: Palette,
    constant_name: str,
) -> None:
    with output_path.open("w", encoding="utf-8") as vhdl_file:
        vhdl_file.write("LIBRARY IEEE;\n")
        vhdl_file.write("USE IEEE.STD_LOGIC_1164.ALL;\n\n")
        vhdl_file.write("PACKAGE image_palette_pkg IS\n")
        vhdl_file.write(
            "    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);\n"
        )
        vhdl_file.write(f"    CONSTANT {constant_name} : rgb444_palette_t := (\n")

        for index, color in enumerate(palette.colors):
            suffix = "," if index < len(palette.colors) - 1 else ""
            vhdl_file.write(f"        x\"{rgb444_hex(color)}\"{suffix}\n")

        vhdl_file.write("    );\n")
        vhdl_file.write("END PACKAGE image_palette_pkg;\n")

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert an image into a 12-bit MIF and a paste-ready VHDL RGB444 palette."
    )
    parser.add_argument(
        "image",
        type=Path,
        help="Path to the input image file",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Path to the output MIF file. Defaults to the input name with a .mif suffix.",
    )
    parser.add_argument(
        "--vhdl-output",
        type=Path,
        help="Path to the output VHDL palette file. Defaults to the input name with a .vhd suffix.",
    )
    parser.add_argument(
        "--vhdl-constant",
        default="IMAGE_PALETTE",
        help="Name of the VHDL palette constant to emit.",
    )
    return parser.parse_args()



if __name__ == "__main__":
    args = parse_args()
    image_path = args.image
    output_path = args.output or image_path.with_suffix(".mif")
    vhdl_output_path = args.vhdl_output or image_path.with_suffix(".vhd")

    if not image_path.is_file():
        raise FileNotFoundError(f"Image not found: {image_path}")

    palette, indexes = convert_image_to_palette_indexes(image_path)
    write_image_mif(output_path, palette, indexes)
    write_vhdl_palette(vhdl_output_path, palette, args.vhdl_constant)

    print("Palette (R,G,B each in 0..15):")
    for i, color in enumerate(palette.colors):
        print(f"  {i}: {color}")

    print(f"\nWrote MIF to: {output_path}")
    print(f"Wrote VHDL palette to: {vhdl_output_path}")