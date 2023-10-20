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

declare +i -r GREEN="\033[0;32m"
declare +i -r RED="\033[1;31m"
declare +i -r NC="\033[0m" # No Color

readonly BUILD_DIR="build"
readonly APPS_DIR="applications"
readonly TOOLS_DIR="tools"
readonly logfile="logfile.txt" # actually write only :-)

# Applications list, populated from json file .applications[]
declare -A appsArray=()
# Libraries dependencies for Arduino CLI, populated from json file .applications[].depends
declare -A dependsArray=()
# Script configuration, populated from json file
declare -A cfg=(
                                                   # PUBLIC: Populated from JSON
  [name]=""                                        #   Factory app sketch name, populated by json contents
  [flash_size]="16MB"                              #   Flash size
  [flash_freq]="80m"                               #   Flash freq
  [flash_mode]="dio"                               #   Flash mode
  [target_port]="/dev/ttyACM0"                     #   Target port
  [target_baudrate]="921600"                       #   Target baudrate
  [flashfs_type]="littlefs"                        #   Filesystem type (spiffs/littlefs/fatfs)
  [flashfs_size]="2MB"                             #   Flashfs partition size (SPIFFS, LittleFS, FatFS), defaults to 2MB
  [factory_partsize]="1MB"                         #   Factory partition max size, defaults to 1MB
                                                   # PRIVATE: Defaults overwritten by JSON settings
  [arduino_cli_config_file]="arduino-cli.yml"      #   Path to Arduino CLI options file
  [arduino_cli]="tools/arduino-cli"                #   Path to arduino-cli binary
  [esptool]="tools/esptool/esptool.py"             #   Path to esptool
  [gen_csv_part]="scripts/gen_csv_part.php"        #   Path to gen_csv_part.php tool (generate partitions.csv, nvs.csv and esptool.args)
  [gen_esp32part]="tools/gen_esp32part.py"         #   Path to gen_esp32part.py tool (generate partitions.bin from CSV file)
  [nvs_partition_gen]="tools/nvs_partition_gen.py" #   Path to nvs_partition_gen.py tool (create partition.bin from CSV file)
  [nvs_tool]="tools/nvs_tool.py"                   #   Path to nvs_tool.py (dump partition.bin contents to shell)
  [boot_app0_bin]="build/boot_app0.bin"            #   Path to boot_app0.bin
  [boot_addr]="0x0"                                #   Bootloader address
  [mkfs_bin]="tools/mklittlefs"                    #   Path to mklittlefs/mkspiffs/mkfatfs
  [merged_bin_name]="merged-flash.bin"             #   Path to output firmware
  [verify]="true"                                  #   Boolean, enable to check for M5StackUpdater integrity
)

