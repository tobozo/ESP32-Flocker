<?php

 /*\
  *
  * d88888b .d8888. d8888b. d8888b. .d888b.        d88888b db       .d88b.   .o88b. db   dD d88888b d8888b.
  * 88'     88'  YP 88  `8D VP  `8D VP  `8D        88'     88      .8P  Y8. d8P  Y8 88 ,8P' 88'     88  `8D
  * 88ooooo `8bo.   88oodD'   oooY'    odD'        88ooo   88      88    88 8P      88,8P   88ooooo 88oobY'
  * 88~~~~~   `Y8b. 88~~~     ~~~b.  .88'   C8888D 88~~~   88      88    88 8b      88`8b   88~~~~~ 88`8b
  * 88.     db   8D 88      db   8D j88.           88      88booo. `8b  d8' Y8b  d8 88 `88. 88.     88 `88.
  * Y88888P `8888Y' 88      Y8888P' 888888D        YP      Y88888P  `Y88P'   `Y88P' YP   YD Y88888P 88   YD
  *
  * ESP32-Flocker v1.0
  * copyleft (c+) tobozo 2023
  * https://github.com/tobozo
  *
 \*/



$ota_entries = [];
$coredump_size    = 0x10000;
$flash_size       = 0x1000000; // 16MB
$ota0_size        = 0x200000; // ~=2MB
$ota0_offset      = 0x10000;
$bootloader_addr  = 0x0;
$spiffs_max_size  = 0x2F0000;
$factory_max_size = 0x0F0000;
$offset           = $ota0_offset;
$max_ota_size     = $ota0_size*6; // 6x2MB app partition scheme
//$bin_size         = 0;
$empty_sha        = "0000000000000000000000000000000000000000000000000000000000000000";
$nvs_packed       = "";
$build_dir        = "build";
$apps_dir         = "applications";
$factory_bin_name = "M5Stack-FW-Menu.ino.bin";
$partitions_file  = "partitions.csv";
$nvs_file         = "nvs.csv";
$esptool_file     = "esptool.args";


if( !isset($argv) || count($argv)<=1) {
  // help screen
  echo sprintf(PHP_EOL."Usage:".PHP_EOL.PHP_EOL);
  echo sprintf(" php ".basename(__FILE__)." -f [FACTORY FILE] [OPTIONS]".PHP_EOL.PHP_EOL);
  echo sprintf(" Collate esptool-friendly args and csv files (partitions and NVS) from a set of provided binaries".PHP_EOL.PHP_EOL);
  echo sprintf("   -f [FILE]⁽¹⁾   Path to the Factory Firmware Launcher binary".PHP_EOL);
  echo sprintf("                  Note: will be flashed on OTA0 and migrated to factory on first boot".PHP_EOL);
  echo sprintf("   -a [DIR]       Path to the precompiled application binaries (default=%s)".PHP_EOL, $apps_dir);
  echo sprintf("   -b [DIR]       Output dir for partitions.csv, nvs.csv and esptool.args (default=%s)".PHP_EOL, $build_dir);
  echo sprintf("   -s [SIZE]⁽²⁾   Flash size (default=0x%06x)".PHP_EOL, $flash_size);
  echo sprintf("   -w [SIZE]⁽²⁾   Factory partition size (default=0x%06x)".PHP_EOL, $factory_max_size);
  echo sprintf("   -x [SIZE]⁽²⁾   FlashFS partition size (default=0x%06x)".PHP_EOL, $spiffs_max_size);
  echo sprintf("   -c [SIZE]⁽²⁾   OTA0 partition size (default=0x%06x) ".PHP_EOL, $ota0_size);
  echo sprintf("   -i [OFFSET]⁽³⁾ OTA0 partition offset (default=0x%06x)".PHP_EOL.PHP_EOL, $ota0_offset);
  echo sprintf("   -l [OFFSET]⁽³⁾ bootloader address (default=0x%x)".PHP_EOL.PHP_EOL, $bootloader_addr );
  echo sprintf("   ⁽¹⁾ Mandatory".PHP_EOL);
  echo sprintf("   ⁽²⁾ The value must be a multiple of 64KB".PHP_EOL);
  echo sprintf("       It can be expressed as Bytes, hexadecimal or decimal e.g. 1MB, 0x200000 or 2097152".PHP_EOL);
  echo sprintf("   ⁽³⁾ The value must be a multiple of 4KB".PHP_EOL);
  echo sprintf("       It can be expressed as hexadecimal or decimal e.g. 0x121000 or 1183744".PHP_EOL.PHP_EOL);
  echo sprintf(" Example:".PHP_EOL.PHP_EOL);
  echo sprintf("   php gen_csv_part.php -s 16MB -w 1MB -x 2MB -b path.to/precompiled/binaries -a path/to/build/dir -f path/to/factory-firmware.bin".PHP_EOL.PHP_EOL);
  exit(1);
}

// parse args
for( $i=1; $i<count($argv); $i+=2 ) {
  $name  = $argv[$i][1];
  $value = isset($argv[$i+1])?$argv[$i+1]:'true';
  switch ($name) {
    case 'f': $factory_bin_name = parse_arg($name, $value, 'file_read');  break; // path to the Firmware Launcher binary (will be flashed on OTA0, will migrate to factory at first boot)
    case 'a': $apps_dir         = parse_arg($name, $value, 'dir_read');   break; // path to the folder containing precompiled binaries, no ending slash
    case 'b': $build_dir        = parse_arg($name, $value, 'dir_read');   break; // path to the folder where csv files and esptool args will be saved
    case 's': $flash_size       = parse_arg($name, $value, 'size_value'); break; // flash size
    case 'w': $factory_max_size = parse_arg($name, $value, 'size_value'); break; // factory partition
    case 'x': $spiffs_max_size  = parse_arg($name, $value, 'size_value'); break; // spiffs partition
    case 'c': $ota0_size        = parse_arg($name, $value, 'size_value'); break; // OTA0 size
    case 'i': $ota0_offset      = parse_arg($name, $value, 'size_value'); break; // OTA0 offset
    case 'l': $bootloader_addr  = parse_arg($name, $value, 'size_value'); break; // OTA0 offset

    default: echo "Invalid option name: $name\n"; exit(1);
  }
}

if( !isset($factory_bin_name) || !file_exists($factory_bin_name) ) {
  echo "Invalid factory binary path\n";
  exit(1);
}

if( !is_dir($apps_dir) ) {
  echo "Applications dir $apps_dir does not exist\n";
  exit(1);
}

if( !is_dir($build_dir) || !is_writable($build_dir) ) {
  echo "Build dir $build_dir does not exist or is not writable\n";
  exit(1);
}

// set default esptool args, put the factory on OTA0
$esptool_args = [
  sprintf("0x%x $build_dir/bootloader.bin", $bootloader_addr ),
  "0x8000 $build_dir/partitions.bin",
  "0xe000 $build_dir/boot_app0.bin",
  "0x9000 $build_dir/nvs.bin",
  sprintf("0x%06x %s", $ota0_offset, $factory_bin_name )
];

// keep first OTA slot empty
$ota_num = 0;
$ota_entries[] = [
  'ota_num'   => $ota_num++,
  'name'      => 'OTA0',
  'filesize'  => $ota0_size,
  'partsize'  => $ota0_size,
  'sha256sum' => $empty_sha,
  'offset'    => $ota0_offset
];
$offset = $ota0_offset + $ota0_size;

append_nvs( $nvs_packed, $ota_entries[0] );


$coredump_offset = $flash_size - $coredump_size; // 0xff0000 on 16MB flash
$spiffs_offset   = $coredump_offset - $spiffs_max_size; // 0xD00000 on 16MB flash, TODO: align to 0x100000
$factory_offset  = $spiffs_offset - $factory_max_size; // 0xC10000 on 16MB flash
$max_ota_size    = $factory_offset - $ota0_offset;
$used_ota_size   = $ota0_size;

// verify all sizes are a multiple of 0x10000
assert_size( $flash_size );
assert_size( $ota0_size );
assert_size( $max_ota_size );
assert_size( $spiffs_max_size );
assert_size( $factory_max_size );
// make sure the factory partition fits on OTA0
assert( $factory_max_size<=$ota0_size );
// veryfy all offsets are a multiple of 0x1000
assert_offset( $ota0_offset );
assert_offset( $factory_offset );
assert_offset( $spiffs_offset );
assert_offset( $coredump_offset );

parse_arg($name, $partitions_file, 'file_write'); // path to output partitions.csv file
parse_arg($name, $nvs_file, 'file_write'); // path to output nvs.csv file
parse_arg($name, $esptool_file, 'file_write'); // path to output esptool.args file


$binaries = glob("$apps_dir/*.bin");

foreach( $binaries as $binary ) {

  if( basename( $binary ) == basename( $factory_bin_name ) ) continue;

  $filesize = filesize( $binary );
  $partsize = ( ( $filesize + 0x10000-1 ) & ~( 0x10000-1 ) );
  $sha256sum = hash_file('sha256', $binary);

  if( $used_ota_size + $partsize > $max_ota_size ) {
    echo "Partition full, skipping $binary\n";
    continue;
  }

  $esptool_args[] = sprintf('0x%06x %s', $offset, $binary );

  $file = [
    'ota_num'   => $ota_num++,
    'name'      => str_replace(".ino", "", $binary),
    'filesize'  => $filesize,
    'partsize'  => $partsize,
    'sha256sum' => $sha256sum,
    'offset'    => $offset
  ];

  $offset        += $partsize;
  $used_ota_size += $partsize;

  assert_size( $used_ota_size );
  assert_offset( $offset );

  append_nvs( $nvs_packed, $file );
  $ota_entries[] = $file;
}

if( file_exists( "$build_dir/flashfs.bin" ) ) {
  $esptool_args[] = sprintf('0x%06x %s', $spiffs_offset, "$build_dir/flashfs.bin" );
}


$partitions_csv  = "";
$partitions_csv .= sprintf("# %d Apps + Factory\n", count($ota_entries) );
$partitions_csv .= sprintf("# Name,   Type,  SubType,  Offset,   Size,     Flags, Comment\n");
$partitions_csv .= sprintf("nvs,      data,  nvs,        0x9000,   0x5000,,\n");
$partitions_csv .= sprintf("otadata,  data,  ota,        0xe000,   0x2000,,\n");

foreach($ota_entries as $pos => $file) { // fill existing
  $partitions_csv .= sprintf("ota_%x,    0,     %-9s %9s 0x%06x,,       %s\n",
    $file['ota_num'],
    'ota_'.$file['ota_num'].',',
    '0x'.dechex($file['offset']).',',
    $file['partsize'],
    basename($file['name'])
  );
}

if( $used_ota_size<$max_ota_size ) { // fit remaining
  $partitions_csv .= sprintf("ota_%x,    0,     %-9s 0x%06x, 0x%06x,,       %s\n", $ota_num, 'ota_'.$ota_num.',', $offset, $max_ota_size-$used_ota_size, "leftover" );
}

$partitions_csv .= sprintf("firmware, app,   factory,  0x%06x, 0x%06x,,       FW-Loader\n", $factory_offset, $factory_max_size);
$partitions_csv .= sprintf("spiffs,   data,  spiffs,   0x%06x, 0x%06x,,\n", $spiffs_offset, $spiffs_max_size);
$partitions_csv .= sprintf("coredump, data,  coredump, 0x%06x, 0x%06x,,\n", $coredump_offset, $coredump_size);


$nvs_csv = "key,type,encoding,value\n";
$nvs_csv .= "sdu,namespace,,\n";
$nvs_csv .= "partitions,data,base64,".base64_encode($nvs_packed)."\n";

file_put_contents( "$build_dir/$partitions_file", $partitions_csv );
file_put_contents( "$build_dir/$nvs_file", $nvs_csv );
file_put_contents( "$build_dir/$esptool_file", implode(" ", $esptool_args) );

echo $partitions_csv.PHP_EOL;
// echo $nvs_csv.PHP_EOL;


function parse_arg( $name, $value, $type )
{
  $error = sprintf("Invalid Arg %s (%s): %s\n", $name, $type, $value);
  switch( $type ) {
    case 'file_read':  if( file_exists($value) ) return $value; break;
    case 'file_write': if( is_writable(dirname($value)) ) return $value; break;
    case 'dir_read':   if( is_dir($value) ) return $value; break;
    case 'size_value':
      if( strtolower(substr($value, 0, 2))=='0x' ) { // hex value
        $value = preg_replace('/[^0-9A-F]/i', '', $value);
        return hexdec( $value );
      } else if( substr( $value, -1 ) == 'B' ) { // MB/GB/KB/B unit value
        $bytes = convertToBytes($value); if( is_int($bytes) )
        return $bytes;
      }
      // numerical value
      if( $value === $value+0 )
        return $value;
    break;
  }
  echo $error;
  exit(1);
}


function append_nvs( &$nvs_packed, $file )
{
  $nvs_packed .= pack('c', $file['ota_num'] );  // c = uint8_t ota_num{0};    // OTA partition number
  $nvs_packed .= pack('L', $file['filesize'] ); // L = uint32_t bin_size{0};   // firmware size
  $nvs_packed .= pack("H*", $file['sha256sum']);
  $appname = '/'.basename( $file['name'] ); // note: prepend slash
  $nvs_packed .= pack("a*", sprintf("%s", $appname));
  $remaining = 40-(strlen($appname)); // 'name' char[40]
  if( $remaining>0 ) { // zero-fill
    for( $i=0; $i<$remaining; $i++ ) {
      $nvs_packed .= pack('c', 0 );
    }
  }
}


function convertToBytes(string $from): ?int {
  $units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  $number = substr($from, 0, -2);
  $suffix = strtoupper(substr($from,-2));

  //B or no suffix
  if(is_numeric(substr($suffix, 0, 1))) {
    return preg_replace('/[^\d]/', '', $from);
  }

  $exponent = array_flip($units)[$suffix] ?? null;
  if($exponent === null) {
    return null;
  }

  return $number * (1024 ** $exponent);
}


function assert_size( $size )
{
  assert( $size>0 && $size%0x10000==0 ); // multiple of 65536
}


function assert_offset( $offset )
{
  assert( $offset>0 && $offset%0x1000==0 ); // multiple of 4096
}
