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

print_header () {
  echo
  echo " /*\\"
  echo "  *"
  echo "  * d88888b .d8888. d8888b. d8888b. .d888b.        d88888b db       .d88b.   .o88b. db   dD d88888b d8888b. "
  echo "  * 88'     88'  YP 88  '8D VP  '8D VP  '8D        88'     88      .8P  Y8. d8P  Y8 88 ,8P' 88'     88  '8D "
  echo "  * 88ooooo '8bo.   88oodD'   oooY'    odD'        88ooo   88      88    88 8P      88,8P   88ooooo 88oobY' "
  echo "  * 88~~~~~   'Y8b. 88~~~     ~~~b.  .88'   C8888D 88~~~   88      88    88 8b      88'8b   88~~~~~ 88'8b   "
  echo "  * 88.     db   8D 88      db   8D j88.           88      88booo. '8b  d8' Y8b  d8 88 '88. 88.     88 '88. "
  echo "  * Y88888P '8888Y' 88      Y8888P' 888888D        YP      Y88888P  'Y88P'   'Y88P' YP   YD Y88888P 88   YD "
  echo "  *"
  echo "  * ESP32-Flocker v1.0"
  echo "  * copyleft (c+) tobozo 2023"
  echo "  * https://github.com/tobozo"
  echo "  *"
  echo " \\*/"
  echo
}

print_usage () {
  echo ""
  echo ""
  echo "Usage: ./`basename $0` -j [JSON FILE] [OPTION]..."
  echo "- Load options and applications list from [JSON FILE]."
  echo "- Compile applications into a single firmware, flashable at 0x0 address."
  echo "- Optional args get overloaded by JSON settings:"
  echo "  -d [DEV]⁽¹⁾      Target port for flashing"
  echo "  -r [BAUDRATE]    Target baudrate (default=921600)"
  echo "  -f [FREQ]        Flash frequency (default=80m)"
  echo "  -i [MODE]        Flash mode (default=dio)"
  echo "  -s [SIZE]⁽²⁾     Flash size"
  echo "  -b [FQBN]        Fully qualified board name for this application set"
  echo "  -c [FILE]⁽³⁾     Path to arduino-cli binary"
  echo "  -e [FILE]⁽³⁾     Path to esptool.py"
  echo "  -g [FILE]⁽³⁾     Path to gen_esp32part.py"
  echo "  -p [FILE]⁽³⁾     Path to nvs_partition_gen.py"
  echo "  -n [FILE]⁽³⁾     Path to nvs_tool.py"
  echo "  -a [FILE]⁽³⁾     Path to boot_app0.bin"
  echo ""
  echo " ⁽¹⁾ Must be active if flashing"
  echo " ⁽²⁾ The value can only be expressed as Bytes e.g. 1MB, 2MB, 4MB, 8MB, 16MB"
  echo " ⁽³⁾ Will be downloaded/installed if missing"
  echo ""
}


get_options () {
  # collect shell arguments
  local OPTIND # import global reference, getopts need that when run from inside a function
  while getopts ":c:b:e:g:p:n:a:d:r:f:s:i:w:x:j:" opt; do
    case $opt in
#       c) arduino_cli="$OPTARG" ;;
#       b) fqbn="$OPTARG" ;;
#       e) esptool="$OPTARG" ;;
#       g) gen_esp32part="$OPTARG" ;;
#       p) nvs_partition_gen="$OPTARG" ;;
#       n) nvs_tool="$OPTARG" ;;
#       a) boot_app0_bin="$OPTARG" ;;
#       d) target_port="$OPTARG" ;;
#       r) target_baudrate="$OPTARG" ;;
#       f) flash_freq="$OPTARG" ;;
#       s) flash_size="$OPTARG" ;;
#       i) flash_mode="$OPTARG" ;;
#       w) factory_partsize="$OPTARG" ;;
#       x) flashfs_size="$OPTARG" ;;
      j) readonly json_settings_file="$OPTARG" ;;
      \?) echo;echo " ❌  Invalid option: -$OPTARG" >&2; print_usage; exit 1 ;;
    esac
    case $OPTARG in
      -*) echo "\n ❌  Option $opt needs a valid argument"; print_usage; exit 1 ;;
    esac
  done

  print_header # print the credits

  if [ "$1" == "clean" ];then # satisfy cleanup requests
    clean_folders
    exit
  fi

  read_json_settings # load json settings

  if [[ ! $@ =~ ^\-.+ ]]; then # leave if no arguments were provided
    print_usage; exit
  fi
}
# helper functions

clean_folders () {
  # clean all build files
  rm -Rf ${cfg[apps_dir]}
  echo " ✅  Cleaned up applications folders"
  rm -Rf ${cfg[build_dir]}
  rm -f "${logfile}"
  echo " ✅  Cleaned up build folders"
  rm -Rf ${cfg[tools_dir]}
  rm -Rf .arduino15
  echo " ✅  Cleaned up tools and packages folder"
  echo ""
}


die () {
  echo ""
  printf " ❌  ${RED}[FATAL] ${1}${NC}"
  echo ""
  export has_error="true"
  exit 1
}


hex_to_dec () {
  (( "$#" == 1 )) || die "${FUNCNAME[0]}() function needs one argument!"
  local -n hex_in=$1 # Note: $1 was passed by reference
  local hex_out=`echo $(($hex_in))` || return 1
  hex_in=$hex_out
}


dec_to_hex () {
  (( "$#" == 1 )) || die "${FUNCNAME[0]}() function needs one argument!"
  local -n dec_in=$1 # Note: $1 was passed by reference
  local dec_out=`printf "0x%x" "$dec_in"` || return 1
  dec_in=$dec_out
  return 0
}


byte_to_dec () {
  (( "$#" == 1 )) || die "${FUNCNAME[0]}() function needs one argument!"
  local -n bytes_in=$1 # Note: $1 was passed by reference
  [[ $bytes_in =~ GB$ ]] && { bytes_in=$((1024*1024*1024*${bytes_in%%GB*})); return 0; } # $1 unit is GByte
  [[ $bytes_in =~ MB$ ]] && { bytes_in=$((1024*1024*${bytes_in%%MB*}));      return 0; } # $1 unit is MByte
  [[ $bytes_in =~ KB$ ]] && { bytes_in=$((1024*${bytes_in%%KB*}));           return 0; } # $1 unit is KByte
  [[ $bytes_in =~ B$ ]]  && { bytes_in=$((${bytes_in%%B*}));                 return 0; } # $1 unit is Byte
  [[ $bytes_in =~ N$ ]]  && { bytes_in=$((0.5*${bytes_in%%N*}));             return 0; } # $1 unit is Nibble
  return 1 # false
}


to_dec () {
  local in=$1
  (( "$#" >= 1 )) || die "${FUNCNAME[0]}() function needs at least one argument!"
  (( "$#" > 1 ))  && local -n out=$2 || local out # Note: if provided, $2 was passed by reference
  [[ $1 =~ ^[0-9]{1,}$ ]]         &&                   { out=$in; return 0; } # $1 is integer
  [[ $1 =~ ^0x[0-9a-fA-F]{1,}$ ]] && hex_to_dec in  && { out=$in; return 0; } # $1 is hex
  [[ $1 =~ ^[0-9]+[M|K]B$ ]]      && byte_to_dec in && { out=$in; return 0; } # $1 is byte
  echo "$1 is neither an integer, hex or byte value"
  return 1 # false
}


to_hex () {
  (( "$#" == 2 )) || die "${FUNCNAME[0]}() function needs two arguments!"
  local val_in=$1
  local -n val_out=$2 # Note: $2 was passed by reference
  to_dec $val_in val_out || die "${FUNCNAME[0]}() $val_in can't be translated to decimal"
  dec_to_hex val_out || die "${FUNCNAME[0]}() $val_out can't be translated to hexadecimal"
}


read_json_settings () {
  [ -f "${json_settings_file}" ] || return # die "${FUNCNAME[0]}() Invalid json settings file: ${json_settings_file}"

  # Important: Application name MUST have the same value as #define SDU_APP_NAME in the target sketch
  #
  # Accepted Path types:
  #
  #     ArduinoIDE_Project: "/path/to/ArduinoIDE_Project/ArduinoIDE_Project.ino"   ends with ".ino"
  #     Platformio_Project: "/path/to/Platformio_Project/platformio.ini#env-name"  ends with "platformio.ini" with optional # for environment name
  #     Precompiled_Binary: "/path/to/Precompiled_Binary/Precompiled_Binary.bin"   ends with ".bin"
  #     Project_Source    : "https://domain/user/project.git"                      ends with ".git"

  local response=""

  # load optional settings
  response=`cat ${json_settings_file} | jq -r .fqbn`;             [ $response != "null" ] && cfg+=([fqbn]="${response}") || die "${FUNCNAME[0]}() No FQBN provided"
  response=`cat ${json_settings_file} | jq -r .build_properties`; [ $response != "null" ] && cfg+=([build_properties]="--build-property build.defines=\"${response}\"")
  response=`cat ${json_settings_file} | jq -r .factory.name`;     [ $response != "null" ] && cfg[name]="${response}"
  response=`cat ${json_settings_file} | jq -r .factory_partsize`; [ $response != "null" ] && cfg[factory_partsize]="${response}"
  response=`cat ${json_settings_file} | jq -r .name`;             [ $response != "null" ] && cfg[merged_bin_name]="${response}.bin"
  response=`cat ${json_settings_file} | jq -r .flash_size`;       [ $response != "null" ] && cfg[flash_size]="${response}"
  response=`cat ${json_settings_file} | jq -r .flash_freq`;       [ $response != "null" ] && cfg[flash_freq]="${response}"
  response=`cat ${json_settings_file} | jq -r .flash_mode`;       [ $response != "null" ] && cfg[flash_mode]="${response}"
  response=`cat ${json_settings_file} | jq -r .flashfs_type`;     [ $response != "null" ] && cfg[flashfs_type]="${response}" && cfg[mkfs_bin]="${cfg[tools_dir]}/mk${cfg[flashfs_type]}"
  response=`cat ${json_settings_file} | jq -r .flashfs_size`;     [ $response != "null" ] && cfg[flashfs_size]="${response}"
  response=`cat ${json_settings_file} | jq -r .target_port`;      [ $response != "null" ] && cfg[target_port]="${response}"
  response=`cat ${json_settings_file} | jq -r .target_baudrate`;  [ $response != "null" ] && cfg[target_baudrate]="${response}"

  # validate numeric/hex/byte values
  to_dec "${cfg[flash_size]}"       || die "${FUNCNAME[0]}() Invalid value for flash_size: ${cfg[flash_size]}"
  to_dec "${cfg[flashfs_size]}"     || die "${FUNCNAME[0]}() Invalid value for flashfs_size: ${cfg[flashfs_size]}"
  to_dec "${cfg[target_baudrate]}"  || die "${FUNCNAME[0]}() Invalid value for target_baudrate: ${cfg[target_baudrate]}"
  to_dec "${cfg[factory_partsize]}" || die "${FUNCNAME[0]}() Invalid value for factory_partsize: ${cfg[factory_partsize]}"

  local factory_path="`cat ${json_settings_file} | jq -r .factory.path`"

  [ ${cfg[name]} != "null" ] && [ ${cfg[name]} != "" ] || die "${FUNCNAME[0]}() No factory name provided"
  [ $factory_path != "null" ]        && [ $factory_path != "" ]        || die "${FUNCNAME[0]}() No factory path provided"

  for config in "${!cfg[@]}"; do
    printf " 📑  %-24s: %s\n" "$config" "${cfg[$config]}"
  done

  appsArray+=([${cfg[name]}]="${factory_path}")

  local apps_count=`cat ${json_settings_file} | jq -r .applications | jq length`
  [ "$apps_count" != 0 ] || die "${FUNCNAME[0]}() No applications found"
  for (( a=0; a<$apps_count; a++ )); do

    local depends="`cat ${json_settings_file} | jq -r .applications[$a].depends`"
    local libs_count=`echo $depends | jq length`
    if [ "$libs_count" != 0 ]; then
      for (( l=0; l<$libs_count; l++ )); do
        local lib="`cat ${json_settings_file} | jq -r .applications[$a].depends[$l]`"
        dependsArray+=($lib)
        echo " ♾   Added library dependency: $lib"
      done
    fi

    local app_name="`cat ${json_settings_file} | jq -r .applications[$a].name`"
    local app_path="`cat ${json_settings_file} | jq -r .applications[$a].path`"

    [ "${app_name}" != "null" ] && [ "${app_name}" != "" ] || continue # die "${FUNCNAME[0]}() No app name provided for application entry #${a}"
    [ "${app_path}" != "null" ] && [ "${app_path}" != "" ] || continue # die "${FUNCNAME[0]}() No app path provided for application entry #${a}"

    appsArray+=([${app_name}]="${app_path}")
  done
}


set_build_app_paths () {
  local fqbn_dirty=$1 # FQBN may have some compound values e.g. :DebugLevel=debug
  local fqbn_bits=(${fqbn_dirty//:/ })
  local fqbn_apps_dir="${cfg[apps_dir]}/${fqbn_bits[0]}/${fqbn_bits[1]}/${fqbn_bits[2]}"
  local fqbn_build_dir="${cfg[build_dir]}/${fqbn_bits[0]}/${fqbn_bits[1]}/${fqbn_bits[2]}"
  #export target_chip="${fqbn_bits[1]}" # pre-fill (will be replaced by arduino-cli query result)
  cfg[apps_dir]="${fqbn_apps_dir}"
  cfg[build_dir]="${fqbn_build_dir}"
  cfg[merged_bin]="${cfg[build_dir]}/${cfg[merged_bin_name]}"
  mkdir -p "${cfg[apps_dir]}" || die "${FUNCNAME[0]}() Unable to create dir ${cfg[apps_dir]}"
  mkdir -p "${cfg[build_dir]}" || die "${FUNCNAME[0]}() Unable to create dir ${cfg[build_dir]}"
}


file_status () {
  if [ -f "$1" ];then
    printf "${GREEN}$1${NC}"
  else
    die "${FUNCNAME[0]}() File $1 not found"
  fi
}


checkstatus () {
  local status=$?
  if [ ! $status -eq 0 ] || [ "$has_error" == "true" ];then die "$1"; exit 1; fi
}


fetch_if_no_exists () {
  local file=$1
  local url=$2
  if [ ! -f "$file" ]; then
    echo " 📥  Downloading `basename ${file}`"
    res=`wget -q $url -O $file`
    checkstatus "${FUNCNAME[0]}() Downloading $file failed for url $url"
  else
    echo " ✅  Found ${file}"
  fi
}


has_arduino_cli () {
  local has_file=`file_status "${cfg[arduino_cli]}"`
  local version=`${cfg[arduino_cli]} version`
  printf "${GREEN}${version}${NC}"
}


has_port () {
  if sh -c ": >${cfg[target_port]}" >/dev/null 2>/dev/null; then
    printf "${GREEN}${cfg[target_port]}${NC}\n"
    return 0
  else
    printf "${RED}${cfg[target_port]}${NC}\n"
    return 1
  fi
}


has_flash_mode () {
  if [ "${cfg[flash_mode]}" = "dio" ] || [ "${cfg[flash_mode]}" = "qio" ] || [ "${cfg[flash_mode]}" = "dout" ] || [ "${cfg[flash_mode]}" = "qout" ];then
    printf "${GREEN}${cfg[flash_mode]}${NC}\n"
    return
  fi
  printf "${RED}${cfg[flash_mode]}${NC}\n"
  die "${FUNCNAME[0]}() Unsupported flash mode ${cfg[flash_mode]}"
}


has_flash_freq () {
  if [ "${cfg[flash_freq]}" = "80m" ] || [ "${cfg[flash_freq]}" = "40m" ];then
    printf "${GREEN}${cfg[flash_freq]}${NC}\n"
    return
  fi
  printf "${RED}${cfg[flash_freq]}${NC}\n"
  die "${FUNCNAME[0]}() Unsupported flash freq ${cfg[flash_freq]}"
}


has_fs_size () {
  if [[ ${cfg[flashfs_size]} =~ ^[0-9]+[M|K]B$ ]]; then

    local flashfs_dec_size
    to_dec ${cfg[flashfs_size]} flashfs_dec_size || die "${FUNCNAME[0]}() Invalid flash_fs partition size (bad unit)"

    if (( $flashfs_dec_size < 65536 )) || (( $flashfs_dec_size % 65536 != 0 )) ; then
      die "${FUNCNAME[0]}() Invalid flash_fs partition size, must be at least 64KB *and* a multiple of 64KB"
    fi

    printf "${GREEN}${cfg[flashfs_size]} ($flashfs_dec_size Bytes)${NC}\n"
    return
  fi
  printf "${RED}${cfg[flashfs_size]}${NC}\n"
  die "${FUNCNAME[0]}() Unsupported ${cfg[flashfs_type]} size: ${cfg[flashfs_size]}"
}


has_part_size () {
  if [[ "${cfg[factory_partsize]}" =~ ^(1|2|4|8|16|32|64)MB$ ]]; then
    printf "${GREEN}${cfg[factory_partsize]}${NC}\n"
    return
  fi
  printf "${RED}${cfg[factory_partsize]}${NC}\n"
  die "${FUNCNAME[0]}() Unsupported flash size: ${cfg[factory_partsize]}}"
}



has_flash_size () {
  if [[ "${cfg[flash_size]}" =~ ^(4|8|16|32|64)MB$ ]]; then
    printf "${GREEN}${cfg[flash_size]}${NC}\n"
    return
  fi
  printf "${RED}${cfg[flash_size]}${NC}\n"
  die "${FUNCNAME[0]}() Unsupported flash size: ${cfg[flash_size]}"
}


fqbn_clean () {
  local fqbn_dirty=$1
  local fqbn_bits=(${fqbn_dirty//:/ })
  local fqbn_clean="${fqbn_bits[0]}:${fqbn_bits[1]}:${fqbn_bits[2]}"
  printf "$fqbn_clean"
}


has_fqbn () {
  local fqbn_clean=$(fqbn_clean "${cfg[fqbn]}")
  local fqbn_found=`${cfg[arduino_cli]} board listall | grep "${fqbn_clean}"`
  if test -z "$fqbn_found"
  then
    printf "${RED}${cfg[fqbn]}${NC}\n"
    die "${FUNCNAME[0]}() FQBN ${fqbn_clean} not found by arduino-cli"
    return
  fi
  printf "${GREEN}${cfg[fqbn]}${NC}\n"
}


get_board_name () {
  local fqbn_clean=`fqbn_clean "${cfg[fqbn]}"`
  local board_name_pref=`${cfg[arduino_cli]} board details -b "${fqbn_clean}" | grep 'Board name:'`
  if test -z "$board_name_pref"; then
    printf "${RED}${cfg[fqbn]}${NC}\n"
    die "${FUNCNAME[0]}() Board details for FQBN ${fqbn_clean} not found by arduino-cli"
    return
  fi
  local board_name="$(echo $board_name_pref | sed 's/Board name: \+//g' | sed 's/ *$//g')"
  printf "${board_name}"
}



monitor_process () {
  pid=$!
  echo
  echo "">>$logfile
  while [[ 1 ]]; do
    if ps -p $pid > /dev/null;then
      printf '\e[A\e[K'
      echo "`tail -1 ${logfile}`"
      sleep 0.05
    else
      break
    fi
  done
  printf '\e[A\e[K'
}



get_core_install () {
  local core=$1
  ( (${cfg[arduino_cli]} core update-index >> ${logfile} && ${cfg[arduino_cli]} core install ${core} >>${logfile}) || die "${FUNCNAME[0]}() Unable to install ${core}") &
  monitor_process
}




get_board_details () {
  if [ -f "${cfg[arduino_cli_config_file]}" ];then
    # ${arduino_cli} --config-file ${cfg[arduino_cli_config_file]} config dump
    cfg[arduino_cli]="${cfg[arduino_cli]} --config-file ${cfg[arduino_cli_config_file]}"
    echo "NEW CLI PATH: ${cfg[arduino_cli]}"
    #exit
  fi

  local fqbn_clean=`fqbn_clean "${cfg[fqbn]}"`
  #resp=`${cfg[arduino_cli]} board details --show-properties=expanded -b "${fqbn_clean}" > "${cfg[build_dir]}/board_details.txt" # 2>&1 >/dev/null`
  ${cfg[arduino_cli]} board details --show-properties=expanded -b "${fqbn_clean}" > "${cfg[build_dir]}/board_details.txt" # 2>&1 >/dev/null

  local status=$?

  if [ ! $status -eq 0 ];then # install missing board
    local fqbn_bits=(${cfg[fqbn]//:/ })
    echo " 📥  Downloading board package"
    get_core_install "${fqbn_bits[0]}:${fqbn_bits[1]}"
    ${cfg[arduino_cli]} board details --show-properties=expanded -b "${fqbn_clean}" > "${cfg[build_dir]}/board_details.txt"
  fi

  checkstatus "${FUNCNAME[0]}() arduino-cli failed"
  [ -f "${cfg[build_dir]}/board_details.txt" ] || die "${FUNCNAME[0]}() Unable to collect board details for FQBN ${cfg[fqbn]}"
}



get_build_mcu () {
  local fqbn_clean=`fqbn_clean "${cfg[fqbn]}"`
  # retrieve the "build.mcu" board property
  [ -f "${cfg[build_dir]}/board_details.txt" ] || return 1
  local build_mcu_pref=`cat "${cfg[build_dir]}/board_details.txt" | grep 'build\.mcu'`
  if test -z "$build_mcu_pref"
  then
    printf "${RED}${cfg[fqbn]}${NC}\n"
    die "${FUNCNAME[0]}() Board details for FQBN ${fqbn_clean} not found by arduino-cli"
    return 1
  fi
  local parts=(${build_mcu_pref//=/ }) # split "build.mcu=blah" at equal "=" sign
  local build_mcu="${parts[1]}"
  printf "$build_mcu"
}


had_build_mcu () {
  local build_mcu=`get_build_mcu` || die "${FUNCNAME[0]}() Can't get build MCU}"
  printf "${GREEN}$build_mcu${NC}"
}


has_factory_sketch () {
  for app in "${!appsArray[@]}";
  do
    if [ "$app" == "${cfg[name]}" ]; then
      local sketch_dir="${appsArray[$app]}"
      local ino_name="${sketch_dir##*/}"
      local ino_file="${sketch_dir}/${ino_name}.ino"
      if [ -f "${ino_file}" ];then
        printf "${GREEN}${ino_file}${NC}"
        return 0
      fi
    fi
  done
  printf "${RED}${cfg[name]}${NC}\n"
  die "${FUNCNAME[0]}() Sketch ${cfg[name]} not in list"
}


verify_app () {
  local sketch_dir=$1
  grep -R M5StackUpdater $sketch_dir 2>&1 >/dev/null || return 1
  grep -R checkFWUpdater $sketch_dir 2>&1 >/dev/null || return 1
  return 0
}



process_platformio_app () {
  local app=$1
  local path=$2
  local sketch_dir=`dirname $path`
  local tmp_env=${path#*#}
  local env

  local -A envs=(`(cd $sketch_dir && pio project config | grep 'env:')`)

  for i in "${envs[@]}"; do
    local envname="${i#*:}"
    if [[ "$i" = "$envname" ]]; then
        env=$tmp_env
      break
    fi
  done

  [ "$env" != "" ] || die "${FUNCNAME[0]}() platformio needs an env name"

  local dst_ino_bin="${app}.ino.bin" # compiled destination firmware name
  local src_bin_file="$sketch_dir/.pio/build/$env/firmware.bin"
  local dst_bin_file="${cfg[apps_dir]}/${dst_ino_bin}" # speculated binary path, the compilation will be skipped if it exists

  if [ ! -f "${dst_bin_file}" ];then # check if firmware was previously compiled

    echo " 🐍  Compiling ${app} ...";
    # local cli_response=`(cd $sketch_dir && pio run -e $env)`
    compile_app () {
      cd $sketch_dir && pio run -e $env >>${logfile} 2>&1 >${logfile}
    }
    verify_app "$sketch_dir" || die "${FUNCNAME[0]}() App $app does not ship with M5StackUpdater\n"
    ( compile_app ) &
    monitor_process

    checkstatus "${FUNCNAME[0]}() platformio failed: \n${cli_response}\n" # compilation check
    [ -f "${src_bin_file}" ] || die "${FUNCNAME[0]}() Could not find compiled ${src_bin_file}, aborting"
    cp "${src_bin_file}" "${dst_bin_file}" || die "${FUNCNAME[0]}() Copy failed on ${src_bin_file}\n" # copy compiled firmware to its destination path
    if [ -d "${sketch_dir}/data" ];then # also regroup flashfs contents if applicable
      cp -R "${sketch_dir}/data" "${cfg[apps_dir]}/"  || die "${FUNCNAME[0]}() Data copy failed on ${sketch_dir}/data\n"
    fi
  fi

  local filesize=`stat -c"%s" "${dst_bin_file}"` # print stats
  checkstatus "${FUNCNAME[0]}() Stat failed on ${dst_bin_file}\n"
  printf " ✅  %-36s - %s bytes\n" "${dst_ino_bin}" "${filesize}"
}


process_arduino_app () {
  local app="$1"
  local sketch_dir="$2"
  # last_dir="${dir##*/}"
  local ino_name="${sketch_dir##*/}"
  # echo $ino_name;exit;
  local src_ino_bin="${ino_name}.ino.bin" # compiled source firmware name
  local dst_ino_bin="${app}.ino.bin" # compiled destination firmware name
  local compilation_dir="${cfg[build_dir]}/${app}" # firmware build (dir)
  local src_bin_file="${compilation_dir}/${src_ino_bin}" # firmware build (full path)
  local dst_bin_file="${cfg[apps_dir]}/${dst_ino_bin}" # speculated binary path, the compilation will be skipped if it exists
  if [ ! -f "${dst_bin_file}" ];then # check if firmware was previously compiled
    mkdir -p "${compilation_dir}" # create build dir for this firmware
    echo " ♾  Compiling ${app} ...";
    compile_app () {
      ${cfg[arduino_cli]} compile --fqbn="${cfg[fqbn]}" ${cfg[build_properties]} --export-binaries --output-dir="${compilation_dir}" "${sketch_dir}" >> ${logfile} 2>&1 >>${logfile}
    }
    verify_app "$sketch_dir" || die "${FUNCNAME[0]}() App $app does not ship with M5StackUpdater\n"
    ( compile_app ) &
    monitor_process
    checkstatus "${FUNCNAME[0]}() arduino-cli failed:\n${cli_response}\n" # compilation check
    [ -f "${src_bin_file}" ] || die "${FUNCNAME[0]}() Could not find compiled ${src_bin_file}, aborting:\nCommand: $command\nResponse: (`tail -2 $logfile`) "
    cp "${src_bin_file}" "${dst_bin_file}" || die "${FUNCNAME[0]}() Copy failed on ${src_bin_file}\n" # copy compiled firmware to its destination path
    if [ -d "${sketch_dir}/data" ];then # also regroup flashfs contents if applicable
      cp -R "${sketch_dir}/data" "${cfg[apps_dir]}/" || die "${FUNCNAME[0]}() Data copy failed on ${sketch_dir}/data\n"
    fi
  fi
  local filesize=`stat -c"%s" "${dst_bin_file}"` # print stats
  checkstatus "${FUNCNAME[0]}() Stat failed on ${dst_bin_file}\n"
  printf " ✅  %-36s - %s bytes\n" "${dst_ino_bin}" "${filesize}"
}


process_binary_app () {
  local app="$1"
  local src_bin_file="$2"
  [ -f "${src_bin_file}" ] || die "${FUNCNAME[0]}() Binary not found: ${src_bin_file}"
  local dst_ino_bin="${app}.ino.bin" # compiled destination firmware name
  local dst_bin_file="${cfg[apps_dir]}/${dst_ino_bin}" # speculated binary path, the compilation will be skipped if it exists
  cp "${src_bin_file}" "${dst_bin_file}" || die "${FUNCNAME[0]}() Copy failed on ${src_bin_file}\n" # copy compiled firmware to its destination path
  local filesize=`stat -c"%s" "${dst_bin_file}"` # print stats
  checkstatus "${FUNCNAME[0]}() Stat failed on ${dst_bin_file}\n"
  printf " ✅  %-36s - %s bytes\n" "${dst_ino_bin}" "${filesize}"
}


sniff_path () {
  local path_to_sniff=$1
  local -n ret=$2 # Note: array was passed by reference
  [ -d "${path_to_sniff}" ] || die "${FUNCNAME[0]}() Path ${path_to_sniff} is not a dir"
  folder_name="${path_to_sniff##*/}"
  if [ "$(ls -A ${path_to_sniff} | grep "${folder_name}.ino")" ]; then
    ret="arduino-cli"
    return 0
  fi
  if [ "$(ls -A ${path_to_sniff} | grep "${folder_name}.bin")" ]; then
    ret="precompiled"
    return 0
  fi
  if [ "$(ls -A ${path_to_sniff} | grep 'platformio.ini')" ]; then
    ret="platformio"
    return 0
  fi
  return 1
}


dispatch_app () {
  local type=$1
  local name=$2
  local path=$3
  if [ "${type}" == "platformio" ]; then
    process_platformio_app "${name}" "${path}"
  elif [ "${type}" == "arduino-cli" ]; then
    process_arduino_app "${app}" "${path}"
  elif [ "${type}" == "precompiled" ]; then
    process_binary_app "${app}" "${path}"
  else
    die "${FUNCNAME[0]}() Unable to identify project $type at ${path}"
  fi
}


process_apps () {
  # install arduino dependencies, if any
  for lib in "${!dependsArray[@]}"; do # pull library dependency
    local resp=`${cfg[arduino_cli]} lib install $lib --no-overwrite 2>&1 >/dev/null`
    [[ "$resp" =~ "not found" ]]         && { printf " ⚠️  ${RED}Library dependency $lib not found${NC}\n"; continue; }
    [[ "$resp" =~ "already installed" ]] && { printf " ♾   ${GREEN}Found custom version of ${lib}${NC}\n"; continue; }
    [[ "$resp" =~ "error" ]]             && { printf " ⚠️  ${RED}${resp}${NC}\n"; continue; }
    printf " ♾   ${GREEN}Found local version of ${lib}${NC}\n"
    # echo $resp
  done
  # identify and dispatch apps
  for app in "${!appsArray[@]}"; do # compile applications
    local path="${appsArray[$app]}"
    if [[ "${path%%#*}" == *.ini ]];then
      dispatch_app "platformio" "${app}" "${appsArray[$app]}"
    elif  [[ "${path}" == *.bin ]];then # Precompiled_Binary
      dispatch_app "precompiled" "${app}" "${appsArray[$app]}"
    elif  [[ "${path}" == *.ino ]];then # ArduinoIDE_Project (ino file name)
      local arduino_app_dir=""
      local arduino_app_name=""
      if [ -f "${path}" ];then # path is a file
        arduino_app_dir=`dirname "${appsArray[$app]}"`
        arduino_app_name="${arduino_app_dir##*/}"
      elif [ -d "${path}" ];then
        arduino_app_dir=${path} # path is a folder name ending with ".ino"
        arduino_app_name="${arduino_app_dir##*/}" # app name should ends with ".ino" too
      else
        die "${FUNCNAME[0]}() ino path ${path} is neither a file nor a directory"
      fi
      [ "${app}" == "${arduino_app_name}" ] || die "${FUNCNAME[0]}() App name and dir name don't match : ${app} / ${arduino_app_name}"
      dispatch_app "arduino-cli" "${app}" "${arduino_app_dir}"
    elif [[ "${path}" == *.git ]];then # path is a git url (ending with ".git") TODO: properly check URL
      local project_type="none"
      [ -d "${cfg[build_dir]}/${app}" ] || git clone ${path} "${cfg[build_dir]}/${app}"
      [ -d "${cfg[build_dir]}/${app}" ] || die "${FUNCNAME[0]}() Failed to clone ${path} to ${cfg[build_dir]}/${app}"
      # sniff contents (look for ino files, then platformio.ini files, then bin files)
      sniff_path "${cfg[build_dir]}/${app}" project_type || die "${FUNCNAME[0]}() unable to identify project contents"
      dispatch_app "${project_type}" "${app}" "${cfg[build_dir]}/${app}"
    elif [[ -d "${path}" ]]; then # Unknown Project
      local project_type="none"
      # sniff contents (look for ino files, then platformio.ini files, then bin files)
      sniff_path "${appsArray[$app]}" project_type || die "${FUNCNAME[0]}() unable to identify project contents"
      dispatch_app "${project_type}" "${app}" "${appsArray[$app]}"
    fi
  done
  echo ""
}


check_tools () {
  mkdir -p ${cfg[tools_dir]} || die "${FUNCNAME[0]}() Unable to create dir ${cfg[tools_dir]}"
  set_build_app_paths "${cfg[fqbn]}" # process config settings
  # check arduino-cli path, install if necessary
  if [ ! -f "${cfg[arduino_cli]}" ];then
    echo " 📥  Installing arduino cli"
    fetch_if_no_exists "${cfg[tools_dir]}/install-arduino-cli.sh" "https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh"
    local res1=`chmod +x ${cfg[tools_dir]}/install-arduino-cli.sh`
    local res2=`BINDIR=${cfg[tools_dir]} ${cfg[tools_dir]}/install-arduino-cli.sh`
    cfg[arduino_cli]="${cfg[tools_dir]}/arduino-cli"
  fi

  # use arduino-cli to figure out the build mcu from the given FQBN
  #readonly target_chip=`get_build_mcu` || die "${FUNCNAME[0]}() Can't get build MCU}"

  # locate platformio
  if [ "`which platformio 2>/dev/null`" == "" ]; then
    die "${FUNCNAME[0]}() Platformio not found, install it manually. See https://docs.platformio.org/en/latest/core/installation/methods/installer-script.html"
    # echo " 📥  Installing platformio"
    # TODO: automate installation
    # 1) python package manager
    #    python3 -m pip install -U platformio
    # 2) python installer
    #    wget https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py && python3 get-platformio.py
    # 3) system package manager
    #    sudo apt install platformio
    #    pacman -Syu platformio
    #    brew install platformio
  fi

  if [ "`which php 2>/dev/null`" == "" ]; then
    die "${FUNCNAME[0]}() php binary not found, install it manually"
    # echo " 📥  Installing php"
  fi

  get_board_details

  # find esptool path, clone if necessary
  if [ ! -f "${cfg[esptool]}" ];then
    # try default git clone path
    cfg[esptool]="${cfg[tools_dir]}/esptool/esptool.py"
    if [ ! -f "${cfg[esptool]}" ]; then
      local pref_line=`cat "${cfg[build_dir]}/board_details.txt" | grep "runtime.tools.esptool_py.path"`
      local esptool_path="${pref_line#*=}"
      if [ ! -f "$esptool_path/esptool.py" ];then
        echo " 📥  Cloning esptool (missing $esptool_path)"
        local res=`git clone https://github.com/espressif/esptool --depth 1 --quiet ${cfg[tools_dir]}/esptool`
        [ -f "$esptool_path/esptool.py" ] || die "${FUNCNAME[0]}() Failed to clone esptool"
      else
        echo " ♾️  Using esptool.py from arduino-cli"
        cfg[esptool]="$esptool_path/esptool.py"
      fi
    fi
  fi

  # find gen_esp32part path, download from esp-idf repo if necessary
  if [ ! -f "${cfg[gen_esp32part]}" ];then
    local pref_line=`cat "${cfg[build_dir]}/board_details.txt" | grep "tools.gen_esp32part.cmd=" | tr -d '"'`
    local gen_esp32part_path="${pref_line#*=python3 }"
    if [ -f "$gen_esp32part_path" ];then
      cfg[gen_esp32part]="$gen_esp32part_path"
      echo " ♾️  Using gen_esp32part.py from arduino-cli"
    else
      cfg[gen_esp32part]="${cfg[tools_dir]}/gen_esp32part.py"
      fetch_if_no_exists "${cfg[gen_esp32part]}" "https://raw.githubusercontent.com/espressif/esp-idf/master/components/partition_table/gen_esp32part.py"
    fi
  fi
  # find nvs_partition_gen path, download from esp-idf repo if necessary
  if [ ! -f "$nvs_partition_gen" ];then
    cfg[nvs_partition_gen]="${cfg[tools_dir]}/nvs_partition_gen.py"
    fetch_if_no_exists "${cfg[nvs_partition_gen]}" "https://raw.githubusercontent.com/espressif/esp-idf/master/components/nvs_flash/nvs_partition_generator/nvs_partition_gen.py"
  fi
  # find nvs_tool path, download from esp-idf repo if necessary
  if [ ! -f "$nvs_tool" ];then
    cfg[nvs_tool]="${cfg[tools_dir]}/nvs_tool.py"
    fetch_if_no_exists "${cfg[nvs_tool]}" "https://raw.githubusercontent.com/espressif/esp-idf/master/components/nvs_flash/nvs_partition_tool/nvs_tool.py"
    fetch_if_no_exists "${cfg[tools_dir]}/nvs_logger.py" "https://raw.githubusercontent.com/espressif/esp-idf/master/components/nvs_flash/nvs_partition_tool/nvs_logger.py"
    fetch_if_no_exists "${cfg[tools_dir]}/nvs_parser.py" "https://raw.githubusercontent.com/espressif/esp-idf/master/components/nvs_flash/nvs_partition_tool/nvs_parser.py"
  fi
  # find boot_app0.bin path, download if necessary
  if [ ! -f "${cfg[boot_app0_bin]}" ];then
    local boot_app0_path=`cat "${cfg[build_dir]}/board_details.txt" | grep boot_app0 | tr ' ' '\n' | grep boot_app0 | tr -d '"'`
    if [ -f "$boot_app0_path" ];then
      echo " ♾️  Using boot_app0.bin from arduino-cli"
      cfg[boot_app0_bin]="$boot_app0_path"
    else
      cfg[boot_app0_bin]="boot_app0.bin"
      fetch_if_no_exists "${cfg[build_dir]}/${cfg[boot_app0_bin]}" "https://github.com/espressif/arduino-esp32/raw/master/tools/partitions/boot_app0.bin -O boot_app0.bin"
    fi
  fi
  # find flashfs tool path
  if [ ! -f "${cfg[mkfs_bin]}" ];then
    local mkfs_name="mk${cfg[flashfs_type]}"
    local pref_line=`cat "${cfg[build_dir]}/board_details.txt" | grep "tools.${mkfs_name}.path" | tr -d '"'`
    local mkfs_path="${pref_line#*=}"
    [ -f "${mkfs_path}/${mkfs_name}" ] || die "${FUNCNAME[0]}() Invalid ${mkfs_name} tool path: ${pref_line}"
    echo " ♾️  Using ${mkfs_name} from arduino-cli"
    cfg[mkfs_bin]="${mkfs_path}/${mkfs_name}"
  fi

}


print_config () {
  echo ""
  # verified settings

  value="$(has_fqbn)";                            printf " ⚙  %-38s : %s \n" "Fully qualified board name" "${value}"
  value="$(has_arduino_cli)";                     printf " ⚙  %-38s : %s \n" "Arduino CLI path" "${value}"
  value="$(file_status "${cfg[esptool]}")";            printf " ⚙  %-38s : %s \n" "esptool path" "${value}"
  value="$(file_status "${cfg[gen_esp32part]}")";      printf " ⚙  %-38s : %s \n" "ESP32 partition table generation tool" "${value}"
  value="$(file_status "${cfg[nvs_partition_gen]}")";  printf " ⚙  %-38s : %s \n" "esp-idf NVS partition generation tool" "${value}"
  value="$(file_status "${cfg[nvs_tool]}")";           printf " ⚙  %-38s : %s \n" "esp-idf NVS Partition Parser Utility" "${value}"
  value="$(file_status "${cfg[boot_app0_bin]}")";      printf " ⚙  %-38s : %s \n" "Boot switch file (boot_app0.bin)" "${value}"
  value="$(file_status "${cfg[mkfs_bin]}")";           printf " ⚙  %-38s : %s \n" "${cfg[flashfs_type]} path" "${value}"
  value="$(has_factory_sketch)";                  printf " ⚙  %-38s : %s \n" "FW-Menu sketch path" "${value}"
  # value="$(had_build_mcu)";                       printf " ⚙  %-38s : %s \n" "Target chip" "${value}"
  value="$(has_flash_size)";                      printf " ⚙  %-38s : %s \n" "Flash size" "${value}"
  value="$(has_part_size)";                       printf " ⚙  %-38s : %s \n" "Factory size" "${value}"
  value="$(has_fs_size)";                         printf " ⚙  %-38s : %s \n" "FlashFs size" "${value}"
  value="$(has_port)";                            printf " ⚙  %-38s : %s \n" "Target port" "${value}"
  value="$(has_flash_freq)";                      printf " ⚙  %-38s : %s \n" "Flash frequency" "${value}"
  value="$(has_flash_mode)";                      printf " ⚙  %-38s : %s \n" "Flash mode" "${value}"
  value="$(get_board_name)";                      printf " ⚙  %-38s : %s \n" "Board name" "${value}"
  # extrapolated/unverifiable settings
  printf " ⚙  %-38s : %s \n" "Target baudrate" "${cfg[target_baudrate]}"
  printf " ⚙  %-38s : %s \n" "Flash filesystem type" "${cfg[flashfs_type]}"
  printf " ⚙  %-38s : %s \n" "Applications dir" "${cfg[apps_dir]}"
  printf " ⚙  %-38s : %s \n" "Build dir" "${cfg[build_dir]}"
  printf " ⚙  %-38s : %s \n" "Output firmware file" "${cfg[merged_bin]}"
  echo ""
}


get_bootloader () {
  local sdk_path="`cat "${cfg[build_dir]}/board_details.txt" | grep 'compiler.sdk.path'`"
  if test -z "$sdk_path"
  then
    printf "${RED}${cfg[fqbn]}${NC}\n"
    die "${FUNCNAME[0]}() Board details for FQBN ${cfg[fqbn]} not found by arduino-cli"
    return
  fi

  local target_chip=`get_build_mcu` || die "${FUNCNAME[0]}() Can't get build MCU}"

  local bootloader_addr="`cat "${cfg[build_dir]}/board_details.txt" | grep 'build.bootloader_addr'`"
  if [ "$bootloader_addr" != "" ]; then
    local parts=(${bootloader_addr//=/ }) # split "build.bootloader_addr=blah" at equal "=" sign
    cfg[boot_addr]="${parts[1]}"
    echo " 🏢  Exported boot_addr: ${cfg[boot_addr]}"
  fi

  local parts=(${sdk_path//=/ }) # split "sdk.path=blah" at equal "=" sign
  local bootloader_path="${parts[1]}/bin/bootloader_${cfg[flash_mode]}_${cfg[flash_freq]}.elf"
  local elf2image_fmt=" --chip %s elf2image --flash_mode %s --flash_freq %s --flash_size %s -o %s/bootloader.bin %s"
  local esptool_args=`printf "${elf2image_fmt}" "${target_chip}" "${cfg[flash_mode]}" "${cfg[flash_freq]}" "${cfg[flash_size]}" "${cfg[build_dir]}" "${bootloader_path}"`
  local command="python3 ${cfg[esptool]} ${esptool_args}"
  local response=`${command}`
  echo " 📋  Generated bootloader.elf from `basename ${bootloader_path}`"
  [ -f "${cfg[build_dir]}/bootloader.bin" ] || die "${FUNCNAME[0]}() Failed to create ${cfg[build_dir]}/bootloader.bin:\n${command}\n${response}"
}


get_app0bin () {
  if [ ! -f "${cfg[build_dir]}/boot_app0.bin" ];then
    echo " 📋  Copying boot_app0.bin"
    cp "${cfg[boot_app0_bin]}" "${cfg[build_dir]}/boot_app0.bin"  || die "${FUNCNAME[0]}() Can't copy ${cfg[build_dir]}/boot_app0.bin"
  fi
}


get_flashfs () {
  rm -f ${cfg[build_dir]}/flashfs.bin
  if [ -d "${cfg[apps_dir]}/data" ] && [ "$(ls -A ${cfg[apps_dir]}/data)" ];then
    echo " 🗄️  Creating flashfs binary"
    local req_size=$(echo `du -hs ${cfg[apps_dir]}/data` | cut -d ' ' -f1)
    local hex_fs_size
    to_hex ${cfg[flashfs_size]} hex_fs_size || die "${FUNCNAME[0]}() invalid flashfs size"
    local command="${cfg[mkfs_bin]} -c ${cfg[apps_dir]}/data -s ${hex_fs_size} ${cfg[build_dir]}/flashfs.bin"
    local resp="`$command 2>&1 >/dev/null`"
    local if_error="${FUNCNAME[0]}() `basename ${cfg[mkfs_bin]}` needs $req_size and failed to create ${cfg[build_dir]}/flashfs.bin:\nCommand: ${command}\nResponse:${resp}"
    [[ "$resp" =~ "error|fail|fatal" ]] && die "${if_error}" # test is not 100% reliable as mkfs cli may respond differently
    [ -f "${cfg[build_dir]}/flashfs.bin" ] || die "${if_error}" # additional test
  fi
}


get_artifacts () {
  echo " 📑  Computing nvs.csv, partitions.csv and esptool.args files"
  rm -f ${cfg[build_dir]}/esptool.args
  local php_cmd="php ${cfg[gen_csv_part]} -l ${cfg[boot_addr]} -s ${cfg[flash_size]} -w ${cfg[factory_partsize]} -x ${cfg[flashfs_size]} -b ${cfg[build_dir]} -a ${cfg[apps_dir]} -f ${cfg[apps_dir]}/${cfg[name]}.ino.bin"
  local response="`${php_cmd}`"
  checkstatus "${FUNCNAME[0]}() ${cfg[gen_csv_part]} failed:\nCommand: ${php_cmd}\nResponse: $response\n"

  echo
  #echo "${response}"
  echo "  ${response//$'\n'/$'\n'  }."
  echo

  [ -f "${cfg[build_dir]}/esptool.args" ]   || die "${FUNCNAME[0]}() `basename ${cfg[gen_csv_part]}` failed to create esptool.args: ${response}"
  [ -f "${cfg[build_dir]}/nvs.csv" ]        || die "${FUNCNAME[0]}() `basename ${cfg[gen_csv_part]}` failed to create nvs.csv: ${response}"
  [ -f "${cfg[build_dir]}/partitions.csv" ] || die "${FUNCNAME[0]}() `basename ${cfg[gen_csv_part]}` failed to create partitions.csv: ${response}"

  echo " 🗄️  Generating partitions.bin"
  rm -f ${cfg[build_dir]}/partitions.bin
  response="`python3 ${cfg[gen_esp32part]} -q "${cfg[build_dir]}/partitions.csv" "${cfg[build_dir]}/partitions.bin"`"
  checkstatus "${FUNCNAME[0]}() `basename ${cfg[gen_esp32part]}` failed"
  [ -f "${cfg[build_dir]}/partitions.bin" ] || die "${FUNCNAME[0]}() `basename ${cfg[gen_esp32part]}` failed to create partitions.bin"

  echo " 🗄️  Generating nvs.bin"
  rm -f ${cfg[build_dir]}/nvs.bin
  response="`python3 ${cfg[nvs_partition_gen]} generate "${cfg[build_dir]}/nvs.csv" "${cfg[build_dir]}/nvs.bin" 0x5000`"
  checkstatus "${FUNCNAME[0]}() ${cfg[nvs_partition_gen]} failed: ${response}"
  [ -f "${cfg[build_dir]}/nvs.bin" ] || die "${FUNCNAME[0]}() ${cfg[nvs_partition_gen]} failed to create nvs.bin"
}


set_esptool_args () {
  # build args for flashing
  local target_chip=`get_build_mcu` || die "${FUNCNAME[0]}() Can't get build MCU}"
  local extra_flags_flash="--before default_reset --after hard_reset write_flash -e -z"
  local flags_fmt_flash="--chip %s --port %s --baud %s %s --flash_mode %s --flash_size %s --flash_freq %s"
  cfg+=([esptool_flags_flash]="`printf " ${flags_fmt_flash}" "${target_chip}" "${cfg[target_port]}" "${cfg[target_baudrate]}" "${extra_flags_flash}" "${cfg[flash_mode]}" "${cfg[flash_size]}" "${cfg[flash_freq]}"`")
  # build args for merging binaries
  local extra_flags_merge="merge_bin -o ${cfg[merged_bin]}"
  local flags_fmt_merge="--chip %s %s --flash_mode %s --flash_size %s"
  cfg+=([esptool_flags_merge]="`printf " ${flags_fmt_merge}" "${target_chip}" "${extra_flags_merge}" "${cfg[flash_mode]}" "${cfg[flash_size]}"`")
}


create_merged_bin () {
  # create merged binary
  echo " 📇  Loading esptool args"
  local esptool_args=`cat "${cfg[build_dir]}/esptool.args"`
  echo " ⚡  Creating flash binary"
  local response=`python3 "${cfg[esptool]}" ${cfg[esptool_flags_merge]} ${esptool_args}`
  local filesize=`stat -c"%s" "${cfg[merged_bin]}"` # print stats
  checkstatus "${FUNCNAME[0]}() Stat failed on ${cfg[merged_bin]}\n"
  printf " ✅  %-36s - %s bytes\n" "${cfg[merged_bin]}" "${filesize}"
  # echo " 🗄️  Binary ready at ${cfg[merged_bin]}"
}


flash_merged_bin () {
  if sh -c ": >${cfg[target_port]}" >/dev/null 2>/dev/null; then
    echo " ⚡  Flashing ${cfg[target_port]}"
    python3 "${cfg[esptool]}" ${cfg[esptool_flags_flash]} 0x0 "${cfg[merged_bin]}"
    checkstatus "${FUNCNAME[0]}() Flashing failed on ${cfg[target_port]}\n"
    pio device monitor -b 115200
  fi
  echo ""
}

