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


def load_pixels(image_path: Path) -> tuple[list[tuple[int, int, int, int]], int, int]:
    with Image.open(image_path) as image:
        rgba_image = image.convert("RGBA")
        width, height = rgba_image.size
        pixels = list(rgba_image.getdata())

    return pixels, width, height


def build_palette(image_paths: list[Path]) -> Palette:
    all_pixels: list[tuple[int, int, int, int]] = []
    for image_path in image_paths:
        pixels, _, _ = load_pixels(image_path)
        all_pixels.extend(pixels)

    return Palette.from_pixels(all_pixels)


def convert_image_to_palette_indexes(
    image_path: Path,
    palette: Palette,
) -> list[list[int]]:
    pixels, width, height = load_pixels(image_path)

    index_rows: list[list[int]] = []
    for y in range(height):
        row: list[int] = []
        for x in range(width):
            r8, g8, b8, a8 = pixels[y * width + x]
            color = rgba_to_4bit_rgb(r8, g8, b8, a8)
            row.append(palette.index_of(color))
        index_rows.append(row)

    return index_rows


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


def make_package_name(output_path: Path) -> str:
    parent_name = output_path.parent.name
    normalized = "".join(
        ch if (ch.isalnum() or ch == "_") else "_" for ch in parent_name
    ).lower()
    if not normalized or not normalized[0].isalpha():
        normalized = f"palette_{normalized}"
    return f"{normalized}_palette_pkg"


def write_vhdl_palette(
    output_path: Path,
    palette: Palette,
    constant_name: str,
    package_name: str,
) -> None:
    with output_path.open("w", encoding="utf-8") as vhdl_file:
        vhdl_file.write("LIBRARY IEEE;\n")
        vhdl_file.write("USE IEEE.STD_LOGIC_1164.ALL;\n\n")
        vhdl_file.write(f"PACKAGE {package_name} IS\n")
        vhdl_file.write(
            "    TYPE rgb444_palette_t IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(11 DOWNTO 0);\n"
        )
        vhdl_file.write(f"    CONSTANT {constant_name} : rgb444_palette_t := (\n")

        for index, color in enumerate(palette.colors):
            suffix = "," if index < len(palette.colors) - 1 else ""
            vhdl_file.write(f"        x\"{rgb444_hex(color)}\"{suffix}\n")

        vhdl_file.write("    );\n")
        vhdl_file.write(f"END PACKAGE {package_name};\n")

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert an image into a 12-bit MIF and a paste-ready VHDL RGB444 palette."
    )
    parser.add_argument(
        "images",
        nargs="+",
        type=Path,
        help="Input image file(s). The first image drives MIF output by default.",
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
    parser.add_argument(
        "--vhdl-package",
        help="Name of the VHDL package to emit. Defaults to a file-based name.",
    )
    parser.add_argument(
        "--palette-images",
        nargs="+",
        type=Path,
        help="Image file(s) to use when building the palette. Defaults to all input images.",
    )
    parser.add_argument(
        "--no-vhdl",
        action="store_true",
        help="Skip writing the VHDL palette file.",
    )
    parser.add_argument(
        "--palette-only",
        action="store_true",
        help="Only write the VHDL palette file (no MIF output).",
    )
    return parser.parse_args()



if __name__ == "__main__":
    args = parse_args()
    image_paths = [path for path in args.images]
    if not image_paths:
        raise ValueError("At least one image path is required")

    for image_path in image_paths:
        if not image_path.is_file():
            raise FileNotFoundError(f"Image not found: {image_path}")

    if args.output and len(image_paths) > 1:
        raise ValueError("--output can only be used with a single input image")

    palette_sources = args.palette_images or image_paths
    for palette_path in palette_sources:
        if not palette_path.is_file():
            raise FileNotFoundError(f"Palette image not found: {palette_path}")

    palette = build_palette(palette_sources)

    if not args.palette_only:
        for image_path in image_paths:
            output_path = args.output or image_path.with_suffix(".mif")
            indexes = convert_image_to_palette_indexes(image_path, palette)
            write_image_mif(output_path, palette, indexes)

    if not args.no_vhdl:
        vhdl_output_path = args.vhdl_output or image_paths[0].with_suffix(".vhd")
        package_name = args.vhdl_package or make_package_name(vhdl_output_path)
        write_vhdl_palette(vhdl_output_path, palette, args.vhdl_constant, package_name)

    print("Palette (R,G,B each in 0..15):")
    for i, color in enumerate(palette.colors):
        print(f"  {i}: {color}")

    if not args.palette_only:
        print("\nWrote MIF(s) for:")
        for image_path in image_paths:
            print(f"  {image_path.with_suffix('.mif')}")

    if not args.no_vhdl:
        vhdl_output_path = args.vhdl_output or image_paths[0].with_suffix(".vhd")
        print(f"Wrote VHDL palette to: {vhdl_output_path}")