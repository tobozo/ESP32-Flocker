### ESP32-Flocker

ESP32-Flocker is a shell script used to concatenate several esp32 binaries and their application launcher into a single firmware.

The goal is to ease the creation of all-in-one-firmware application suites without having to manually edit the partitions.csv file
or requiring the creation of a custom bootloader.

In this scenario, the factory partition which holds the applications launcher is near the end of the flash space, just before
spiffs, OTA0 is available for flashing, and all space in between is used to stack the applications.

Example of generated partition scheme with 16MB flash size:

```csv
  # 9 Apps + Factory
  # Name,   Type,  SubType,  Offset,   Size,     Flags, Comment
  nvs,      data,  nvs,        0x9000,   0x5000,,
  otadata,  data,  ota,        0xe000,   0x2000,,
  ota_0,    0,     ota_0,     0x10000, 0x200000,,       OTA0 (available slot)
  ota_1,    0,     ota_1,    0x210000, 0x090000,,       WiFiManager
  ota_2,    0,     ota_2,    0x2a0000, 0x1f0000,,       BLEScanner
  ota_3,    0,     ota_3,    0x490000, 0x0c0000,,       I2CScanner
  ota_4,    0,     ota_4,    0x550000, 0x090000,,       SerialBridge
  ota_5,    0,     ota_5,    0x5e0000, 0x0c0000,,       HomeAssistant
  ota_6,    0,     ota_6,    0x6a0000, 0x090000,,       Camera
  ota_7,    0,     ota_7,    0x730000, 0x090000,,       Tetris
  ota_8,    0,     ota_8,    0x7c0000, 0x110000,,       Pacman
  ota_9,    0,     ota_9,    0x8d0000, 0x420000,,       Leftover space (available slot)
  firmware, app,   factory,  0xcf0000, 0x100000,,       Factory Launcher
  spiffs,   data,  spiffs,   0xdf0000, 0x200000,,
  coredump, data,  coredump, 0xff0000, 0x010000,,.
```

### Build process

The shell script will:

- Read a [JSON settings](#JSON settings format) file
- Gather/build the binaries for every applications, including the launcher
- Create a custom partition scheme
- Generate the NVS data for the launcher
- Merge all binaries
- Flash the ESP

**⚠️ All included applications must meet the [application requirements](#Application requirements).**

ℹ️ `applications[]` items listed in the JSON settings file and can be either of:

  - Path/git-url to .bin file
  - Path/git-url to arduino project source
  - Path/git-url to platformio project source

ℹ️ Project sources will be compiled with `arduino-cli` and `platformio` according to their nature.

ℹ️ Although the recommended application launcher with this shell script is M5StackUpdater's M5Stack-FW-Menu example,
any custom launcher will work as long as it's capable of enumerating the partitions and launching the other applications.




#### JSON settings format

```json
{
  "name": "MyApplicationSuite",
  "fqbn": "esp32:esp32:esp32:DebugLevel=debug",
  "build_properties": "-DMY_CUSTOM_FLAG",
  "factory": { "name": "M5Stack-FW-Menu", "path": "~/Arduino/libraries/M5Stack-SD-Updater/examples/M5Stack-FW-Menu" },
  "applications":[
    { "name":"WiFiManager",       "path": "/path/to/Arduino_Projects/WiFiManager/examples/SmartConfig" },
    { "name":"BLEScanner",        "path": "https://github.com/tobozo/ESP32-BLECollector.git", "depends":["SQLiteEsp32", "ESP32-Chimera-Core"] },
    { "name":"SerialBridge",      "path": "/path/to/Arduino_Projects/SerialBridge", "depends": [ "SoftwareSerial" ] },
    { "name":"HomeAssistant",     "path": "/path/to/Platformio_Projects/HomeAssistant#env-name" },
    { "name":"Camera",            "path": "/path/to/Precompiled_Projects/Camera.bin" },
    { "name":"Tetris",            "path": "" },
    { "name":"Pacman",            "path": "" }
  ]
}
```

#### Optional members:

  - `build_properties`: additional compilation flags e.g. `-DMY_CUSTOM_FLAG` for **arduino-cli**
  - `flash_size`: default is `16MB`
  - `flash_freq`: default is `80m`
  - `flash_mode`: default is `dio`
  - `target_port`: default is `/dev/ttyUSB0`
  - `baud_rate`: default is `921600`
  - `flashfs_type`: data partition type, default is `littlefs`
  - `flashfs_size`: data partition size, default is `2MB`
  - `factory_partsize`: factory partition size, default is `1MB`
  - `applications[].depends`: list of **arduino-cli** library dependencies for a given app, assumed as all satisfied if empty or missing



#### CI vs desktop use

Uncommenting the `directories` entry in `arduino-cli.yml` file **only makes sense if** no local installation of Arduino IDE exists
e.g. a CI is running the bash script and needs to cache downloads on a different volume to save bandwidth

In any other situation it is safe to keep the `directories` block commented out.



#### Application requirements

Every application must provide a way to load the factory partition.
This can be achieved either by calling `Flash::loadFactory()` from `M5StackUpdater` library, or by implementing this function:

Every `/data/` folders from the listed applications will be merged into a single filesystem image, and only one of spiffs/littlefs/fatfs
can be used (default is littlefs), obviously every application using the flash filesystem will have to agree on this.


```cpp

#include "esp_ota_ops.h"
#include "bootloader_common.h"

void loadFactory()
{
  auto factory = esp_partition_find( ESP_PARTITION_TYPE_APP,  ESP_PARTITION_SUBTYPE_APP_FACTORY, NULL );
  if( !factory ) {
    log_e( "this partitions scheme has no factory partition");
    return;
  }

  auto factory_partition = esp_partition_get(factory);

  if( !factory_partition ) {
    log_e( "Failed to find factory partition" );
    return;
  }
  // Set partition for boot
  auto err = esp_ota_set_boot_partition ( factory_partition );
  // restart on success
  if ( err != ESP_OK ) {
    log_e( "Failed to set boot partition" ) ;
  } else {
    log_i("Will reboot to factory partition");
    esp_restart() ;
  }
}
```



#### System Requirements

  - linux
  - bash
  - git
  - php
  - platformio

