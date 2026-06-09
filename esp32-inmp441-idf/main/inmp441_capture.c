#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

#include "driver/gpio.h"
#include "driver/i2s.h"
#include "esp_err.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define TAG "speaker_test"

#define SPEAKER_I2S_PORT                I2S_NUM_0
#define SPEAKER_SAMPLE_RATE_HZ          16000

/*
 * Default wiring for the current NiobeU4/MAX98357A test setup:
 * BCLK -> GPIO32
 * LRCLK/WS -> GPIO33
 * DIN -> GPIO14
 */
#define SPEAKER_BCK_GPIO                GPIO_NUM_32
#define SPEAKER_WS_GPIO                 GPIO_NUM_33
#define SPEAKER_DOUT_GPIO               GPIO_NUM_14

#define STATUS_LED_GPIO                 GPIO_NUM_2
#define STATUS_LED_ON_LEVEL             1
#define STATUS_LED_OFF_LEVEL            (!STATUS_LED_ON_LEVEL)

#define FRAME_SAMPLES_PER_CHANNEL       320
#define SPEAKER_CHANNELS                2
#define FRAME_SAMPLES_TOTAL             (FRAME_SAMPLES_PER_CHANNEL * SPEAKER_CHANNELS)
#define DMA_BUFFER_COUNT                6
#define DMA_BUFFER_LENGTH               160

#define TONE_FREQUENCY_HZ               1000
#define TONE_AMPLITUDE_PCM16            22000
#define LOG_FRAME_INTERVAL              40

static int16_t s_tone_frame[FRAME_SAMPLES_TOTAL];

static esp_err_t status_led_init(void)
{
    esp_err_t ret = gpio_reset_pin(STATUS_LED_GPIO);
    if (ret != ESP_OK) {
        return ret;
    }

    ret = gpio_set_direction(STATUS_LED_GPIO, GPIO_MODE_OUTPUT);
    if (ret != ESP_OK) {
        return ret;
    }

    return gpio_set_level(STATUS_LED_GPIO, STATUS_LED_OFF_LEVEL);
}

static void set_status_led(bool on)
{
    gpio_set_level(STATUS_LED_GPIO, on ? STATUS_LED_ON_LEVEL : STATUS_LED_OFF_LEVEL);
}

static esp_err_t speaker_i2s_init(void)
{
    const i2s_config_t i2s_config = {
        .mode = I2S_MODE_MASTER | I2S_MODE_TX,
        .sample_rate = SPEAKER_SAMPLE_RATE_HZ,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = DMA_BUFFER_COUNT,
        .dma_buf_len = DMA_BUFFER_LENGTH,
        .use_apll = false,
        .tx_desc_auto_clear = false,
        .fixed_mclk = 0,
    };

    const i2s_pin_config_t pin_config = {
        .bck_io_num = SPEAKER_BCK_GPIO,
        .ws_io_num = SPEAKER_WS_GPIO,
        .data_out_num = SPEAKER_DOUT_GPIO,
        .data_in_num = I2S_PIN_NO_CHANGE,
    };

    esp_err_t ret = i2s_driver_install(SPEAKER_I2S_PORT, &i2s_config, 0, NULL);
    if (ret != ESP_OK) {
        return ret;
    }

    ret = i2s_set_pin(SPEAKER_I2S_PORT, &pin_config);
    if (ret != ESP_OK) {
        i2s_driver_uninstall(SPEAKER_I2S_PORT);
        return ret;
    }

    ret = i2s_set_clk(
        SPEAKER_I2S_PORT,
        SPEAKER_SAMPLE_RATE_HZ,
        I2S_BITS_PER_SAMPLE_16BIT,
        I2S_CHANNEL_STEREO
    );
    if (ret != ESP_OK) {
        i2s_driver_uninstall(SPEAKER_I2S_PORT);
        return ret;
    }

    return i2s_zero_dma_buffer(SPEAKER_I2S_PORT);
}

static void fill_tone_frame(void)
{
    size_t i = 0;
    const size_t half_period_samples =
        (size_t)(SPEAKER_SAMPLE_RATE_HZ / (TONE_FREQUENCY_HZ * 2U));

    for (i = 0; i < FRAME_SAMPLES_PER_CHANNEL; ++i) {
        const bool high_phase = ((i / half_period_samples) & 0x01U) == 0;
        const int16_t sample = high_phase ? TONE_AMPLITUDE_PCM16 : (int16_t)-TONE_AMPLITUDE_PCM16;
        s_tone_frame[i * 2] = sample;
        s_tone_frame[i * 2 + 1] = sample;
    }
}

static esp_err_t write_tone_frame(size_t *bytes_written)
{
    return i2s_write(
        SPEAKER_I2S_PORT,
        s_tone_frame,
        sizeof(s_tone_frame),
        bytes_written,
        portMAX_DELAY
    );
}

void app_main(void)
{
    esp_err_t ret = status_led_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "LED init failed: %s", esp_err_to_name(ret));
        return;
    }

    ret = speaker_i2s_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "I2S TX init failed: %s", esp_err_to_name(ret));
        return;
    }

    fill_tone_frame();
    set_status_led(true);

    ESP_LOGI(TAG, "MAX98357A speaker tone test started");
    ESP_LOGI(
        TAG,
        "sample_rate=%d bck=%d ws=%d dout=%d freq=%d amplitude=%d",
        SPEAKER_SAMPLE_RATE_HZ,
        SPEAKER_BCK_GPIO,
        SPEAKER_WS_GPIO,
        SPEAKER_DOUT_GPIO,
        TONE_FREQUENCY_HZ,
        TONE_AMPLITUDE_PCM16
    );

    uint32_t frame_counter = 0;
    while (1) {
        size_t bytes_written = 0;
        ret = write_tone_frame(&bytes_written);
        if (ret != ESP_OK || bytes_written != sizeof(s_tone_frame)) {
            ESP_LOGE(
                TAG,
                "i2s_write failed: %s bytes_written=%u expected=%u",
                esp_err_to_name(ret),
                (unsigned)bytes_written,
                (unsigned)sizeof(s_tone_frame)
            );
            set_status_led(false);
            vTaskDelay(pdMS_TO_TICKS(500));
            continue;
        }

        if ((frame_counter % LOG_FRAME_INTERVAL) == 0) {
            ESP_LOGI(
                TAG,
                "tone active: frame_bytes=%u first_samples=%d,%d,%d,%d",
                (unsigned)bytes_written,
                s_tone_frame[0],
                s_tone_frame[1],
                s_tone_frame[2],
                s_tone_frame[3]
            );
        }

        frame_counter++;
    }
}
