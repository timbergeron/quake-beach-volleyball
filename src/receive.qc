// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Receive skill comes from a physical rebound: read the approach, aim the
 * platform, plant, cushion the speed and release as the ball reaches it.
 */
float(entity player) BV_IsReceiving =
{
    if (player.bv_serve_contact) return FALSE;
    if (player.bv_receive_contact) return TRUE;
    if (bv_ball_state != BV_LIVE) return FALSE;
    if (bv_match)
        return bv_match_phase == BV_MATCH_RALLY && bv_touch_team != BV_Team(player);
    return player.bv_mode == 1 && bv_feeder == player && bv_last_player != player;
};

float(entity player) BV_ReceiveError =
{
    local vector relative_position, relative_velocity;
    local float speed_squared;
    BV_ContactZone(player, bv_ball.origin);
    relative_position = bv_ball.origin - bv_hand_position;
    relative_velocity = bv_ball.velocity - player.velocity;
    speed_squared = relative_velocity * relative_velocity;
    if (speed_squared < 1) return 0;
    return -(relative_position * relative_velocity) / speed_squared;
};

float(entity player) BV_ReceiveTiming =
{
    local float timing;
    if (player.bv_receive_committed) return player.bv_release_timing;
    timing = 1 - BV_Smooth((fabs(BV_ReceiveError(player)) - 0.035) / 0.12);
    if (!player.bv_isbot && player.bv_assisted && player.bv_preparing)
        timing = BV_Clamp(timing, 0, 0.6);
    return timing;
};

/* Anticipate the ordinary falling approach from the trajectory being read.
 * Float wake is deliberately omitted: late drift must still be handled by
 * movement and a fresh platform read through Shift, rather than auto aim.
 */
vector(entity player) BV_ReadIncoming =
{
    local vector position, flight_velocity, spin;
    local float age, height;
    position = bv_ball.origin;
    flight_velocity = bv_ball.velocity;
    spin = bv_ball_spin;
    height = player.origin_z + 20;
    if (player.bv_action == 2) height = player.origin_z + 45;
    age = 0;
    while (age < 3 && !(flight_velocity_z < 0 && position_z <= height))
    {
        BV_Integrate(position, flight_velocity, spin, BV_STEP * 2);
        position = bv_step_position;
        flight_velocity = bv_step_velocity;
        spin = bv_step_spin;
        age = age + BV_STEP * 2;
    }
    return normalize(flight_velocity);
};

void(entity player, vector contact) BV_BuildReceive =
{
    local vector heading, desired, read, normal, incoming, horizontal;
    local float angle, cushion, speed;
    horizontal = player.velocity;
    horizontal_z = 0;
    incoming = bv_ball.velocity - horizontal;
    heading = player.bv_aim;
    if (vlen(heading) < 0.5) heading = BV_Heading(player.v_angle_y);
    angle = (50 + player.bv_arc * 25 + BV_Clamp(-player.bv_last_pitch, -15, 15)) * BV_PI / 180;
    desired = heading * cos(angle) + '0 0 1' * sin(angle);
    cushion = 0.44 + BV_Clamp(player.bv_depth, -1, 1) * 0.16;
    read = player.bv_read_direction;
    if (vlen(read) < 0.5) read = normalize(incoming);
    if (player.bv_isbot)
    {
        // AI chooses its platform/cushion; reach, footing and timing still grade it.
        desired = BV_BallisticVelocity(contact, player.bv_shot_target, player.bv_shot_apex);
        speed = vlen(desired);
        desired = normalize(desired);
        read = normalize(incoming);
        cushion = BV_Clamp((speed - 80) / BV_Clamp(vlen(incoming), 1, 1200), 0.2, 0.6);
    }
    normal = normalize(desired - read);
    if (vlen(normal) < 0.5) normal = '0 0 1';
    bv_shot_velocity = BV_Reflect(incoming, normal, cushion, cushion) + desired * 80;
    bv_shot_spin = bv_ball_spin * 0.06;
    bv_shot_float = 0;
    bv_shot_phase = 0;
    bv_shot_kind = BV_PASS;
    if (player.bv_action == 2) bv_shot_kind = BV_SET;
    if (incoming * normal >= -5)
    {
        // A platform facing away cannot turn the incoming ball into a perfect pass.
        bv_shot_velocity = incoming * 0.6 + desired * 30;
        bv_contact_quality = BV_Clamp(bv_contact_quality * 0.65, 0.35, 1);
        bv_contact_reason = BV_NOTE_PLATFORM;
    }
};
