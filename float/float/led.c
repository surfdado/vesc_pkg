#include "led.h"
#include "st_types.h"
#include "vesc_c_if.h"

#include "conf/datatypes.h"

#include <math.h>

#define WS2812_CLK_HZ		800000
#define TIM_PERIOD			(((168000000 / 2 / WS2812_CLK_HZ) - 1))
#define WS2812_ZERO			(TIM_PERIOD * 0.3)
#define WS2812_ONE			(TIM_PERIOD * 0.7)
#define BITBUFFER_PAD		1000

uint32_t led_rgb_to_local(uint32_t color, uint8_t brightness, bool rgbw) {
    uint32_t w = (color >> 24) & 0xFF;
    uint32_t r = (color >> 16) & 0xFF;
    uint32_t g = (color >> 8) & 0xFF;
    uint32_t b = color & 0xFF;

    r = (r * brightness) / 100;
    g = (g * brightness) / 100;
    b = (b * brightness) / 100;
    w = (w * brightness) / 100;

    if (rgbw) {
        return (g << 24) | (r << 16) | (b << 8) | w;
    } else {
        return (g << 16) | (r << 8) | b;
    }
}

uint32_t led_fade_color(uint32_t from, uint32_t to) {
    uint8_t fw = (from >> 24) & 0xFF;
    uint8_t fr = (from >> 16) & 0xFF;
    uint8_t fg = (from >> 8) & 0xFF;
    uint8_t fb = from & 0xFF;

    uint8_t tw = (to >> 24) & 0xFF;
    uint8_t tr = (to >> 16) & 0xFF;
    uint8_t tg = (to >> 8) & 0xFF;
    uint8_t tb = to & 0xFF;

    if (fw < tw) {
        if (fw + 12 > tw) {
            fw = tw;
        } else {
            fw += 12;
        }
    } else if (fw > tw) {
        if (fw - 12 < tw) {
            fw = tw;
        } else {
            fw -= 12;
        }
    }
    if (fr < tr) {
        if (fr + 12 > tr) {
            fr = tr;
        } else {
            fr += 12;
        }
    } else if (fr > tr) {
        if (fr - 12 < tr) {
            fr = tr;
        } else {
            fr -= 12;
        }
    }
    if (fg < tg) {
        if (fg + 12 > tg) {
            fg = tg;
        } else {
            fg += 12;
        }
    } else if (fg > tg) {
        if (fg - 12 < tg) {
            fg = tg;
        } else {
            fg -= 12;
        }
    }
    if (fb < tb) {
        if (fb + 12 > tb) {
            fb = tb;
        } else {
            fb += 12;
        }
    } else if (fb > tb) {
        if (fb - 12 < tb) {
            fb = tb;
        } else {
            fb -= 12;
        }
    }
    return (fw << 24) | (fr << 16) | (fg << 8) | fb;
}

void led_init_dma(LEDData* led_data) {
    // Init
    TIM_TimeBaseInitTypeDef  TIM_TimeBaseStructure;
    TIM_OCInitTypeDef  TIM_OCInitStructure;
    DMA_InitTypeDef DMA_InitStructure;

    TIM_TypeDef* tim;
    DMA_Stream_TypeDef* dma_stream;
    uint32_t dma_ch;

    // Always GPIOB PIN7 #dealwithit
    tim = TIM4;
    dma_stream = DMA1_Stream3;
    dma_ch = DMA_Channel_2;
    VESC_IF->set_pad_mode(GPIOB, 7, PAL_MODE_ALTERNATE(2) | PAL_STM32_OTYPE_OPENDRAIN | PAL_STM32_OSPEED_MID1);

    TIM_DeInit(tim);

    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_DMA1, ENABLE);
    DMA_DeInit(dma_stream);

    DMA_InitStructure.DMA_PeripheralBaseAddr = (uint32_t)&tim->CCR2;

    DMA_InitStructure.DMA_Channel = dma_ch;
    DMA_InitStructure.DMA_Memory0BaseAddr = (uint32_t)(led_data->bitbuffer);
    DMA_InitStructure.DMA_DIR = DMA_DIR_MemoryToPeripheral;
    DMA_InitStructure.DMA_BufferSize = led_data->bitbuf_len;
    DMA_InitStructure.DMA_PeripheralInc = DMA_PeripheralInc_Disable;
    DMA_InitStructure.DMA_MemoryInc = DMA_MemoryInc_Enable;
    DMA_InitStructure.DMA_PeripheralDataSize = DMA_PeripheralDataSize_HalfWord;
    DMA_InitStructure.DMA_MemoryDataSize = DMA_MemoryDataSize_HalfWord;
    DMA_InitStructure.DMA_Mode = DMA_Mode_Circular;
    DMA_InitStructure.DMA_Priority = DMA_Priority_High;
    DMA_InitStructure.DMA_FIFOMode = DMA_FIFOMode_Disable;
    DMA_InitStructure.DMA_FIFOThreshold = DMA_FIFOThreshold_Full;
    DMA_InitStructure.DMA_MemoryBurst = DMA_MemoryBurst_Single;
    DMA_InitStructure.DMA_PeripheralBurst = DMA_PeripheralBurst_Single;

    DMA_Init(dma_stream, &DMA_InitStructure);

    RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM4, ENABLE);

    TIM_TimeBaseStructure.TIM_Prescaler = 0;
    TIM_TimeBaseStructure.TIM_CounterMode = TIM_CounterMode_Up;
    TIM_TimeBaseStructure.TIM_Period = TIM_PERIOD;
    TIM_TimeBaseStructure.TIM_ClockDivision = 0;
    TIM_TimeBaseStructure.TIM_RepetitionCounter = 0;

    TIM_TimeBaseInit(tim, &TIM_TimeBaseStructure);

    TIM_OCInitStructure.TIM_OCMode = TIM_OCMode_PWM1;
    TIM_OCInitStructure.TIM_OutputState = TIM_OutputState_Enable;
    TIM_OCInitStructure.TIM_Pulse = led_data->bitbuffer[0];
    TIM_OCInitStructure.TIM_OCPolarity = TIM_OCPolarity_High;

    TIM_OC2Init(tim, &TIM_OCInitStructure);
    TIM_OC2PreloadConfig(tim, TIM_OCPreload_Enable);

    TIM_ARRPreloadConfig(tim, ENABLE);

    TIM_Cmd(tim, ENABLE);

    DMA_Cmd(dma_stream, ENABLE);

    TIM_DMACmd(tim, TIM_DMA_CC2, ENABLE);
}

void led_init(LEDData* led_data, float_config* float_conf) {
    // De-init
    led_stop(led_data);

    // Copy params that require a reboot
    led_data->led_type = float_conf->led_type;
    led_data->led_status_count = float_conf->led_status_count;
    led_data->led_forward_count = float_conf->led_forward_count;
    led_data->led_rear_count = float_conf->led_rear_count;

    // Init
    int bits = 0;
    if (led_data->led_type == 0) {
        return;
    } else if (led_data->led_type == 1) {
        bits = 24;
    } else {
        bits = 32;
    }

    led_data->ledbuf_len = led_data->led_status_count + led_data->led_forward_count + led_data->led_rear_count + 1;
    led_data->bitbuf_len = bits * led_data->ledbuf_len + BITBUFFER_PAD;

    bool ok = false;
    led_data->bitbuffer = VESC_IF->malloc(sizeof(uint16_t) * led_data->bitbuf_len);
    led_data->RGBdata = VESC_IF->malloc(sizeof(uint32_t) * led_data->ledbuf_len);
    ok = led_data->bitbuffer != NULL && led_data->RGBdata != NULL;
    if (!ok) {
        led_stop(led_data);
        VESC_IF->printf("LED setup failed, out of memory\n");
        return;
    }

    led_data->led_last_updated = 0;
    led_data->led_previous_forward = 0;
    led_data->led_previous_rear = 0;
    led_data->led_previous_brightness = 0;
    led_data->led_latching_direction = true;

    // Default LED values
    for (int i = 0;i < led_data->ledbuf_len;i++) {
        led_data->RGBdata[i] = 0;
    }
    for (int i = 0;i < led_data->ledbuf_len;i++) {
        uint32_t tmp_color = led_rgb_to_local(0x00000000, 0x00, bits == 32);

        for (int bit = 0;bit < bits;bit++) {
            if (tmp_color & (1 << (bits - 1))) {
                led_data->bitbuffer[bit + i * bits] = WS2812_ONE;
            } else {
                led_data->bitbuffer[bit + i * bits] = WS2812_ZERO;
            }
            tmp_color <<= 1;
        }
    }

    // Fill the rest of the buffer with zeros to give the LEDs a chance to update
    // after sending all bits
    for (int i = 0;i < BITBUFFER_PAD;i++) {
        led_data->bitbuffer[led_data->bitbuf_len - BITBUFFER_PAD - 1 + i] = 0;
    }

    led_init_dma(led_data);
    return;
}

void led_set_color(LEDData* led_data, int led, uint32_t color, uint32_t brightness, bool fade) {
    if (led_data->led_type == 0) {
        return;
    }
    if (led >= 0 && led < led_data->ledbuf_len) {
        if (fade) {
            color = led_fade_color(led_data->RGBdata[led], color);
        }
        led_data->RGBdata[led] = color;

        color = led_rgb_to_local(color, brightness, led_data->led_type == 2);

        int bits = 0;
        if (led_data->led_type == 1) {
            bits = 24;
        } else {
            bits = 32;
        }

        int bit;
        for (bit = 0;bit < bits;bit++) {
            if (color & (1 << (bits - 1))) {
                led_data->bitbuffer[bit + led * bits] = WS2812_ONE;
            } else {
                led_data->bitbuffer[bit + led * bits] = WS2812_ZERO;
            }
            color <<= 1;
        }
    }
}

void led_display_battery(LEDData* led_data, int brightness, int strip_offset, int strip_length, bool fade) {
    float batteryLevel = VESC_IF->mc_get_battery_level(NULL);
    int batteryLeds = (int)(batteryLevel * strip_length);
    int batteryColor = 0x0000FF00;
    if (batteryLevel < .4) {
        batteryColor = 0x00FFFF00;
    }
    if (batteryLevel < .2) {
        batteryColor = 0x00FF0000;
    }
    for (int i = strip_offset; i < strip_offset + strip_length; i++) {
        if (i < strip_offset + batteryLeds) {
            led_set_color(led_data, i, batteryColor, brightness, fade);
        } else {
            led_set_color(led_data, i, 0x00000000, brightness, fade);
        }
    }
}

void led_float_disabled(LEDData* led_data, int brightness, int first, int count) {
    // show red LEDs in the center of the light bar
    int start = count / 4;
    int end = count * 3 / 4;
    if (end < 3) { // 3 or fewer LEDs in total? Show red lights across the entire light bar
        end = count;
    }
    for (int i = first; i < first + count; i++) {
        int bright = brightness;
        if ((end > 4) && ((i == first+start) || (i == first+end-1))) // first and last red led at half brightness
            bright /= 2;
        if ((i < first+start) || (i > first+end)) // outer LEDs are off
            bright = 0;
        led_set_color(led_data, i, 0x00FF0000, bright, false);
    }
}

void led_update(LEDData* led_data, float_config* float_conf, float current_time, float erpm, float abs_duty_cycle, int switch_state, int float_state) {
    if (led_data->led_type == 0 || current_time - led_data->led_last_updated < 0.05) {
        return;
    } else {
        led_data->led_last_updated = current_time;
    }
    if (led_data->led_status_count > 0) {
        int statusBrightness = (int)(float_conf->led_status_brightness * 2.55);
        if (float_state == 15) {
            led_float_disabled(led_data, statusBrightness, 0, led_data->led_status_count);
        }
        else if (erpm < float_conf->fault_adc_half_erpm) {
            // Display status LEDs
            if (switch_state == 0) {
                led_display_battery(led_data, statusBrightness, 0, led_data->led_status_count, false);
            } else if (switch_state == 1) {
                for (int i = 0; i < led_data->led_status_count; i++) {
                    if (i < led_data->led_status_count / 2) {
                        led_set_color(led_data, i, 0x000000FF, statusBrightness, false);
                    } else {
                        led_set_color(led_data, i, 0x00000000, 0xFF, false);
                    }
                }
            } else {
                for (int i = 0; i < led_data->led_status_count; i++) {
                    led_set_color(led_data, i, 0x000000FF, statusBrightness, false);
                }
            }
        } else {
            // Display duty cycle when riding
            int dutyLeds = (int)(fminf((abs_duty_cycle * 1.1112), 1) * led_data->led_status_count);
            int dutyColor = 0x00FFFF00;
            if (abs_duty_cycle > 0.85) {
                dutyColor = 0x00FF0000;
            } else if (abs_duty_cycle > 0.7) {
                dutyColor = 0x00FF8800;
            }

            for (int i = 0; i < led_data->led_status_count; i++) {
                if (i < dutyLeds) {
                    led_set_color(led_data, i, dutyColor, statusBrightness, false);
                } else {
                    led_set_color(led_data, i, 0x00000000, 0xFF, false);
                }
            }
        }
    }

    int brightness = float_conf->led_brightness;
    if (float_state > 5) {
        // board is disengaged
        brightness = float_conf->led_brightness_idle;
    }
    if (brightness > led_data->led_previous_brightness) {
        led_data->led_previous_brightness += 5;
        if (led_data->led_previous_brightness > brightness) {
            led_data->led_previous_brightness = brightness;
        }
    } else if (brightness < led_data->led_previous_brightness) {
        led_data->led_previous_brightness -= 5;
        if (led_data->led_previous_brightness < brightness) {
            led_data->led_previous_brightness = brightness;
        }
    }
    brightness = led_data->led_previous_brightness;

    // Find color
    int forwardColor = 0;
    int rearColor = 0;
    bool fade = true;
    bool directional = true;
    bool batteryMeter = false;
    int led_mode = float_state < 5 ? float_conf->led_mode : float_conf->led_mode_idle;
    if (led_mode == 0) { // Red/White
        forwardColor = 0xFFFFFFFF;
        rearColor = 0x00FF0000;
    } else if (led_mode == 1) { // Red/White with Battery Meter
        batteryMeter = true;
        forwardColor = 0xFFFFFFFF;
        rearColor = 0x00FF0000;
    } else if (led_mode == 2) { // Cyan/Magenta
        forwardColor = 0x0000FFFF;
        rearColor = 0x00FF00FF;
    } else if (led_mode == 3) { // Blue/Green
        forwardColor = 0x000000FF;
        rearColor = 0x0000FF00;
    } else if (led_mode == 4) { // Yellow/Green
        forwardColor = 0x00FFFF00;
        rearColor = 0x0000FF00;
    } else if (led_mode == 5) { // RGB Fade
        if ((int)(current_time * 1000) % 3000 < 1000) {
            forwardColor = 0x00FF0000;
            rearColor = 0x00FF0000;
        } else if ((int)(current_time * 1000) % 3000 < 2000) {
            forwardColor = 0x0000FF00;
            rearColor = 0x0000FF00;
        } else {
            forwardColor = 0x000000FF;
            rearColor = 0x000000FF;
        }
    } else if (led_mode == 6) { // Strobe
        fade = false;
        if (led_data->led_previous_forward > 0) {
            forwardColor = 0x00000000;
            rearColor = 0x00000000;
        } else {
            forwardColor = 0xFFFFFFFF;
            rearColor = 0xFFFFFFFF;
        }
        led_data->led_previous_forward = forwardColor;
    } else if (led_mode == 7) { // Rave
        fade = false;
        if (led_data->led_previous_forward == 0x00FF0000) {
            forwardColor = 0x00FFFF00;
            rearColor = 0x00FFFF00;
        } else if (led_data->led_previous_forward == 0x00FFFF00) {
            forwardColor = 0x0000FF00;
            rearColor = 0x0000FF00;
        } else if (led_data->led_previous_forward == 0x0000FF00) {
            forwardColor = 0x0000FFFF;
            rearColor = 0x0000FFFF;
        } else if (led_data->led_previous_forward == 0x0000FFFF) {
            forwardColor = 0x000000FF;
            rearColor = 0x000000FF;
        } else if (led_data->led_previous_forward == 0x000000FF) {
            forwardColor = 0x00FF00FF;
            rearColor = 0x00FF00FF;
        } else {
            forwardColor = 0x00FF0000;
            rearColor = 0x00FF0000;
        }
        led_data->led_previous_forward = forwardColor;
    } else if (led_mode == 8) { // Mullet
        fade = false;
        forwardColor = 0xFFFFFFFF;
        if (led_data->led_previous_rear == 0x00FF0000) {
            rearColor = 0x00FFFF00;
        } else if (led_data->led_previous_rear == 0x00FFFF00) {
            rearColor = 0x0000FF00;
        } else if (led_data->led_previous_rear == 0x0000FF00) {
            rearColor = 0x0000FFFF;
        } else if (led_data->led_previous_rear == 0x0000FFFF) {
            rearColor = 0x000000FF;
        } else if (led_data->led_previous_rear == 0x000000FF) {
            rearColor = 0x00FF00FF;
        } else {
            rearColor = 0x00FF0000;
        }
        led_data->led_previous_rear = rearColor;
    }

    // Set directonality
    if (directional) {
        if (erpm > 100) {
            led_data->led_latching_direction = true;
        } else if (erpm < -100) {
            led_data->led_latching_direction = false;
        }
        if (led_data->led_latching_direction == false) {
            int temp = forwardColor;
            forwardColor = rearColor;
            rearColor = temp;
        }
    }

    if (batteryMeter && float_state > 5 && float_state < 15) {
        // Idle voltage display
        led_display_battery(led_data, brightness, led_data->led_status_count, led_data->led_forward_count, fade);
        led_display_battery(led_data, brightness, led_data->led_status_count + led_data->led_forward_count, led_data->led_rear_count, fade);
    } else {
        // Normal color/pattern display
        if (led_data->led_forward_count > 0) {
            int offset = led_data->led_status_count;
            if (float_state == 15) { // disabled board? front lights show red in center
                led_float_disabled(led_data, brightness, offset, led_data->led_forward_count);
            }
            else {
                for (int i = offset; i < led_data->led_forward_count + offset; i++) {
                    led_set_color(led_data, i, forwardColor, brightness, fade);
                }
            }
        }
        if (led_data->led_rear_count > 0) {
            int offset = led_data->led_status_count + led_data->led_forward_count;
            if (float_state == 15) { // disabled board? rear lights off
                brightness = 0;
            }
            for (int i = offset; i < led_data->led_rear_count + offset; i++) {
                led_set_color(led_data, i, rearColor, brightness, fade);
            }
        }
    }
}

void led_stop(LEDData* led_data) {
    TIM_DeInit(TIM4);
    DMA_DeInit(DMA1_Stream3);

    led_data->ledbuf_len = 0;
    led_data->bitbuf_len = 0;
    if (led_data->bitbuffer) {
        VESC_IF->free(led_data->bitbuffer);
    }
    if (led_data->RGBdata) {
        VESC_IF->free(led_data->RGBdata);
    }
}
