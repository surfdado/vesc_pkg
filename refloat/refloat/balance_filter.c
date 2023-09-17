// Copyright 2023 - 2024 Lukas Hrazky
//
// This file is part of the Refloat VESC package.
//
// Refloat VESC package is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by the
// Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// Refloat VESC package is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with
// this program. If not, see <http://www.gnu.org/licenses/>.

//=====================================================================================================
//
// Madgwick's implementation of Mayhony's AHRS algorithm.
// See: https://x-io.co.uk/open-source-imu-and-ahrs-algorithms/
//
// Date         Author          Notes
// 29/09/2011   SOH Madgwick    Initial release
// 02/10/2011   SOH Madgwick    Optimised for reduced CPU load
// 26/01/2014   Benjamin V      Adaption to our platform
// 20/02/2017   Benjamin V      Added Madgwick algorithm and refactoring
// 17/09/2023   Lukas Hrazky    Adopted from vedderb/bldc, modified for self-balancing skateboard
//
//=====================================================================================================

#include "balance_filter.h"

#include "vesc_c_if.h"

#include <math.h>

static inline float inv_sqrt(float x) {
    return 1.0 / sqrtf(x);
}

static float calculate_acc_confidence(float new_acc_mag, BalanceFilterData *data) {
    // G.K. Egan (C) computes confidence in accelerometers when
    // aircraft is being accelerated over and above that due to gravity
    data->acc_mag = data->acc_mag * 0.9 + new_acc_mag * 0.1;

    float confidence = 1.0 - (data->acc_confidence_decay * sqrtf(fabsf(data->acc_mag - 1.0f)));

    return confidence > 0 ? confidence : 0;
}

void balance_filter_init(BalanceFilterData *data) {
    // Init with internal filter orientation, otherwise the AHRS would need a while to stabilise
    float quat[4];
    VESC_IF->imu_get_quaternions(quat);
    data->q0 = quat[0];
    data->q1 = quat[1];
    data->q2 = quat[2];
    data->q3 = quat[3];
    data->acc_mag = 1.0;
}

void balance_filter_configure(BalanceFilterData *data, const RefloatConfig *config) {
    data->acc_confidence_decay = config->bf_accel_confidence_decay;
    data->kp = config->mahony_kp;
}

void balance_filter_update(BalanceFilterData *data, float *gyro_xyz, float *accel_xyz, float dt) {
    float gx = gyro_xyz[0];
    float gy = gyro_xyz[1];
    float gz = gyro_xyz[2];

    float ax = accel_xyz[0];
    float ay = accel_xyz[1];
    float az = accel_xyz[2];

    float accel_norm = sqrtf(ax * ax + ay * ay + az * az);

    // Compute feedback only if accelerometer abs(vector)is not too small to avoid a division
    // by a small number
    if (accel_norm > 0.01) {
        float two_kp = 2.0 * data->kp * calculate_acc_confidence(accel_norm, data);

        // Normalise accelerometer measurement
        float recip_norm = inv_sqrt(ax * ax + ay * ay + az * az);
        ax *= recip_norm;
        ay *= recip_norm;
        az *= recip_norm;

        // Estimated direction of gravity and vector perpendicular to magnetic flux
        float halfvx = data->q1 * data->q3 - data->q0 * data->q2;
        float halfvy = data->q0 * data->q1 + data->q2 * data->q3;
        float halfvz = data->q0 * data->q0 - 0.5f + data->q3 * data->q3;

        // Error is sum of cross product between estimated and measured direction of gravity
        float halfex = (ay * halfvz - az * halfvy);
        float halfey = (az * halfvx - ax * halfvz);
        float halfez = (ax * halfvy - ay * halfvx);

        // Apply proportional feedback
        gx += two_kp * halfex;
        gy += two_kp * halfey;
        gz += two_kp * halfez;
    }

    // Integrate rate of change of quaternion
    gx *= (0.5f * dt);  // pre-multiply common factors
    gy *= (0.5f * dt);
    gz *= (0.5f * dt);
    float qa = data->q0;
    float qb = data->q1;
    float qc = data->q2;
    data->q0 += (-qb * gx - qc * gy - data->q3 * gz);
    data->q1 += (qa * gx + qc * gz - data->q3 * gy);
    data->q2 += (qa * gy - qb * gz + data->q3 * gx);
    data->q3 += (qa * gz + qb * gy - qc * gx);

    // Normalize quaternion
    float recip_norm = inv_sqrt(
        data->q0 * data->q0 + data->q1 * data->q1 + data->q2 * data->q2 + data->q3 * data->q3
    );
    data->q0 *= recip_norm;
    data->q1 *= recip_norm;
    data->q2 *= recip_norm;
    data->q3 *= recip_norm;
}

float balance_filter_get_roll(BalanceFilterData *data) {
    const float q0 = data->q0;
    const float q1 = data->q1;
    const float q2 = data->q2;
    const float q3 = data->q3;

    return -atan2f(q0 * q1 + q2 * q3, 0.5 - (q1 * q1 + q2 * q2));
}

float balance_filter_get_pitch(BalanceFilterData *data) {
    const float q0 = data->q0;
    const float q1 = data->q1;
    const float q2 = data->q2;
    const float q3 = data->q3;

    return asinf(-2.0 * (q1 * q3 - q0 * q2));
}

float balance_filter_get_yaw(BalanceFilterData *data) {
    const float q0 = data->q0;
    const float q1 = data->q1;
    const float q2 = data->q2;
    const float q3 = data->q3;

    return -atan2f(q0 * q3 + q1 * q2, 0.5 - (q2 * q2 + q3 * q3));
}
