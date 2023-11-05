#include "led.h"
#include "st_types.h"
#include "vesc_c_if.h"

#include "conf/datatypes.h"

#include <math.h>

#define WS2812_CLK_HZ		800000
#define TIM_PERIOD			(((168000000 / 2 / WS2812_CLK_HZ) - 1))
#define WS2812_ZERO			(TIM_PERIOD * 0.2)
#define WS2812_ONE			(TIM_PERIOD * 0.8)
#define BITBUFFER_PAD		50

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

uint32_t led_fade_color(uint32_t from, uint32_t to){
	uint8_t fw = (from >> 24) & 0xFF;
	uint8_t fr = (from >> 16) & 0xFF;
	uint8_t fg = (from >> 8) & 0xFF;
	uint8_t fb = from & 0xFF;

	uint8_t tw = (to >> 24) & 0xFF;
	uint8_t tr = (to >> 16) & 0xFF;
	uint8_t tg = (to >> 8) & 0xFF;
	uint8_t tb = to & 0xFF;

	if(fw < tw){
		if(fw + 12 > tw){
			fw = tw;
		}else{
			fw += 12;
		}
	}else if(fw > tw){
		if(fw - 12 < tw){
			fw = tw;
		}else{
			fw -= 12;
		}
	}
	if(fr < tr){
		if(fr + 12 > tr){
			fr = tr;
		}else{
			fr += 12;
		}
	}else if(fr > tr){
		if(fr - 12 < tr){
			fr = tr;
		}else{
			fr -= 12;
		}
	}
	if(fg < tg){
		if(fg + 12 > tg){
			fg = tg;
		}else{
			fg += 12;
		}
	}else if(fg > tg){
		if(fg - 12 < tg){
			fg = tg;
		}else{
			fg -= 12;
		}
	}
	if(fb < tb){
		if(fb + 12 > tb){
			fb = tb;
		}else{
			fb += 12;
		}
	}else if(fb > tb){
		if(fb - 12 < tb){
			fb = tb;
		}else{
			fb -= 12;
		}
	}
	return (fw << 24) | (fr << 16) | (fg << 8) | fb;
}

void led_init(LEDData *led_data, float_config * float_conf) {
	// Deinit
	led_data->ledbuf_len = 0;
	led_data->bitbuf_len = 0;	
	if (led_data->bitbuffer) {
		VESC_IF->free(led_data->bitbuffer);
	}
	if (led_data->RGBdata) {
		VESC_IF->free(led_data->RGBdata);
	}

	// Init
	int bits = 0;
	if(float_conf->led_type == 0){
		led_data->ledbuf_len = 0;
		led_data->bitbuf_len = 0;
		return;	
	}else if(float_conf->led_type == 1){
		bits = 24;
	}else{
		bits = 32;
	}
	
	led_data->ledbuf_len = float_conf->led_status_count + float_conf->led_forward_count + float_conf->led_rear_count + 1;
	led_data->bitbuf_len = bits * led_data->ledbuf_len + BITBUFFER_PAD;
	
	bool ok = false;
	led_data->bitbuffer = VESC_IF->malloc(sizeof(uint16_t) * led_data->bitbuf_len);
	led_data->RGBdata = VESC_IF->malloc(sizeof(uint32_t) * led_data->ledbuf_len);
	ok = led_data->bitbuffer != NULL && led_data->RGBdata != NULL;
	if (!ok) {
		led_data->ledbuf_len = 0;
		led_data->bitbuf_len = 0;	
		if (led_data->bitbuffer) {
			VESC_IF->free(led_data->bitbuffer);
		}
		if (led_data->RGBdata) {
			VESC_IF->free(led_data->RGBdata);
		}
		VESC_IF->printf("LED setup failed, out of memory\n");
		return;
	}
	
	led_data->led_last_updated = 0;
	led_data->led_previous_forward = 0;
	led_data->led_previous_rear = 0;
	led_data->led_previous_brightness = 0;
	led_data->led_latching_direction = true;
	
	led_ws2812_init(led_data, float_conf);
	return;
}

void led_ws2812_init(LEDData *led_data, float_config * float_conf) {
	// Deinit
	TIM_DeInit(TIM4);
	DMA_DeInit(DMA1_Stream3);

	// Init
	TIM_TimeBaseInitTypeDef  TIM_TimeBaseStructure;
	TIM_OCInitTypeDef  TIM_OCInitStructure;
	DMA_InitTypeDef DMA_InitStructure;

	// Default LED values
	int i, bit;

	for (i = 0;i < led_data->ledbuf_len;i++) {
		led_data->RGBdata[i] = 0;
	}

	for (i = 0;i < led_data->ledbuf_len;i++) {
		uint32_t tmp_color = led_rgb_to_local(led_data->RGBdata[i], float_conf->led_brightness, float_conf->led_type == 2);

		int bits = 0;
		if(float_conf->led_type == 1){
			bits = 24;
		} else {
			bits = 32;
		}

		for (bit = 0;bit < bits;bit++) {
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
	for (i = 0;i < BITBUFFER_PAD;i++) {
		led_data->bitbuffer[led_data->bitbuf_len - BITBUFFER_PAD - 1 + i] = 0;
	}

	TIM_TypeDef *tim;
	DMA_Stream_TypeDef *dma_stream;
	uint32_t dma_ch;
	
	// Always GPIOB PIN7 #dealwithit
	tim = TIM4;
	dma_stream = DMA1_Stream3;
			dma_ch = DMA_Channel_2;
			VESC_IF->set_pad_mode(GPIOB, 7,
				PAL_MODE_ALTERNATE(2) |
				PAL_STM32_OTYPE_OPENDRAIN |
				PAL_STM32_OSPEED_MID1);
	
	TIM_DeInit(tim);

	RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_DMA1 , ENABLE);
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

void led_set_color(LEDData *led_data, float_config *float_conf, int led, uint32_t color, uint32_t brightness) {
	if(float_conf->led_type == 0){
		return;
	}
	if (led >= 0 && led < led_data->ledbuf_len) {
		led_data->RGBdata[led] = color;

		color = led_rgb_to_local(color, brightness, float_conf->led_type == 2);

		int bits = 0;
		if(float_conf->led_type == 1){
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

void led_update(LEDData *led_data, float_config *float_conf, float current_time, float erpm, float abs_duty_cycle, int switch_state){	
	if(current_time - led_data->led_last_updated < 0.05){
		return;
	}else{
		led_data->led_last_updated = current_time;
	}
	if(float_conf->led_status_count > 0){
		int statusBrightness = (int)(float_conf->led_status_brightness * 2.55);
		if(erpm < float_conf->fault_adc_half_erpm){
			// Display status LEDs
			if(switch_state == 0){
				float batteryLevel = VESC_IF->mc_get_battery_level(NULL);
				int batteryLeds = (int)(batteryLevel * float_conf->led_status_count);
				int batteryColor = 0x0000FF00;
				if(batteryLevel < .4){
					batteryColor = 0x00FFFF00;
				}else if(batteryLevel < .2){
					batteryColor = 0x00FF0000;
				}
				for(int i = 0; i < float_conf->led_status_count; i++){
					if(i < batteryLeds){
						led_set_color(led_data, float_conf, i, batteryColor, statusBrightness);
					}else{
						led_set_color(led_data, float_conf, i, 0x00000000, 0xFF);
					}
					
				}
			}else if(switch_state == 1){
				for(int i = 0; i < float_conf->led_status_count; i++){
					if(i < float_conf->led_status_count / 2){
						led_set_color(led_data, float_conf, i, 0x000000FF, statusBrightness);
					}else{
						led_set_color(led_data, float_conf, i, 0x00000000, 0xFF);
					}	
				}
			}else{
				for(int i = 0; i < float_conf->led_status_count; i++){
					led_set_color(led_data, float_conf, i, 0x000000FF, statusBrightness);
				}
			}
		}else{
			// Display duty cycle when riding
			int dutyLeds = (int)(fminf((abs_duty_cycle * 1.1112), 1) * float_conf->led_status_count);
			int dutyColor = 0x0000FF00;
			if(abs_duty_cycle > 0.85){
				dutyColor = 0x00FF0000;
			}else if(abs_duty_cycle > 0.7){
				dutyColor = 0x00FFFF00;
			}

			for(int i = 0; i < float_conf->led_status_count; i++){
				if(i < dutyLeds){
					led_set_color(led_data, float_conf, i, dutyColor, statusBrightness);
				}else{
					led_set_color(led_data, float_conf, i, 0x00000000, 0xFF);
				}	
			}
		}
	}

	uint8_t brightness = float_conf->led_brightness;
	if(switch_state == 0){
		brightness = (uint8_t) (brightness * 0.05);
	}
	if(brightness > led_data->led_previous_brightness){
		led_data->led_previous_brightness += 5;
		if(led_data->led_previous_brightness > brightness){
			led_data->led_previous_brightness = brightness;
		}
	}else if(brightness < led_data->led_previous_brightness){
		led_data->led_previous_brightness -= 5;
		if(led_data->led_previous_brightness < brightness){
			led_data->led_previous_brightness = brightness;
		}
	}
	brightness = led_data->led_previous_brightness;

	// Find color
	int forwardColor = 0;
	int rearColor = 0;
	if(float_conf->led_mode == 0){
		forwardColor = 0xFFFFFFFF;
		rearColor = 0x00FF0000;
	}else if(float_conf->led_mode == 1){
		forwardColor = 0x0000FFFF;
		rearColor = 0x00FF00FF;
	}else if(float_conf->led_mode == 2){
		forwardColor = 0x000000FF;
		rearColor = 0x0000FF00;
	}else if(float_conf->led_mode == 3){
		forwardColor = 0x00FFFF00;
		rearColor = 0x0000FF00;
	}

	// Set directonality
	if(erpm > 100){
		led_data->led_latching_direction = true;
	}else if(erpm < -100){
		led_data->led_latching_direction = false;
	}
	if(led_data->led_latching_direction == false){
		int temp = forwardColor;
		forwardColor = rearColor;
		rearColor = temp;
	}

	// Fade
	forwardColor = led_fade_color(led_data->led_previous_forward, forwardColor);
	rearColor = led_fade_color(led_data->led_previous_rear, rearColor);
	led_data->led_previous_forward = forwardColor;
	led_data->led_previous_rear = rearColor;

	if(float_conf->led_forward_count > 0){
		int offset = float_conf->led_status_count;
		for(int i = offset; i < float_conf->led_forward_count + offset; i++){
			led_set_color(led_data, float_conf, i, forwardColor, brightness);
		}
	}
	if(float_conf->led_rear_count > 0){
		int offset = float_conf->led_status_count + float_conf->led_forward_count;
		for(int i = offset; i < float_conf->led_rear_count + offset; i++){
			led_set_color(led_data, float_conf, i, rearColor, brightness);
		}
	}
}

void led_stop(LEDData *led_data){
    TIM_DeInit(TIM4);
	DMA_DeInit(DMA1_Stream3);
	if (led_data->bitbuffer) {
		VESC_IF->free(led_data->bitbuffer);
	}
	if (led_data->RGBdata) {
		VESC_IF->free(led_data->RGBdata);
	}
}
