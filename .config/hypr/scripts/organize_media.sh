#!/bin/bash
# organize_media_strict.sh - STRICT version - NO spaces allowed in filenames

DRY_RUN=true

IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "gif" "bmp" "webp")
VIDEO_EXTENSIONS=("mp4" "mov" "avi" "mkv" "wmv" "flv")

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_msg() {
    echo -e "${2}${1}${NC}"
}

# Escape special regex characters in folder name
escape_regex() {
    echo "$1" | sed 's/[][\.*^$()+?{}|]/\\&/g'
}

# Get highest image number (NO SPACES allowed)
get_highest_image_number() {
    local folder="$1"
    local folder_name="$2"
    local escaped_name=$(escape_regex "$folder_name")
    local highest=0
    
    for ext in "${IMAGE_EXTENSIONS[@]}"; do
        while IFS= read -r file; do
            local filename="$(basename "$file")"
            local filename_lower="${filename,,}"
            # STRICT: ^FolderNameNumber.extension$ - NO SPACE between name and number
            if [[ "$filename_lower" =~ ^${escaped_name,,}([0-9]+)\.${ext}$ ]]; then
                local num="${BASH_REMATCH[1]}"
                num=$((10#$num))
                [ $num -gt $highest ] && highest=$num
            fi
        done < <(find "$folder" -maxdepth 1 -type f -iname "*.${ext}" 2>/dev/null)
    done
    
    echo $highest
}

# Get highest video number (NO SPACES allowed)
get_highest_video_number() {
    local folder="$1"
    local folder_name="$2"
    local video_dir="$folder/Videos"
    local escaped_name=$(escape_regex "$folder_name")
    local highest=0
    
    if [ -d "$video_dir" ]; then
        while IFS= read -r file; do
            local filename="$(basename "$file")"
            local filename_lower="${filename,,}"
            # STRICT: ^FolderNameNumber.extension$ - NO SPACE
            if [[ "$filename_lower" =~ ^${escaped_name,,}([0-9]+)\.[a-z0-9]+$ ]]; then
                local num="${BASH_REMATCH[1]}"
                num=$((10#$num))
                [ $num -gt $highest ] && highest=$num
            fi
        done < <(find "$video_dir" -maxdepth 1 -type f 2>/dev/null)
    fi
    
    echo $highest
}

# Check if folder needs processing
folder_needs_processing() {
    local folder="$1"
    local folder_name="$2"
    local video_dir="$folder/Videos"
    local escaped_name=$(escape_regex "$folder_name")
    local needs_count=0
    
    # Check image files
    for ext in "${IMAGE_EXTENSIONS[@]}"; do
        while IFS= read -r -d '' file; do
            local filename="$(basename "$file")"
            local filename_lower="${filename,,}"
            # STRICT: Must match EXACTLY FolderNameNumber.extension
            if [[ ! "$filename_lower" =~ ^${escaped_name,,}([0-9]+)\.${ext}$ ]]; then
                ((needs_count++))
            fi
        done < <(find "$folder" -maxdepth 1 -type f -iname "*.${ext}" -not -path "$video_dir/*" -print0 2>/dev/null)
    done
    
    # Check video files in both locations
    for ext in "${VIDEO_EXTENSIONS[@]}"; do
        # Main folder
        while IFS= read -r -d '' file; do
            local filename="$(basename "$file")"
            local filename_lower="${filename,,}"
            if [[ ! "$filename_lower" =~ ^${escaped_name,,}([0-9]+)\.${ext}$ ]]; then
                ((needs_count++))
            fi
        done < <(find "$folder" -maxdepth 1 -type f -iname "*.${ext}" -print0 2>/dev/null)
        
        # Videos folder
        if [ -d "$video_dir" ]; then
            while IFS= read -r -d '' file; do
                local filename="$(basename "$file")"
                local filename_lower="${filename,,}"
                if [[ ! "$filename_lower" =~ ^${escaped_name,,}([0-9]+)\.${ext}$ ]]; then
                    ((needs_count++))
                fi
            done < <(find "$video_dir" -maxdepth 1 -type f -iname "*.${ext}" -print0 2>/dev/null)
        fi
    done
    
    echo $needs_count
}

process_folder() {
    local folder="$1"
    local folder_name="$(basename "$folder")"
    local escaped_name=$(escape_regex "$folder_name")
    local video_dir="$folder/Videos"
    
    # Check if folder needs processing
    local needs_count=$(folder_needs_processing "$folder" "$folder_name")
    if [ "$needs_count" -eq 0 ]; then
        print_msg "✓ '$folder_name' already perfectly organized - skipping" "$CYAN"
        return 0
    fi
    
    print_msg "Processing folder: $folder_name ($needs_count files need organization)" "$YELLOW"
    echo "--------------------------------------------------"
    
    # Create Videos directory
    if [ ! -d "$video_dir" ]; then
        print_msg "  Creating Videos directory..." "$GREEN"
        [ "$DRY_RUN" = false ] && mkdir -p "$video_dir"
    fi
    
    # Get starting numbers
    local img_start=$(get_highest_image_number "$folder" "$folder_name")
    local vid_start=$(get_highest_video_number "$folder" "$folder_name")
    local img_counter=$((img_start + 1))
    local vid_counter=$((vid_start + 1))
    
    print_msg "  Images: starting from $img_counter (found $img_start existing)" "$BLUE"
    print_msg "  Videos: starting from $vid_counter (found $vid_start existing)" "$BLUE"
    
    # Process IMAGE files (STRICT: NO SPACES)
    for ext in "${IMAGE_EXTENSIONS[@]}"; do
        while IFS= read -r -d '' file; do
            local filename="$(basename "$file")"
            local filename_lower="${filename,,}"
            
            # STRICT: Only Angelina1.png is correct, NOT Angelina 1.png
            if [[ "$filename_lower" =~ ^${escaped_name,,}([0-9]+)\.${ext}$ ]]; then
                print_msg "  ✓ Keeping: $filename" "$GREEN"
                continue
            fi
            
            local new_name="${folder_name}${img_counter}.${ext}"  # NO space
            local new_path="$folder/$new_name"
            
            print_msg "  Renaming: $filename -> $new_name" "$YELLOW"
            
            if [ "$DRY_RUN" = false ]; then
                mv "$file" "$new_path" 2>/dev/null && print_msg "    ✓ Done" "$GREEN" || print_msg "    ✗ Failed" "$RED"
            fi
            
            ((img_counter++))
        done < <(find "$folder" -maxdepth 1 -type f -iname "*.${ext}" -not -path "$video_dir/*" -print0 2>/dev/null)
    done
    
    # Collect ALL video files
    local -a all_video_files=()
    
    # From main folder
    for ext in "${VIDEO_EXTENSIONS[@]}"; do
        while IFS= read -r -d '' file; do
            all_video_files+=("$file")
        done < <(find "$folder" -maxdepth 1 -type f -iname "*.${ext}" -print0 2>/dev/null)
    done
    
    # From Videos folder
    if [ -d "$video_dir" ]; then
        for ext in "${VIDEO_EXTENSIONS[@]}"; do
            while IFS= read -r -d '' file; do
                all_video_files+=("$file")
            done < <(find "$video_dir" -maxdepth 1 -type f -iname "*.${ext}" -print0 2>/dev/null)
        done
    fi
    
    # Process video files
    if [ ${#all_video_files[@]} -gt 0 ]; then
        # Sort alphabetically
        IFS=$'\n' sorted_videos=($(printf '%s\n' "${all_video_files[@]}" | sort))
        unset IFS
        
        # Track used numbers
        local -A used_numbers
        
        # First: Identify correctly named files
        for file in "${sorted_videos[@]}"; do
            local filename="$(basename "$file")"
            local filename_lower="${filename,,}"
            local extension="${filename##*.}"
            extension="${extension,,}"
            
            if [[ "$filename_lower" =~ ^${escaped_name,,}([0-9]+)\.${extension}$ ]]; then
                local num="${BASH_REMATCH[1]}"
                used_numbers["$num"]=1
                # If file is in Videos folder and correctly named, keep it
                if [[ "$file" == "$video_dir/"* ]]; then
                    print_msg "  ✓ Already correct: Videos/$filename" "$GREEN"
                else
                    # Move to Videos folder
                    print_msg "  Moving to Videos: $filename" "$BLUE"
                    if [ "$DRY_RUN" = false ]; then
                        mv "$file" "$video_dir/" 2>/dev/null && print_msg "    ✓ Moved" "$GREEN" || print_msg "    ✗ Failed" "$RED"
                    fi
                fi
            fi
        done
        
        # Second: Process files that need renaming
        for file in "${sorted_videos[@]}"; do
            local filename="$(basename "$file")"
            local filename_lower="${filename,,}"
            local extension="${filename##*.}"
            extension="${extension,,}"
            
            # Skip if already correctly named (handled above)
            if [[ "$filename_lower" =~ ^${escaped_name,,}([0-9]+)\.${extension}$ ]]; then
                continue
            fi
            
            # Find next available number
            while [[ -n "${used_numbers[$vid_counter]}" ]]; do
                ((vid_counter++))
            done
            
            local new_name="${folder_name}${vid_counter}.${extension}"  # NO space
            local new_path="$video_dir/$new_name"
            
            print_msg "  Video: $filename -> Videos/$new_name" "$YELLOW"
            
            if [ "$DRY_RUN" = false ]; then
                [ ! -d "$video_dir" ] && mkdir -p "$video_dir"
                mv "$file" "$new_path" 2>/dev/null && print_msg "    ✓ Done" "$GREEN" || print_msg "    ✗ Failed" "$RED"
            fi
            
            used_numbers["$vid_counter"]=1
            ((vid_counter++))
        done
    fi
    
    print_msg "  Done processing $folder_name" "$YELLOW"
    echo ""
}

main() {
    [ -z "$1" ] && print_msg "Usage: $0 /path/to/folder [--run]" "$RED" && exit 1
    [ ! -d "$1" ] && print_msg "Error: Directory doesn't exist!" "$RED" && exit 1
    
    local parent_dir="$1"
    
    if [ "$2" = "--run" ]; then
        DRY_RUN=false
        print_msg "WARNING: LIVE MODE - files will be changed!" "$RED"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    else
        print_msg "DRY-RUN mode (use --run to actually change files)" "$YELLOW"
    fi
    
    print_msg "Processing: $parent_dir" "$YELLOW"
    echo "=========================================="
    echo ""
    
    while IFS= read -r -d '' folder; do
        [[ "$(basename "$folder")" != "Videos" ]] && [ -d "$folder" ] && process_folder "$folder"
    done < <(find "$parent_dir" -mindepth 1 -maxdepth 1 -type d -print0)
    
    echo ""
    [ "$DRY_RUN" = true ] && print_msg "DRY RUN COMPLETE" "$YELLOW" || print_msg "ORGANIZATION COMPLETE" "$GREEN"
}

main "$@"
