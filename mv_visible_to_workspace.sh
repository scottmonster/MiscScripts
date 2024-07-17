#!/usr/bin/env bash



# using xdotool get all windows in current workspace that are vissible and move them to the workspace specified. if one isn't specified, move them to the next workspace
# move_wins(){


  current_workspace=$(xdotool get_desktop)

  target_workspace=${1:-$(($current_workspace + 1))}

  echo "current workspace: $current_workspace"
  echo "target workspace: $target_workspace"
  # get the active window
  # active_window=$(xdotool getactivewindow)
  # get all windows in the current workspace
  

  windows=$(xdotool search --desktop $current_workspace . | while read id; do xprop -id $id | grep -q "_NET_WM_STATE_HIDDEN" || echo $id; done)
  # move all windows to the next workspace
  echo "xwindows:"
  for win in $windows; do
    # echo "move $win - $(xprop -id "$win" | awk '/WM_CLASS/{print $4}' | awk -F'"' '{print $2}') to workspace $target_workspace"
    # xdotool windowmove "$win" --desktop $target_workspace
    xdotool set_desktop_for_window "$win" $target_workspace
  done
  # return
 


# }




# move_wins























