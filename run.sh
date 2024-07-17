#!/usr/bin/bash

dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
logfile="$dir/tmp/log.txt"
exec > >(tee -a "$logfile") 2>&1

# loop through passed in args
for arg in "$@"; do
  # res="$res $arg"
  echo "run.sh: $arg" 
done


res=" ran the script @ $(timestamp)"


echo "$res" 

i=0

while [ $i -lt 10 ]; do
  echo "waiting $i"
  i=$((i+1))
  sleep 1
done

echo "run.sh done"
clear
exit


