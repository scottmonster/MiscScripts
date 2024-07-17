#!/usr/bin/env bash


# Get the device id for the keyboard
keyboard_id=$(xinput list | grep -i 'keyboard' | grep -o 'id=[0-9]*' | grep -o '[0-9]*')

# Check if a keyboard was found
if [ -z "$keyboard_id" ]; then
    echo "No keyboard device found."
    exit 1
fi

# Run xev and filter the output to show only key press and release events
xev -root | grep --line-buffered -E 'KeyPress|KeyRelease'