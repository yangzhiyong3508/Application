# WSL OpenHarmony ESP32 Skill

## Purpose

This skill captures the reliable workflow for building, flashing, and debugging `OpenHarmony LiteOS-M` projects for `ESP32` from `WSL`, plus the practical pitfalls discovered while working on `INMP441`, `MAX98357A`, Wi-Fi, and serial flashing.

## Use When

Use this skill when:

- the source tree lives inside WSL, especially under `/root/openharmony-esp32`
- the target is an `ESP32` board using `OpenHarmony LiteOS-M`
- firmware must be built in WSL and flashed either from Windows or directly from WSL
- USB serial access is flaky because of `usbipd` / WSL attachment state
- the board uses `I2S` peripherals like `INMP441` or `MAX98357A`

## Known Good Project Layout

- OpenHarmony source root:
  - `/root/openharmony-esp32/src/niobeu4_src`
- Python virtualenv with `hb`:
  - `/root/openharmony-esp32/.venv/bin`
- Xtensa toolchain:
  - `/root/openharmony-esp32/toolchains/xtensa-esp32-elf/bin`
- Product:
  - `iotlink@openvalley`
- Board/vendor app area:
  - `/root/openharmony-esp32/src/niobeu4_src/vendor/openvalley/niobeu4`

## Build Workflow

Always build from the actual source root, not from `/root/openharmony-esp32`.

```bash
cd /root/openharmony-esp32/src/niobeu4_src
export PATH=/root/openharmony-esp32/.venv/bin:/root/openharmony-esp32/toolchains/xtensa-esp32-elf/bin:$PATH
export GIT_CONFIG_GLOBAL=/root/openharmony-esp32/gitconfig
hb build -p iotlink@openvalley --ccache=false
```

If `hb: command not found`, the problem is almost always that `.venv/bin` is missing from `PATH`.

### Build Outputs

- `out/niobeu4/iotlink/bin/bootloader.bin`
- `out/niobeu4/iotlink/bin/partitions.bin`
- `out/niobeu4/iotlink/OHOS_Image.bin`

## Flash Workflow

### Prefer WSL flashing when the USB device is attached to WSL

If `usbipd list` shows the CH340 device as `Attached`, Windows no longer owns the `COM` port. Flash from WSL using `/dev/ttyUSB0`.

```bash
cd /root/openharmony-esp32/src/niobeu4_src
/root/openharmony-esp32/.venv/bin/python -m esptool --chip esp32 --port /dev/ttyUSB0 --baud 460800 \
  --before default_reset --after hard_reset write_flash -z \
  0x1000 out/niobeu4/iotlink/bin/bootloader.bin \
  0x8000 out/niobeu4/iotlink/bin/partitions.bin \
  0x10000 out/niobeu4/iotlink/OHOS_Image.bin
```

### Prefer Windows flashing when the USB device is not attached to WSL

Use the Windows Python path with `esptool`.

## USB / Serial Rules

Always check ownership before flashing:

```powershell
usbipd list
```

Interpretation:

- `Shared`: bind exists, but device is not currently attached into WSL
- `Attached`: use `/dev/ttyUSB0` in WSL
- Windows `COMx` disappears while attached to WSL

### Reattach to WSL

```powershell
usbipd attach --wsl Ubuntu-24.04 --busid <BUSID>
```

Then verify in WSL:

```bash
ls -l /dev/ttyUSB* /dev/ttyACM*
```

### Serial monitor in WSL

```bash
stty -F /dev/ttyUSB0 115200 raw -echo
cat /dev/ttyUSB0
```

If output looks stuck, press the board `EN/RST` button once.

## Python / pip Rule in WSL

Do not install Python tools into system Python if Debian `PEP 668` blocks it.

Use the project virtualenv:

```bash
/root/openharmony-esp32/.venv/bin/python -m pip install esptool
```

This avoids the `externally-managed-environment` error.

## Search Rule in WSL

`rg` may accidentally resolve to a Windows app path inside WSL and fail with `Permission denied`.

When that happens:

- use `grep`, `find`, `sed`
- or explicitly verify `which rg`

Do not assume `rg` is safe just because it exists in `PATH`.

## Network Rule

For ESP32 connecting over Wi-Fi to a host service:

- use the **Windows host LAN IP**, not the WSL `172.x.x.x` NAT IP
- get the correct IP from `ipconfig`
- if the backend runs on Windows, the ESP32 can reach it directly
- if the backend runs only inside WSL, you may need extra port exposure or forwarding

## Wi-Fi Lessons For This OpenHarmony ESP32 Port

This board adaptation has important limitations:

- scan result handling in `wifi_lite` had bugs and required fixes
- `WPA/WPA2` support in `esp_wifi_wpa.c` is stubbed / incomplete
- encrypted APs may fail even when the SSID is visible
- open APs are much more reliable on this port

Practical rule:

- for quick validation, use `2.4GHz + OPEN` hotspot
- only attempt `WPA2` after the open network path is confirmed

### Useful Wi-Fi diagnostics to print

- scan target SSID
- scan result list
- selected AP frequency / BSSID
- disconnect reason code

## Audio Rules

### INMP441

- standard I2S microphone
- no `MCLK`
- usually set `L/R -> GND` for left channel

### MAX98357A

- use `5V` on `VIN` for best volume
- common ground with ESP32 is mandatory
- speaker must connect to `SPK+ / SPK-`, not ground
- `SD/MODE` must not be left in shutdown state
- `GAIN` may float; use it later for loudness tuning

### Recommended bring-up order

1. Continuous test tone only
2. Startup beep only
3. Microphone loopback
4. Streaming / ASR

If step 1 fails, stop blaming software and inspect wiring.

## Good ESP32 Audio Pins Used In This Project

For the tested OpenHarmony demos:

- `BCK -> GPIO26`
- `WS/LRCLK -> GPIO25`
- `INMP441 SD -> GPIO27`
- `MAX98357A DIN -> GPIO22`
- `LED -> GPIO2`

## Quick Recovery Checklist

If flashing fails:

1. Run `usbipd list`
2. Confirm whether the board is on Windows `COMx` or WSL `/dev/ttyUSB0`
3. Reattach if needed
4. Recheck `ls /dev/ttyUSB*`
5. Retry flash with the correct side owning the device

If Wi-Fi fails:

1. Verify the hotspot is actually on `2.4GHz`
2. Prefer open network first
3. Confirm the SSID seen in logs matches the intended one
4. Inspect disconnect reason

If audio fails:

1. Test continuous tone first
2. Confirm `VIN=5V`
3. Confirm `SD/MODE` is high
4. Confirm `SPK+/-` wiring
5. Confirm the module really is `MAX98357A`

## Copy/Paste Command Set

Build:

```bash
cd /root/openharmony-esp32/src/niobeu4_src
export PATH=/root/openharmony-esp32/.venv/bin:/root/openharmony-esp32/toolchains/xtensa-esp32-elf/bin:$PATH
export GIT_CONFIG_GLOBAL=/root/openharmony-esp32/gitconfig
hb build -p iotlink@openvalley --ccache=false
```

Flash from WSL:

```bash
cd /root/openharmony-esp32/src/niobeu4_src
/root/openharmony-esp32/.venv/bin/python -m esptool --chip esp32 --port /dev/ttyUSB0 --baud 460800 \
  --before default_reset --after hard_reset write_flash -z \
  0x1000 out/niobeu4/iotlink/bin/bootloader.bin \
  0x8000 out/niobeu4/iotlink/bin/partitions.bin \
  0x10000 out/niobeu4/iotlink/OHOS_Image.bin
```

Serial log:

```bash
stty -F /dev/ttyUSB0 115200 raw -echo
cat /dev/ttyUSB0
```

## Notes

This skill is based on the concrete lessons learned in the `OpenHarmony + ESP32 + WSL` workflow for this workspace, not on generic theory.
