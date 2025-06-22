#!/bin/bash

# # Check if hyprlock is already running
# if pgrep -x "hyprlock" >/dev/null; then
#   echo "Warning: hyprlock is already running." | ts '[%Y-%m-%d %H:%M:%S]' >>/home/pallaire/lock.log
# else
#   echo "Starting hyprlock" | ts '[%Y-%m-%d %H:%M:%S]' >>/home/pallaire/lock.log
#   hyprlock | ts '[%Y-%m-%d %H:%M:%S]' >>/home/pallaire/lock.log &
# fi
# Check if hyprlock is already running
if pgrep -x "gtklock" >/dev/null; then
  echo "Warning: gtklock is already running." | ts '[%Y-%m-%d %H:%M:%S]' >>/home/pallaire/lock.log
else
  echo "Starting gtklock" | ts '[%Y-%m-%d %H:%M:%S]' >>/home/pallaire/lock.log
  gtklock | ts '[%Y-%m-%d %H:%M:%S]' >>/home/pallaire/lock.log &
fi
