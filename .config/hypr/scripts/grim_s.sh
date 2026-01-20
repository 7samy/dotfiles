#!/bin/bash

file="/home/azu/Pictures/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

grim -g "$(slurp)" "$file"

wl-copy < "$file"

