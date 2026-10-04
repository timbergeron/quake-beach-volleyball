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

/* Sweep the ball centre through the mesh/tape volume expanded by its radius.
 * Slab entry handles every direction, including drops onto the top tape.
 */
float bv_box_enter, bv_box_leave, bv_box_fraction;
vector bv_box_normal, bv_box_position;

float(float start, float delta, float low, float high, vector axis) BV_BoxSlab =
{
    local float enter, leave, swap;
    local vector normal;
    if (fabs(delta) < 0.000001) return start >= low && start <= high;
    enter = (low - start) / delta;
    leave = (high - start) / delta;
    normal = -axis;
    if (enter > leave)
    {
        swap = enter;
        enter = leave;
        leave = swap;
        normal = axis;
    }
    if (enter > bv_box_enter)
    {
        bv_box_enter = enter;
        bv_box_normal = normal;
    }
    if (leave < bv_box_leave) bv_box_leave = leave;
    return bv_box_enter <= bv_box_leave;
};

float(vector start, vector finish, vector low, vector high) BV_BoxSweep =
{
    local vector delta;
    local float depth, candidate;
    low = low - '1 1 1' * BV_RADIUS;
    high = high + '1 1 1' * BV_RADIUS;
    delta = finish - start;
    if (start_x >= low_x && start_x <= high_x &&
        start_y >= low_y && start_y <= high_y &&
        start_z >= low_z && start_z <= high_z)
    {
        /* A partially embedded ball must be able to leave the net. Resolve
         * inward motion toward the nearest face, rather than tunnelling.
         */
        depth = start_x - low_x;
        bv_box_normal = '-1 0 0';
        candidate = high_x - start_x;
        if (candidate < depth) { depth = candidate; bv_box_normal = '1 0 0'; }
        candidate = start_y - low_y;
        if (candidate < depth) { depth = candidate; bv_box_normal = '0 -1 0'; }
        candidate = high_y - start_y;
        if (candidate < depth) { depth = candidate; bv_box_normal = '0 1 0'; }
        candidate = start_z - low_z;
        if (candidate < depth) { depth = candidate; bv_box_normal = '0 0 -1'; }
        candidate = high_z - start_z;
        if (candidate < depth) { depth = candidate; bv_box_normal = '0 0 1'; }
        if (delta * bv_box_normal > 0) return FALSE;
        bv_box_fraction = 0;
        bv_box_position = start + bv_box_normal * depth;
        return TRUE;
    }
    bv_box_enter = 0;
    bv_box_leave = 1;
    bv_box_normal = '0 0 0';
    if (!BV_BoxSlab(start_x, delta_x, low_x, high_x, '1 0 0')) return FALSE;
    if (!BV_BoxSlab(start_y, delta_y, low_y, high_y, '0 1 0')) return FALSE;
    if (!BV_BoxSlab(start_z, delta_z, low_z, high_z, '0 0 1')) return FALSE;
    bv_box_fraction = bv_box_enter;
    bv_box_position = start + delta * bv_box_enter;
    return vlen(bv_box_normal) > 0.5;
};

float bv_net_fraction;
vector bv_net_position, bv_net_normal;

float(vector start, vector finish) BV_NetSweep =
{
    local vector low, high;
    local float hit;
    hit = FALSE;
    bv_net_fraction = 1;
    low = '-0.65 -128 43';
    high = '0.65 128 0';
    high_z = BV_NET_HEIGHT;
    if (BV_BoxSweep(start, finish, low, high))
    {
        hit = TRUE;
        bv_net_fraction = bv_box_fraction;
        bv_net_position = bv_box_position;
        bv_net_normal = bv_box_normal;
    }
    low = '-1 -144 0';
    low_z = BV_NET_HEIGHT - 3;
    high = '1 144 0';
    high_z = BV_NET_HEIGHT;
    if (BV_BoxSweep(start, finish, low, high) &&
        (!hit || bv_box_fraction < bv_net_fraction))
    {
        hit = TRUE;
        bv_net_fraction = bv_box_fraction;
        bv_net_position = bv_box_position;
        bv_net_normal = bv_box_normal;
    }
    return hit;
};

float(vector start, vector finish) BV_UnderNetSweep =
{
    local float fraction;
    local vector crossing;
    if (!((start_x < 0 && finish_x >= 0) || (start_x > 0 && finish_x <= 0)))
        return FALSE;
    fraction = -start_x / (finish_x - start_x);
    crossing = start + (finish - start) * fraction;
    return fabs(crossing_y) <= BV_HALF_WIDTH + BV_RADIUS && crossing_z < 43 - BV_RADIUS;
};

vector(vector velocity, vector normal, float bounce, float damping) BV_Reflect =
{
    local vector perpendicular;
    perpendicular = normal * (velocity * normal);
    return (velocity - perpendicular) * damping - perpendicular * bounce;
};

/* Consider the first floor or net event, and never classify a crossing that
 * lies beyond that event. Live play additionally traces BSP surroundings.
 */
void(vector position, vector velocity, vector spin) BV_Predict =
{
    local float duration, fraction, event;
    local vector old, impact, normal;
    duration = 0;
    bv_apex = position_z;
    bv_predict_net = FALSE;
    bv_predict_under_net = FALSE;
    while (duration < BV_MAX_FLIGHT)
    {
        old = position;
        BV_Integrate(position, velocity, spin, BV_STEP);
        position = bv_step_position;
        velocity = bv_step_velocity;
        spin = bv_step_spin;
        event = 0;
        normal = '0 0 0';
        fraction = 1;
        impact = position;
        if (position_z <= BV_RADIUS)
        {
            event = 1;
            fraction = 0;
            if (old_z != position_z)
                fraction = BV_Clamp((old_z - BV_RADIUS) / (old_z - position_z), 0, 1);
            impact = old + (position - old) * fraction;
            impact_z = BV_RADIUS;
        }
        if (BV_NetSweep(old, position) && bv_net_fraction < fraction)
        {
            event = 2;
            fraction = bv_net_fraction;
            impact = bv_net_position;
            normal = bv_net_normal;
        }
        if (BV_UnderNetSweep(old, impact)) bv_predict_under_net = TRUE;
        duration = duration + BV_STEP;
        position = impact;
        if (position_z > bv_apex) bv_apex = position_z;
        if (event == 1)
        {
            bv_landing = position;
            bv_flight_time = duration - BV_STEP + BV_STEP * fraction;
            return;
        }
        if (event == 2)
        {
            bv_predict_net = TRUE;
            position = position + normal * 0.01;
            velocity = BV_Reflect(velocity, normal, 0.22, 0.65);
            spin = spin * 0.4;
        }
    }
    bv_landing = position;
    bv_flight_time = duration;
};
