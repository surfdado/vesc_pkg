#include "footpad_sensor.h"

#include "vesc_c_if.h"

// Read ADCs and determine footpad sensor state
FootpadSensorState footpad_sensor_state_evaluate(const FootpadSensor *fs, const float_config *config) {
	// Calculate sensor state from ADC values
	if (config->fault_adc1 == 0 && config->fault_adc2 == 0) { // No sensors
		return FS_BOTH;
	} else if (config->fault_adc2 == 0) { // Single sensor on ADC1
		if (fs->adc1 > config->fault_adc1) {
			return FS_BOTH;
		}
	} else if (config->fault_adc1 == 0) { // Single sensor on ADC2
		if (fs->adc2 > config->fault_adc2) {
			return FS_BOTH;
		}
	} else { // Double sensor
		if (fs->adc1 > config->fault_adc1) {
			if (fs->adc2 > config->fault_adc2) {
				return FS_BOTH;
			} else {
				return FS_LEFT;
			}
		} else {
			if (fs->adc2 > config->fault_adc2) {
				return FS_RIGHT;
			}
		}
	}

	return FS_NONE;
}

void footpad_sensor_update(FootpadSensor *fs, const float_config *config) {
	fs->adc1 = VESC_IF->io_read_analog(VESC_PIN_ADC1);
	fs->adc2 = VESC_IF->io_read_analog(VESC_PIN_ADC2); // Returns -1.0 if the pin is missing on the hardware
	if (fs->adc2 < 0.0) {
		fs->adc2 = 0.0;
	}

	fs->state = footpad_sensor_state_evaluate(fs, config);
}

int footpad_sensor_state_to_switch_compat(FootpadSensorState v) {
	switch (v) {
	case FS_BOTH:
		return 2;
	case FS_LEFT:
	case FS_RIGHT:
		return 1;
	case FS_NONE:
	default:
		return 0;
	}
}
