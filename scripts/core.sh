#!/bin/bash
#
#  d88888b .d8888. d8888b. d8888b. .d888b.        d88888b db       .d88b.   .o88b. db   dD d88888b d8888b.
#  88'     88'  YP 88  `8D VP  `8D VP  `8D        88'     88      .8P  Y8. d8P  Y8 88 ,8P' 88'     88  `8D
#  88ooooo `8bo.   88oodD'   oooY'    odD'        88ooo   88      88    88 8P      88,8P   88ooooo 88oobY'
#  88~~~~~   `Y8b. 88~~~     ~~~b.  .88'   C8888D 88~~~   88      88    88 8b      88`8b   88~~~~~ 88`8b
#  88.     db   8D 88      db   8D j88.           88      88booo. `8b  d8' Y8b  d8 88 `88. 88.     88 `88.
#  Y88888P `8888Y' 88      Y8888P' 888888D        YP      Y88888P  `Y88P'   `Y88P' YP   YD Y88888P 88   YD
#
#  ESP32-Flocker v1.0
#  copyleft (c+) tobozo 2023
#  https://github.com/tobozo
#

source scripts/variables.sh
source scripts/functions.sh

get_options "$@" # read shell args, load json settings
check_tools # check/install tools
print_config # print retained settings
process_apps # collect and/or compile applications binaries
get_bootloader # create bootloader.bin
get_app0bin # copy boot_app0.bin
get_flashfs # copy flashfs.bin
get_artifacts # generate nvs.bin, partitions.bin and esptool.args
set_esptool_args # process esptool.args
create_merged_bin # merge applications into a single binary
flash_merged_bin # flash the merged binary

