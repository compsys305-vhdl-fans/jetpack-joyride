#!/bin/zsh

find ../res -type f | rg "\.png" | xargs -I{} uv run image_conv.py {}
find ../res -type f | rg "[^2-9.]\.vhd" | xargs -I{} zsh -c 'mv {} $(sed "s|/[^./]*\.|/palette.|" <<< "{}")'
rm $(find ../res | rg "\.vhd" | rg -v "palette")