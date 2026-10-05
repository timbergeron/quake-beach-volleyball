// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* All distances use 32 Quake units per metre; time is seconds. */
const float BV_GRAVITY = 313.92;
const float BV_RADIUS = 3.4;
const float BV_NET_HEIGHT = 77.76;
const float BV_NET_BOTTOM = 45.76;
const float BV_NET_HALF_LENGTH = 136;
const float BV_NET_HALF_DEPTH = 0.12;
const float BV_POST_Y = 160;
const float BV_POST_HEIGHT = 81.6;
const float BV_POST_RADIUS = 3.52;
const float BV_ANTENNA_X = 0.24;
const float BV_ANTENNA_Y = 128.16;
const float BV_ANTENNA_RADIUS = 0.16;
const float BV_ANTENNA_TOP = 103.36;
const float BV_HALF_LENGTH = 256;
const float BV_HALF_WIDTH = 128;
const float BV_STEP = 0.008333333;
const float BV_MAX_FLIGHT = 8;
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
const float BV_FLOAT_SERVE = 1;
const float BV_TOPSPIN_SERVE = 2;

const float BV_RESULT_TARGET = 1;
const float BV_RESULT_IN = 2;
const float BV_RESULT_OUT = 3;
const float BV_RESULT_OWN = 4;
const float BV_RESULT_MISS = 5;
const float BV_RESULT_UNDER = 6;
const float BV_RESULT_NET = 7;
const float BV_RESULT_ANTENNA = 10;

/* Custom stats are shared by the server and HUD. Vector stats occupy three
 * consecutive slots; keep the player and preview vectors separate.
 */
const float BV_STAT_ARC = 32;
const float BV_STAT_SIDE = 33;
const float BV_STAT_CHARGE = 34;
const float BV_STAT_KIND = 35;
const float BV_STAT_STATE = 36;
const float BV_STAT_SPEED = 37;
const float BV_STAT_QUALITY = 38;
const float BV_STAT_TARGETS = 39;
const float BV_STAT_ATTEMPTS = 40;
const float BV_STAT_MODE = 41;
const float BV_STAT_TOP = 42;
const float BV_STAT_AIM_LOCKED = 43;
const float BV_STAT_RESULT = 45;
const float BV_STAT_BALL = 48;
const float BV_STAT_PLAYER = 51;
const float BV_STAT_PREVIEW = 54;
const float BV_STAT_PREVIEW_RESULT = 57;
const float BV_STAT_PREVIEW_RANGE = 58;
const float BV_STAT_PREVIEW_HEIGHT = 59;
const float BV_STAT_FEEDBACK_AGE = 60;
const float BV_STAT_REACH = 61;
const float BV_STAT_FEED_DELAY = 62;
const float BV_STAT_DEPTH = 63;
const float BV_STAT_CONTACT_NOTE = 64;
const float BV_STAT_TIMING = 65;
const float BV_STAT_SERVING = 66;
const float BV_STAT_MATCH = 67;
const float BV_STAT_HOME_SCORE = 68;
const float BV_STAT_AWAY_SCORE = 69;
const float BV_STAT_TOUCHES = 70;
const float BV_STAT_TOUCH_TEAM = 71;
const float BV_STAT_PHASE = 72;
const float BV_STAT_SERVE_TEAM = 73;
const float BV_STAT_ASSISTED = 74;
const float BV_STAT_OVERLAYS = 75;
const float BV_STAT_RECOVERY = 76;
const float BV_STAT_PARTNER = 77;
const float BV_STAT_OPPONENT1 = 80;
const float BV_STAT_OPPONENT2 = 83;
const float BV_STAT_HINT = 86;
const float BV_STAT_POINT_REASON = 87;
const float BV_STAT_SERVE_STYLE = 88;
const float BV_STAT_RECEIVING = 89;
const float BV_POINT_DOUBLE = 8;
const float BV_POINT_FOUR = 9;

const float BV_MATCH_SERVE = 1;
const float BV_MATCH_RALLY = 2;
const float BV_MATCH_POINT = 3;
const float BV_MATCH_OVER = 4;
const float BV_HINT_RECEIVE = 1;
const float BV_HINT_SET = 2;
const float BV_HINT_ATTACK = 3;
const float BV_HINT_COVER = 4;
const float BV_HINT_SERVE = 5;

const float BV_NOTE_CLEAN = 0;
const float BV_NOTE_PREPARATION = 1;
const float BV_NOTE_REACH = 2;
const float BV_NOTE_FOOTING = 3;
const float BV_NOTE_DIVE = 4;
const float BV_NOTE_TIMING = 5;
const float BV_NOTE_EARLY = 6;
const float BV_NOTE_LATE = 7;
const float BV_NOTE_PLATFORM = 8;
const float BV_NOTE_ASSIST = 9;

float(float value) BV_Round =
{
    return floor(value + 0.5);
};

/* QSS-M's ftos can expose every binary-float digit. Build the fraction from
 * integers so all HUD distances and speeds have exactly one decimal place.
 */
string(float value) BV_Decimal =
{
    local float rounded, whole;
    local string sign;
    sign = "";
    if (value < 0) sign = "-";
    rounded = BV_Round(fabs(value) * 10);
    whole = floor(rounded / 10);
    return strcat(sign, ftos(whole), ".", ftos(rounded - whole * 10));
};

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
