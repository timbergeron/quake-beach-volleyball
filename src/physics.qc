// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* One integrator serves live play, trajectory previews, and QC regression tests.
 * Output globals avoid allocations in the 120 Hz loop.
 */
var float autocvar_bv_gravity = 313.92;
var float autocvar_bv_drag = 0.0008;
var float autocvar_bv_magnus = 0.003;
var float autocvar_bv_spin_decay = 0.18;
var float autocvar_bv_wind_x = 0;
var float autocvar_bv_wind_y = 0;

vector bv_step_position, bv_step_velocity, bv_step_spin;
vector bv_landing;
float bv_flight_time, bv_apex;
float bv_predict_net, bv_predict_under_net;

void(vector position, vector velocity, vector spin, float dt) BV_Integrate =
{
    local vector air, acceleration, wind;
    local float drag, decay;
    wind = '0 0 0';
    wind_x = autocvar_bv_wind_x;
    wind_y = autocvar_bv_wind_y;
    air = velocity - wind;
    drag = BV_Clamp(autocvar_bv_drag, 0, 0.01);
    acceleration = BV_Cross(spin, air) * BV_Clamp(autocvar_bv_magnus, 0, 0.02);
    acceleration = acceleration - air * (vlen(air) * drag);
    acceleration_z = acceleration_z - BV_Clamp(autocvar_bv_gravity, 100, 800);
    bv_step_velocity = velocity + acceleration * dt;
    bv_step_position = position + (velocity + bv_step_velocity) * (0.5 * dt);
    decay = 1 - BV_Clamp(autocvar_bv_spin_decay, 0, 5) * dt;
    bv_step_spin = spin * BV_Clamp(decay, 0, 1);
};

vector(vector start, vector target, float apex) BV_BallisticVelocity =
{
    local float gravity, up, down, duration;
    local vector velocity;
    gravity = BV_Clamp(autocvar_bv_gravity, 100, 800);
    apex = BV_Clamp(apex, start_z + 1, 1024);
    if (apex < target_z + 1) apex = target_z + 1;
    up = sqrt(2 * gravity * (apex - start_z));
    down = sqrt(2 * (apex - target_z) / gravity);
    duration = up / gravity + down;
    velocity = (target - start) * (1 / duration);
    velocity_z = up;
    return velocity;
};

vector(vector a, vector b, vector point) BV_ClosestPoint =
{
    local vector segment;
    local float fraction, length_squared;
    segment = b - a;
    length_squared = segment * segment;
    if (length_squared < 0.00001) return a;
    fraction = BV_Clamp(((point - a) * segment) / length_squared, 0, 1);
    return a + segment * fraction;
};

/* A swept sphere against the net plane, including the top tape and edges.
 * Net collisions use the crossing position, not the end of the time step.
 */
float bv_net_fraction;
vector bv_net_position;

float(vector start, vector finish) BV_NetSweep =
{
    local float side, plane, fraction;
    local vector position;
    bv_net_fraction = 1;
    if (start_x < 0) side = -1;
    else side = 1;
    plane = side * (BV_RADIUS + 0.65);
    if (side * start_x < BV_RADIUS + 0.65) return FALSE;
    if (side * finish_x >= BV_RADIUS + 0.65) return FALSE;
    fraction = (plane - start_x) / (finish_x - start_x);
    position = start + (finish - start) * fraction;
    if (fabs(position_y) > BV_HALF_WIDTH + BV_RADIUS) return FALSE;
    if (position_z < 43 - BV_RADIUS ||
        position_z > BV_NET_HEIGHT + BV_RADIUS) return FALSE;
    bv_net_fraction = fraction;
    bv_net_position = position;
    return TRUE;
};

/* Preview uses the same forces as live play. It includes net contact and
 * interpolates the exact ground crossing instead of snapping to a step.
 */
void(vector position, vector velocity, vector spin) BV_Predict =
{
    local float duration, fraction;
    local vector old;
    duration = 0;
    bv_apex = position_z;
    bv_predict_net = FALSE;
    bv_predict_under_net = FALSE;
    while (duration < 8)
    {
        old = position;
        BV_Integrate(position, velocity, spin, BV_STEP);
        position = bv_step_position;
        velocity = bv_step_velocity;
        spin = bv_step_spin;
        if (old_x * position_x < 0)
        {
            fraction = fabs(old_x) / (fabs(old_x) + fabs(position_x));
            if (old_z + (position_z - old_z) * fraction < 43 - BV_RADIUS)
                bv_predict_under_net = TRUE;
        }
        if (BV_NetSweep(old, position))
        {
            bv_predict_net = TRUE;
            position = bv_net_position;
            position_x = position_x + (old_x - position_x) * 0.001;
            velocity_x = -velocity_x * 0.22;
            velocity_y = velocity_y * 0.65;
            velocity_z = velocity_z * 0.65;
            spin = spin * 0.4;
        }
        duration = duration + BV_STEP;
        if (position_z > bv_apex) bv_apex = position_z;
        if (position_z <= BV_RADIUS)
        {
            fraction = BV_Clamp((old_z - BV_RADIUS) / (old_z - position_z), 0, 1);
            bv_landing = old + (position - old) * fraction;
            bv_landing_z = BV_RADIUS;
            bv_flight_time = duration - BV_STEP + BV_STEP * fraction;
            return;
        }
    }
    bv_landing = position;
    bv_flight_time = duration;
};
