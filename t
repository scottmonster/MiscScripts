#!/usr/bin/env bash

dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
target="$dir/wrk/getinput.sh"


# check if not target exists
if [ ! -f "$target" ]; then
    echo "target file does not exist"
    exit 1
fi

#check if not target is executable
if [ ! -x "$target" ]; then
    chmod +x "$target"
fi

# run target
"$target" "$@"


