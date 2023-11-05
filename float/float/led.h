#ifndef FLOATLED_H_
#define FLOATLED_H_

#include "conf/datatypes.h"

typedef struct{
	float led_last_updated;
	uint32_t led_previous_forward;
	uint32_t led_previous_rear;
	uint8_t led_previous_brightness;
	bool led_latching_direction;
	int ledbuf_len;
	int bitbuf_len;
	uint16_t *bitbuffer;
	uint32_t *RGBdata;
} LEDData;

void led_init(LEDData *led_data, float_config * float_conf);
void led_ws2812_init(LEDData *led_data);
void led_update(LEDData *led_data, float_config *float_conf, float current_time, float erpm, float abs_duty_cycle, int switch_state);
void led_stop(LEDData *led_data);

#endif /* FLOATLED_H_ */
