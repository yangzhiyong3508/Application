# ESP32-WROOM-32 + INMP441

This example is a minimal microphone capture program for a standard `ESP32-WROOM-32` board using an `INMP441` I2S microphone.

Target:

- mono capture
- `16 kHz`
- `16-bit PCM`
- ESP-IDF style I2S driver
- light the on-board LED when the microphone level crosses a threshold

## Wiring

Default pin mapping in the example:

| INMP441 | ESP32-WROOM-32 | Notes |
| --- | --- | --- |
| `VDD` | `3V3` | Do not use 5V |
| `GND` | `GND` | Common ground |
| `SCK` | `GPIO26` | I2S bit clock, ESP32 output |
| `WS` | `GPIO25` | I2S word select / LRCLK, ESP32 output |
| `SD` | `GPIO34` | I2S data input, ESP32 input only pin |
| `L/R` | `GND` | Select left channel |
| `CHIPEN` | `3V3` | Keep microphone enabled |
| On-board LED | `GPIO2` | Default status LED output |

Recommended addition:

- `SD` to `GND` with a `100 kOhm` pull-down resistor. The INMP441 datasheet recommends this because the data line is tri-stated outside its active slot.

## Why the code reads 32-bit and outputs 16-bit

The `INMP441` outputs `24-bit` I2S audio. On ESP32, the stable approach is to receive samples in a `32-bit` container, then down-convert to `16-bit PCM`.

The conversion path used in the example is:

1. I2S DMA reads `int32_t` samples.
2. Shift right by `8` to drop the padding bits.
3. Shift right by another `8` to convert `24-bit` audio to `16-bit PCM`.

## LED trigger logic

The example treats a frame as "loud" when either of these is true:

- `peak >= 1200`
- `avg_abs >= 600`

To keep the LED from flickering, the LED turns off only after both conditions are quiet again and a `180 ms` hold time has passed. If your board LED is not on `GPIO2`, change `STATUS_LED_GPIO` in the source file.

## Files

- [inmp441_capture.c](/D:/OpenHarmony_Project/Application/docs/esp32-inmp441/inmp441_capture.c)

## How to use

1. Build the file inside an ESP-IDF project.
2. Flash it to an `ESP32-WROOM-32`.
3. Open a serial monitor at `115200`.
4. Speak near the microphone or tap near it.

The program prints:

- bytes captured
- sample count
- peak amplitude
- average absolute amplitude
- LED state
- the first few PCM16 samples

If the microphone is wired correctly, the amplitude should clearly change when you speak or tap near it, and the LED should light for louder sounds.

## Porting note for OpenHarmony LiteOS

This code intentionally uses the classic ESP32 I2S driver API so it is easy to port into the `device_soc_esp` based LiteOS application later.
