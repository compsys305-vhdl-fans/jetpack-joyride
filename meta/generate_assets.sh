#!/bin/zsh

find ../res -type f | grep "\.png" | xargs -I{} uv run image_conv.py {}
find ../res -type f | grep "[^2-9.]\.vhd" | grep -v "palette" | xargs -I{} zsh -c 'mv {} $(sed "s|/[^./]*\.|/palette.|" <<< "{}")'
rm $(find ../res | grep "\.vhd" | grep -v "palette")
