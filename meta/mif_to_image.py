import argparse
import math
import re
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


INDEX_PALETTE = [
    (0, 0, 0),
    (255, 255, 255),
    (230, 25, 75),
    (60, 180, 75),
    (255, 225, 25),
    (0, 130, 200),
    (245, 130, 48),
    (145, 30, 180),
]


@dataclass(frozen=True)
class MifData:
    width: int
    depth: int
    values: list[int]


def parse_mif(mif_path: Path) -> MifData:
    width = None
    depth = None
    values: list[int] = []
    in_content = False

    line_re = re.compile(r"^(\d+)\s*:\s*([0-9A-Fa-f]+)\s*;\s*$")
    range_re = re.compile(r"^\[(\d+)\.\.(\d+)\]\s*:\s*([0-9A-Fa-f]+)\s*;\s*$")

    with mif_path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("--"):
                continue

            if line.upper().startswith("WIDTH="):
                width = int(line.split("=", 1)[1].rstrip(";"))
                continue
            if line.upper().startswith("DEPTH="):
                depth = int(line.split("=", 1)[1].rstrip(";"))
                continue
            if line.upper().startswith("CONTENT BEGIN"):
                in_content = True
                continue
            if line.upper().startswith("END"):
                break

            if not in_content:
                continue

            match = line_re.match(line)
            if match:
                addr = int(match.group(1))
                value = int(match.group(2), 16)
                values.append((addr, value))
                continue

            match = range_re.match(line)
            if match:
                start = int(match.group(1))
                end = int(match.group(2))
                value = int(match.group(3), 16)
                for addr in range(start, end + 1):
                    values.append((addr, value))

    if width is None or depth is None:
        raise ValueError("MIF is missing WIDTH or DEPTH")

    data = [0] * depth
    for addr, value in values:
        if 0 <= addr < depth:
            data[addr] = value

    return MifData(width=width, depth=depth, values=data)


def infer_dimensions(depth: int, width: int | None, height: int | None) -> tuple[int, int]:
    if width is not None and height is not None:
        if width * height != depth:
            raise ValueError("Provided width/height do not match DEPTH")
        return width, height

    if width is not None:
        if depth % width != 0:
            raise ValueError("Provided width does not evenly divide DEPTH")
        return width, depth // width

    root = int(math.isqrt(depth))
    if root * root != depth:
        raise ValueError("DEPTH is not a perfect square; provide --width")
    return root, root


def render_image(mif: MifData, output_path: Path, width: int, height: int) -> None:
    image = Image.new("RGB", (width, height))
    pixels = []
    for value in mif.values:
        color_index = value & 0xF
        pixels.append(INDEX_PALETTE[color_index % len(INDEX_PALETTE)])

    image.putdata(pixels)
    image.save(output_path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render a MIF file to an image using a fixed high-contrast palette."
    )
    parser.add_argument("mif", type=Path, help="Path to the MIF file")
    parser.add_argument(
        "--output",
        type=Path,
        help="Output image path. If omitted, opens a viewer instead of writing.",
    )
    parser.add_argument(
        "--width",
        type=int,
        help="Override output width. Height is inferred from DEPTH.",
    )
    parser.add_argument(
        "--height",
        type=int,
        help="Override output height. Used with --width.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    mif_path = args.mif
    if not mif_path.is_file():
        raise FileNotFoundError(f"MIF not found: {mif_path}")

    mif = parse_mif(mif_path)
    width, height = infer_dimensions(mif.depth, args.width, args.height)
    output_path = args.output

    image = Image.new("RGB", (width, height))
    pixels = []
    for value in mif.values:
        color_index = value & 0xF
        pixels.append(INDEX_PALETTE[color_index % len(INDEX_PALETTE)])
    image.putdata(pixels)

    if output_path is None:
        image.show()
    else:
        image.save(output_path)
        print(f"Wrote image to: {output_path}")
