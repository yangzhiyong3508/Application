#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "driver/gpio.h"
#include "driver/i2s.h"
#include "esp_err.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#define TAG "inmp441"

#define INMP441_I2S_PORT        I2S_NUM_0
#define INMP441_SAMPLE_RATE_HZ  16000
#define INMP441_BCK_GPIO        GPIO_NUM_26
#define INMP441_WS_GPIO         GPIO_NUM_25
#define INMP441_SD_GPIO         GPIO_NUM_34

#define STATUS_LED_GPIO         GPIO_NUM_2
#define STATUS_LED_ON_LEVEL     1
#define STATUS_LED_OFF_LEVEL    (!STATUS_LED_ON_LEVEL)

#define SOUND_ON_PEAK_THRESHOLD   1200
#define SOUND_OFF_PEAK_THRESHOLD  700
#define LED_HOLD_TIME_MS          180

#define RAW_FRAME_SAMPLES       256
#define DMA_BUFFER_COUNT        6
#define DMA_BUFFER_LENGTH       160

static int32_t s_raw_samples[RAW_FRAME_SAMPLES];
static int16_t s_pcm16_samples[RAW_FRAME_SAMPLES];
static bool s_led_is_on;
static int64_t s_last_trigger_us;

typedef struct {
    int32_t peak;
    int64_t avg_abs;
} audio_frame_stats_t;

static esp_err_t inmp441_i2s_init(void)
{
    const i2s_config_t i2s_config = {
        .mode = I2S_MODE_MASTER | I2S_MODE_RX,
        .sample_rate = INMP441_SAMPLE_RATE_HZ,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT,
        .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
        .communication_format = I2S_COMM_FORMAT_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = DMA_BUFFER_COUNT,
        .dma_buf_len = DMA_BUFFER_LENGTH,
        .use_apll = false,
        .tx_desc_auto_clear = false,
        .fixed_mclk = 0,
    };

    const i2s_pin_config_t pin_config = {
        .bck_io_num = INMP441_BCK_GPIO,
        .ws_io_num = INMP441_WS_GPIO,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num = INMP441_SD_GPIO,
    };

    esp_err_t ret = i2s_driver_install(INMP441_I2S_PORT, &i2s_config, 0, NULL);
    if (ret != ESP_OK) {
        return ret;
    }

    ret = i2s_set_pin(INMP441_I2S_PORT, &pin_config);
    if (ret != ESP_OK) {
        i2s_driver_uninstall(INMP441_I2S_PORT);
        return ret;
    }

    ret = i2s_set_clk(
        INMP441_I2S_PORT,
        INMP441_SAMPLE_RATE_HZ,
        I2S_BITS_PER_SAMPLE_32BIT,
        I2S_CHANNEL_MONO
    );
    if (ret != ESP_OK) {
        i2s_driver_uninstall(INMP441_I2S_PORT);
        return ret;
    }

    return ESP_OK;
}

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
    s_led_is_on = on;
}

static size_t convert_i2s_32_to_pcm16(const int32_t *src, size_t sample_count, int16_t *dst)
{
    size_t i = 0;

    for (i = 0; i < sample_count; ++i) {
        const int32_t sample_24 = src[i] >> 8;
        dst[i] = (int16_t)(sample_24 >> 8);
    }

    return sample_count;
}

static audio_frame_stats_t analyze_frame(const int16_t *samples, size_t sample_count)
{
    audio_frame_stats_t stats = { 0 };
    size_t i = 0;

    for (i = 0; i < sample_count; ++i) {
        int32_t value = samples[i];
        if (value < 0) {
            value = -value;
        }
        if (value > stats.peak) {
            stats.peak = value;
        }
        stats.avg_abs += value;
    }

    if (sample_count > 0) {
        stats.avg_abs /= (int64_t)sample_count;
    }

    return stats;
}

static void update_status_led(const audio_frame_stats_t *stats)
{
    const int64_t now_us = esp_timer_get_time();
    const bool trigger_now =
        (stats->peak >= SOUND_ON_PEAK_THRESHOLD) ||
        (stats->avg_abs >= (SOUND_ON_PEAK_THRESHOLD / 2));

    if (trigger_now) {
        s_last_trigger_us = now_us;
        if (!s_led_is_on) {
            set_status_led(true);
        }
        return;
    }

    if (!s_led_is_on) {
        return;
    }

    if (stats->peak > SOUND_OFF_PEAK_THRESHOLD) {
        s_last_trigger_us = now_us;
        return;
    }

    if ((now_us - s_last_trigger_us) >= (LED_HOLD_TIME_MS * 1000LL)) {
        set_status_led(false);
    }
}

static void print_frame_stats(
    const int16_t *samples,
    size_t sample_count,
    size_t bytes_read,
    const audio_frame_stats_t *stats
)
{
    size_t i = 0;

    printf(
        "bytes=%u samples=%u peak=%" PRId32 " avg_abs=%" PRId64 " led=%s\n",
        (unsigned)bytes_read,
        (unsigned)sample_count,
        stats->peak,
        stats->avg_abs,
        s_led_is_on ? "on" : "off"
    );

    printf("pcm16:");
    for (i = 0; i < sample_count && i < 8; ++i) {
        printf(" %d", samples[i]);
    }
    printf("\n");
}

void app_main(void)
{
    esp_err_t ret = status_led_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "LED init failed: %s", esp_err_to_name(ret));
        return;
    }

    s_last_trigger_us = esp_timer_get_time();

    ret = inmp441_i2s_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "I2S init failed: %s", esp_err_to_name(ret));
        return;
    }

    ESP_LOGI(TAG, "INMP441 capture started");
    ESP_LOGI(
        TAG,
        "sample_rate=%d, bck=%d, ws=%d, din=%d",
        INMP441_SAMPLE_RATE_HZ,
        INMP441_BCK_GPIO,
        INMP441_WS_GPIO,
        INMP441_SD_GPIO
    );
    ESP_LOGI(
        TAG,
        "led_gpio=%d, sound_on=%d, sound_off=%d, hold_ms=%d",
        STATUS_LED_GPIO,
        SOUND_ON_PEAK_THRESHOLD,
        SOUND_OFF_PEAK_THRESHOLD,
        LED_HOLD_TIME_MS
    );

    while (1) {
        size_t bytes_read = 0;
        const esp_err_t read_ret = i2s_read(
            INMP441_I2S_PORT,
            s_raw_samples,
            sizeof(s_raw_samples),
            &bytes_read,
            portMAX_DELAY
        );

        if (read_ret != ESP_OK) {
            ESP_LOGE(TAG, "i2s_read failed: %s", esp_err_to_name(read_ret));
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }

        const size_t raw_sample_count = bytes_read / sizeof(s_raw_samples[0]);
        const size_t pcm_sample_count = convert_i2s_32_to_pcm16(
            s_raw_samples,
            raw_sample_count,
            s_pcm16_samples
        );
        const audio_frame_stats_t stats = analyze_frame(s_pcm16_samples, pcm_sample_count);

        update_status_led(&stats);
        print_frame_stats(s_pcm16_samples, pcm_sample_count, bytes_read, &stats);
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
