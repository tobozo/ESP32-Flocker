#!/bin/bash

#  ESP32-Flocker v1.0
#  copyleft (c+) tobozo 2023
#  https://github.com/tobozo

#
#
# foo () {
#   echo "$BASHPID";
#   echo "0" >log; sleep 1;
#   echo "1">>log; sleep 1;
#   echo "2">>log; sleep 1;
#   echo "3">>log; sleep 1;
#   echo "End";
# }
#
# # bar () { (foo &); pid="${!}"; echo "Child $pid"; while ps -p $pid > /dev/null; do tail -1 log; done; echo "done"; }
#
# process_manager () {
#   # pid_of_last_command_run_in_background=$!
#   mypid=$BASHPID
#   foo &
#   pid=$!
#   echo "Current pid: $BASHPID, forked pid: $pid"
#   while [[ 1 ]]; do
#     if ps -p $pid > /dev/null;then
#       printf '\e[A\e[K'
#       tail -1 log
#       sleep 0.1
#     else
#       break
#     fi
#   done
# }
#
# process_manager
#
# exit

source scripts/core.sh
