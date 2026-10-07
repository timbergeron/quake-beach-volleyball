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

float() BV_JumpSpeed =
{
    return sqrt(2 * BV_Clamp(autocvar_bv_gravity, 100, 800) * BV_JUMP_HEIGHT);
};

vector bv_step_position, bv_step_velocity, bv_step_spin;
float bv_step_phase;
vector bv_landing;
float bv_flight_time, bv_apex;
float bv_predict_net, bv_predict_under_net, bv_predict_antenna;
vector bv_visual_forward, bv_visual_up, bv_draw_angles;

void() BV_ResetBallRotation =
{
    bv_visual_forward = '1 0 0';
    bv_visual_up = '0 0 1';
    bv_draw_angles = '0 0 0';
};

vector(vector point, vector axis, float angle) BV_RotateAxis =
{
    return point * cos(angle) + BV_Cross(axis, point) * sin(angle) +
        axis * (axis * point) * (1 - cos(angle));
};

float(float angle, float previous) BV_AngleDelta =
{
    local float delta;
    delta = angle - previous;
    return delta - floor((delta + 180) / 360) * 360;
};

/* Spin is a world-axis angular velocity. Entity angles are pitch/yaw/roll,
 * not XYZ rotations. Keep an orthonormal model basis, rotate it about the
 * actual spin axis, then convert to Quake's model (upward pitch) convention.
 */
void(vector spin, float dt) BV_AdvanceBallRotation =
{
    local vector axis, left, direction, heading, previous, alternate, delta, other;
    local float speed, horizontal;
    if (vlen(bv_visual_forward) < 0.5) BV_ResetBallRotation();
    speed = vlen(spin);
    if (speed < 0.0001) return;
    previous = bv_draw_angles;
    axis = spin * (1 / speed);
    bv_visual_forward = normalize(BV_RotateAxis(bv_visual_forward, axis, speed * dt));
    bv_visual_up = BV_RotateAxis(bv_visual_up, axis, speed * dt);
    left = normalize(BV_Cross(bv_visual_up, bv_visual_forward));
    bv_visual_up = normalize(BV_Cross(bv_visual_forward, left));
    horizontal = sqrt(bv_visual_forward_x * bv_visual_forward_x +
        bv_visual_forward_y * bv_visual_forward_y);
    direction = '0 0 0';
    direction_x = horizontal;
    direction_y = bv_visual_forward_z;
    bv_draw_angles_x = atan2(direction_y, direction_x) * 180 / BV_PI;
    if (horizontal > 0.0001)
    {
        bv_draw_angles_y = atan2(bv_visual_forward_y, bv_visual_forward_x) * 180 / BV_PI;
        direction_x = bv_visual_up_z;
        direction_y = left_z;
    }
    else
    {
        // At a vertical forward axis, retain yaw and solve roll horizontally.
        heading = BV_Heading(bv_draw_angles_y);
        direction_x = left * BV_Cross('0 0 1', heading);
        direction_y = -(left * heading) * bv_visual_forward_z;
    }
    bv_draw_angles_z = atan2(direction_y, direction_x) * 180 / BV_PI;
    // Equivalent Euler branches avoid a yaw/roll half-turn at vertical pitch.
    alternate_x = 180 - bv_draw_angles_x;
    alternate_y = bv_draw_angles_y + 180;
    alternate_z = bv_draw_angles_z + 180;
    delta_x = BV_AngleDelta(bv_draw_angles_x, previous_x);
    delta_y = BV_AngleDelta(bv_draw_angles_y, previous_y);
    delta_z = BV_AngleDelta(bv_draw_angles_z, previous_z);
    other_x = BV_AngleDelta(alternate_x, previous_x);
    other_y = BV_AngleDelta(alternate_y, previous_y);
    other_z = BV_AngleDelta(alternate_z, previous_z);
    if (other * other < delta * delta) bv_draw_angles = alternate;
    bv_draw_angles_x = bv_draw_angles_x - floor(bv_draw_angles_x / 360) * 360;
    bv_draw_angles_y = bv_draw_angles_y - floor(bv_draw_angles_y / 360) * 360;
    bv_draw_angles_z = bv_draw_angles_z - floor(bv_draw_angles_z / 360) * 360;
};

/* A bounded wake approximation, rather than random kicks: every flight owns
 * its phase so prediction and live play see exactly the same float movement.
 */
void(vector position, vector velocity, vector spin, float dt,
     float floating, float phase) BV_IntegrateFlight =
{
    local vector air, acceleration, wind, lateral;
    local float drag, decay, wake;
    wind = '0 0 0';
    wind_x = autocvar_bv_wind_x;
    wind_y = autocvar_bv_wind_y;
    air = velocity - wind;
    drag = BV_Clamp(autocvar_bv_drag, 0, 0.01);
    acceleration = BV_Cross(spin, air) * BV_Clamp(autocvar_bv_magnus, 0, 0.02);
    acceleration = acceleration - air * (vlen(air) * drag);
    lateral = air;
    lateral_z = 0;
    lateral = BV_Cross('0 0 1', normalize(lateral));
    wake = BV_Clamp(floating, 0, 1) * (1 - BV_Clamp(vlen(spin) / 8, 0, 1)) *
        BV_Clamp((air * air) / 202500, 0, 1.5);
    acceleration = acceleration + lateral * (wake * 60 *
        (sin(phase * 8.4) * 0.65 + sin(phase * 17.9 + 1.7) * 0.35));
    acceleration_z = acceleration_z + wake * 45 *
        (sin(phase * 11.3 + 0.8) * 0.65 + sin(phase * 23.1) * 0.35);
    acceleration_z = acceleration_z - BV_Clamp(autocvar_bv_gravity, 100, 800);
    bv_step_velocity = velocity + acceleration * dt;
    bv_step_position = position + (velocity + bv_step_velocity) * (0.5 * dt);
    decay = 1 - BV_Clamp(autocvar_bv_spin_decay, 0, 5) * dt;
    bv_step_spin = spin * BV_Clamp(decay, 0, 1);
    bv_step_phase = phase + dt;
};

void(vector position, vector velocity, vector spin, float dt) BV_Integrate =
{
    BV_IntegrateFlight(position, velocity, spin, dt, 0, 0);
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

float(vector start, vector finish, vector low, vector high, float radius) BV_BoxSweepRadius =
{
    local vector delta;
    local float depth, candidate;
    low = low - '1 1 1' * radius;
    high = high + '1 1 1' * radius;
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

float(vector start, vector finish, vector low, vector high) BV_BoxSweep =
{
    return BV_BoxSweepRadius(start, finish, low, high, BV_RADIUS);
};

float bv_net_fraction;
vector bv_net_position, bv_net_normal;

float(vector start, vector finish, float radius) BV_NetSweepRadius =
{
    local vector low, high;
    local float hit;
    hit = FALSE;
    bv_net_fraction = 1;
    low_x = -BV_NET_HALF_DEPTH;
    low_y = -BV_NET_HALF_LENGTH;
    low_z = BV_NET_BOTTOM;
    high_x = BV_NET_HALF_DEPTH;
    high_y = BV_NET_HALF_LENGTH;
    high_z = BV_NET_HEIGHT;
    if (BV_BoxSweepRadius(start, finish, low, high, radius))
    {
        hit = TRUE;
        bv_net_fraction = bv_box_fraction;
        bv_net_position = bv_box_position;
        bv_net_normal = bv_box_normal;
    }
    return hit;
};

float(vector start, vector finish) BV_NetSweep =
{
    return BV_NetSweepRadius(start, finish, BV_RADIUS);
};

float bv_capsule_fraction;
vector bv_capsule_position, bv_capsule_normal;

void(vector start, vector delta, vector centre, float radius) BV_CapsuleSphere =
{
    local vector relative, position;
    local float a, b, c, discriminant, fraction;
    relative = start - centre;
    a = delta * delta;
    if (a < 0.0000001) return;
    b = relative * delta;
    c = relative * relative - radius * radius;
    discriminant = b * b - a * c;
    if (discriminant < 0) return;
    fraction = (-b - sqrt(discriminant)) / a;
    if (fraction < 0 || fraction > 1 || fraction >= bv_capsule_fraction) return;
    position = start + delta * fraction;
    bv_capsule_fraction = fraction;
    bv_capsule_position = position;
    bv_capsule_normal = normalize(position - centre);
};

/* Swept sphere against a vertical capsule: padded posts and antenna rods.
 * End caps matter for descending balls; overlap may only move away freely.
 */
float(vector start, vector finish, vector centre, float low_z, float high_z,
      float radius) BV_CapsuleSweep =
{
    local vector delta, relative, nearest, position;
    local float distance, a, b, c, discriminant, fraction;
    bv_capsule_fraction = 2;
    // Most forecast steps are far from equipment. Reject those before roots.
    if ((start_x < centre_x - radius && finish_x < centre_x - radius) ||
        (start_x > centre_x + radius && finish_x > centre_x + radius) ||
        (start_y < centre_y - radius && finish_y < centre_y - radius) ||
        (start_y > centre_y + radius && finish_y > centre_y + radius) ||
        (start_z < low_z - radius && finish_z < low_z - radius) ||
        (start_z > high_z + radius && finish_z > high_z + radius)) return FALSE;
    delta = finish - start;
    nearest = centre;
    nearest_z = BV_Clamp(start_z, low_z, high_z);
    relative = start - nearest;
    distance = vlen(relative);
    if (distance < radius - 0.00001)
    {
        bv_capsule_normal = normalize(relative);
        if (distance < 0.00001) bv_capsule_normal = normalize(-delta);
        if (vlen(bv_capsule_normal) < 0.5) bv_capsule_normal = '1 0 0';
        if (delta * bv_capsule_normal >= 0) return FALSE;
        bv_capsule_fraction = 0;
        bv_capsule_position = nearest + bv_capsule_normal * radius;
        return TRUE;
    }
    relative = start - centre;
    a = delta_x * delta_x + delta_y * delta_y;
    b = relative_x * delta_x + relative_y * delta_y;
    c = relative_x * relative_x + relative_y * relative_y - radius * radius;
    if (a > 0.0000001)
    {
        discriminant = b * b - a * c;
        if (discriminant >= 0)
        {
            fraction = (-b - sqrt(discriminant)) / a;
            position = start + delta * fraction;
            if (fraction >= 0 && fraction <= 1 && position_z >= low_z && position_z <= high_z)
            {
                bv_capsule_fraction = fraction;
                bv_capsule_position = position;
                position_z = centre_z;
                bv_capsule_normal = normalize(position - centre);
            }
        }
    }
    centre_z = low_z;
    BV_CapsuleSphere(start, delta, centre, radius);
    centre_z = high_z;
    BV_CapsuleSphere(start, delta, centre, radius);
    return bv_capsule_fraction <= 1;
};

float bv_equipment_fraction, bv_equipment_kind;
vector bv_equipment_position, bv_equipment_normal;

float(vector start, vector finish, float radius) BV_EquipmentSweepRadius =
{
    local float side, kind;
    local vector centre;
    bv_equipment_fraction = 2;
    bv_equipment_kind = 0;
    if (BV_NetSweepRadius(start, finish, radius))
    {
        bv_equipment_fraction = bv_net_fraction;
        bv_equipment_position = bv_net_position;
        bv_equipment_normal = bv_net_normal;
        bv_equipment_kind = 1;
    }
    side = -1;
    while (side <= 1)
    {
        kind = 2;
        while (kind <= 3)
        {
            centre = '0 0 0';
            centre_y = side * BV_POST_Y;
            if (kind == 2)
                BV_CapsuleSweep(start, finish, centre, BV_POST_RADIUS,
                    BV_POST_HEIGHT - BV_POST_RADIUS, BV_POST_RADIUS + radius);
            else
            {
                centre_x = side * BV_ANTENNA_X;
                centre_y = side * BV_ANTENNA_Y;
                BV_CapsuleSweep(start, finish, centre, BV_NET_BOTTOM + BV_ANTENNA_RADIUS,
                    BV_ANTENNA_TOP - BV_ANTENNA_RADIUS, BV_ANTENNA_RADIUS + radius);
            }
            if (bv_capsule_fraction <= 1 && bv_capsule_fraction < bv_equipment_fraction)
            {
                bv_equipment_fraction = bv_capsule_fraction;
                bv_equipment_position = bv_capsule_position;
                bv_equipment_normal = bv_capsule_normal;
                bv_equipment_kind = kind;
            }
            kind = kind + 1;
        }
        side = side + 2;
    }
    return bv_equipment_kind > 0;
};

float(vector start, vector finish) BV_EquipmentSweep =
{
    return BV_EquipmentSweepRadius(start, finish, BV_RADIUS);
};

float(vector start, vector finish) BV_UnderNetSweep =
{
    local float fraction;
    local vector crossing;
    if (!((start_x < 0 && finish_x >= 0) || (start_x > 0 && finish_x <= 0)))
        return FALSE;
    fraction = -start_x / (finish_x - start_x);
    crossing = start + (finish - start) * fraction;
    return fabs(crossing_y) <= BV_HALF_WIDTH + BV_RADIUS &&
        crossing_z < BV_NET_BOTTOM - BV_RADIUS;
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
void(vector position, vector velocity, vector spin, float floating, float phase) BV_PredictFlight =
{
    local float duration, fraction, event;
    local vector old, impact, normal;
    duration = 0;
    bv_apex = position_z;
    bv_predict_net = FALSE;
    bv_predict_under_net = FALSE;
    bv_predict_antenna = FALSE;
    while (duration < BV_MAX_FLIGHT)
    {
        old = position;
        BV_IntegrateFlight(position, velocity, spin, BV_STEP, floating, phase);
        position = bv_step_position;
        velocity = bv_step_velocity;
        spin = bv_step_spin;
        phase = bv_step_phase;
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
        if (BV_EquipmentSweep(old, position) && bv_equipment_fraction < fraction)
        {
            event = bv_equipment_kind;
            if (event == 1) event = 2;
            else if (event == 2) event = 4;
            else event = 5;
            fraction = bv_equipment_fraction;
            impact = bv_equipment_position;
            normal = bv_equipment_normal;
        }
        if (BV_UnderNetSweep(old, impact)) bv_predict_under_net = TRUE;
        duration = duration + BV_STEP;
        position = impact;
        if (event == 5)
        {
            bv_predict_antenna = TRUE;
            bv_landing = position;
            bv_flight_time = duration - BV_STEP + BV_STEP * fraction;
            return;
        }
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
            floating = floating * 0.4;
        }
        if (event == 4)
        {
            position = position + normal * 0.01;
            velocity = BV_Reflect(velocity, normal, 0.3, 1);
            spin = spin * 0.4;
            floating = floating * 0.4;
        }
    }
    bv_landing = position;
    bv_flight_time = duration;
};

void(vector position, vector velocity, vector spin) BV_Predict =
{
    BV_PredictFlight(position, velocity, spin, 0, 0);
};
