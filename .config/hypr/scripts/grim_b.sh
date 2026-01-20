#!/bin/bash

file="/home/azu/Pictures/Ballin/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

grim -g "$(slurp)" "$file"


