#!/bin/zsh
set -ex
setopt null_glob

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
res_dir="$script_dir/../res"

for dir in "$res_dir"/*; do
	if [[ -d "$dir" ]]; then
		pngs=($dir/*.png)
		if [[ -e "${pngs[1]}" ]]; then
			uv run image_conv.py --vhdl-output "$dir/palette.vhd" "${pngs[@]}"
		fi
	fi
done

find "$res_dir" -type f -name "*.vhd" ! -name "palette.vhd" -delete
