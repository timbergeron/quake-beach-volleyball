// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* All distances use 32 Quake units per metre; time is seconds. */
const float BV_GRAVITY = 313.92;
const float BV_RADIUS = 3.4;
const float BV_NET_HEIGHT = 77.76;
const float BV_HALF_LENGTH = 256;
const float BV_HALF_WIDTH = 128;
const float BV_STEP = 0.008333333;
const float BV_PI = 3.141592654;
const float BV_EF_FULLBRIGHT = 512;
const float BV_EF_NOSHADOW = 4096;

const float BV_IDLE = 0;
const float BV_HELD = 1;
const float BV_LIVE = 2;
const float BV_DEAD = 3;

const float BV_PASS = 1;
const float BV_SET = 2;
const float BV_SPIKE = 3;
const float BV_ROLL = 4;
const float BV_SERVE = 5;

float(float value, float low, float high) BV_Clamp =
{
    if (value < low) return low;
    if (value > high) return high;
    return value;
};

vector(vector a, vector b) BV_Cross =
{
    local vector result;
    result_x = a_y * b_z - a_z * b_y;
    result_y = a_z * b_x - a_x * b_z;
    result_z = a_x * b_y - a_y * b_x;
    return result;
};

vector(float yaw) BV_Heading =
{
    local vector result;
    result = '0 0 0';
    result_x = cos(yaw * BV_PI / 180);
    result_y = sin(yaw * BV_PI / 180);
    return result;
};

string(float kind) BV_ShotName =
{
    if (kind == BV_SET) return "SET";
    if (kind == BV_SPIKE) return "SPIKE";
    if (kind == BV_ROLL) return "ROLL";
    if (kind == BV_SERVE) return "SERVE";
    return "PASS";
};
