#!/usr/bin/env bash


# case "$1" in
#   F11)
#     key=87; alt=113;
#     ;;
#   F12)
#     key=88; alt=114;
#     ;;
#   *)
    
#     ;;
# esac

script_name=$(basename $0)

instances=$(pgrep -c -f "$script_name")


# if [ $instances -gt 1 ]; then
# echo "already running" >> /home/scott/bin/lib/log.txt
#   exit
# fi

# echo "key: $key alt: $alt"

# Add a delay before simulating the key press
# sleep 0.2

# key=88;
key=F12;
alt=XF86AudioLowerVolume;
# alt=114;

if is_sound_playing; then
  # xte key $alt
  echo "$alt" >> /home/scott/bin/lib/log.txt
  xdotool key $alt
else
  # xte key $key
  echo "$key" >> /home/scott/bin/lib/log.txt
  xdotool key $key
  sleep 0.1
fi

echo "exiting" >> /home/scott/bin/lib/log.txt

# else
#     echo ""
# fi
# xdotool key F12


# F11/14/F15?
# 113/114/115
#    /88 /

# F11
# F12
# F13

# scan codes
# 0x57 0xd7
# 0x58 0xd8
# 0xe0 0x30 0xe0 0xb0

# fn
# 0xe0 0x20 0xe0 0xa0 
# 0xe0 0x2e 0xe0 0xae 
# 0xe0 0x30 0xe0 0xb0

# on keycodes id_sound send 100 series
# 87
# 88
# 115

# 113
# 114
# 115
