#!/bin/zsh
set -ex

for dir in ../res/*; do
	if [[ -d "$dir" ]]; then
		pngs=($dir/*.png)
		if [[ -e "${pngs[1]}" ]]; then
			uv run image_conv.py --palette-only --vhdl-output "$dir/palette.vhd" "${pngs[@]}"
			for img in "${pngs[@]}"; do
				uv run image_conv.py --no-vhdl "$img" --palette-images "${pngs[@]}"
			done
		fi
	fi
done

find ../res -type f -name "*.vhd" ! -name "palette.vhd" -delete
