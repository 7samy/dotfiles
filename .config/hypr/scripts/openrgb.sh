#!/bin/bash

# Maximum attempts to apply profile
MAX_ATTEMPTS=3
ATTEMPT=1

# Start OpenRGB
openrgb &

# Wait a bit
sleep 3

# Try to apply profile multiple times (in case devices aren't ready yet)
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Attempt $ATTEMPT to apply OpenRGB profile..."
    
    # Apply profile (replace with your actual profile path)
    if openrgb --profile ~/.config/OpenRGB/azu.org; then
        echo "Profile applied successfully!"
        break
    else
        echo "Failed to apply profile, waiting 2 seconds..."
        sleep 2
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    echo "Warning: Could not apply OpenRGB profile after $MAX_ATTEMPTS attempts"
fi
