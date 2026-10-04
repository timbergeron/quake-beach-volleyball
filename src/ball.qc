// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
.float bv_isplayer;
.float bv_arc, bv_sidespin, bv_topspin, bv_charge, bv_kind;
.float bv_preparing, bv_prepare_started, bv_armed_until, bv_last_contact;
.float bv_action, bv_serve_contact, bv_previous_primary, bv_previous_secondary;
.float bv_previous_jump, bv_previous_dive, bv_dive_until, bv_dive_ready;
.float bv_mode, bv_targets, bv_attempts, bv_quality, bv_state;
.float bv_last_speed, bv_aim_locked, bv_last_result, bv_last_pitch;
.float bv_preview_next;
.float bv_contact_side;
.vector bv_aim;
.entity bv_marker;
.string bv_message;
.float button3, button4, button5, button6, button7, button8;
.float gravity;

entity bv_ball, bv_holder, bv_last_player, bv_feeder;
vector bv_ball_spin;
float bv_ball_state, bv_accumulator, bv_next_feed, bv_net_touched, bv_under_net;
vector bv_ball_position;

void(entity player, vector contact) BV_Contact;
void(entity player) BV_Feed;

float(vector position) BV_InCourt =
{
    return fabs(position_x) <= BV_HALF_LENGTH + BV_RADIUS &&
           fabs(position_y) <= BV_HALF_WIDTH + BV_RADIUS;
};

/* Six painted targets on the far court, all represented by identical boxes
 * in assets.py. The centre and short targets make placement easy to compare.
 */
float(vector position) BV_OnTarget =
{
    local float x, y;
    x = fabs(position_x);
    y = fabs(position_y);
    return (fabs(x - 80) <= 28 || fabs(x - 208) <= 28) &&
           (y <= 26 || fabs(y - 92) <= 26);
};

void(vector position) BV_FinishRally =
{
    bv_ball_state = BV_DEAD;
    bv_ball.velocity = '0 0 0';
    bv_ball_spin = '0 0 0';
    setorigin(bv_ball, position);
    if (bv_last_player != world)
    {
        bv_last_player.bv_attempts = bv_last_player.bv_attempts + 1;
        if (bv_under_net)
        {
            bv_last_player.bv_message = "UNDER NET";
            bv_last_player.bv_last_result = 6;
        }
        else if (!BV_InCourt(position))
        {
            bv_last_player.bv_message = "OUT - reduce power or change arc";
            bv_last_player.bv_last_result = 3;
        }
        else if (position_x * bv_last_player.bv_contact_side >= 0)
        {
            if (bv_net_touched)
                bv_last_player.bv_message = "NET - give the ball more clearance";
            else
                bv_last_player.bv_message = "OWN COURT - prepare the next contact";
            bv_last_player.bv_last_result = 4;
        }
        else if (BV_OnTarget(position))
        {
            bv_last_player.bv_targets = bv_last_player.bv_targets + 1;
            bv_last_player.bv_message = "TARGET HIT";
            bv_last_player.bv_last_result = 1;
            sound(bv_ball, 1, "beach/target.wav", 0.7, 1);
        }
        else
        {
            bv_last_player.bv_message = "IN - try placing the next shot on a target";
            bv_last_player.bv_last_result = 2;
        }
    }
    if (bv_feeder != world && bv_feeder.bv_mode > 0)
        bv_next_feed = time + 1.35;
};

/* Release arms a short contact window. A fast ball crossing the hands
 * between frames can still be hit, but cannot be hit across the court.
 */
float(vector start, vector finish) BV_TryContacts =
{
    local entity player;
    local vector hand, closest, heading;
    local float reach, height;
    player = find(world, classname, "player");
    while (player != world)
    {
        if (player.bv_isplayer && player.bv_armed_until >= time &&
            player.bv_armed_until > 0 && time - player.bv_last_contact > 0.22)
        {
            heading = BV_Heading(player.v_angle_y);
            height = 20;
            reach = 25;
            if (player.bv_action == 2) height = 45;
            if (player.bv_serve_contact ||
                (player.bv_action == 1 && start_z > player.origin_z + 36))
            {
                height = 53;
                reach = 30;
            }
            if (player.bv_dive_until > time)
            {
                height = 2;
                reach = 32;
            }
            hand = player.origin + heading * 17 + '0 0 1' * height;
            closest = BV_ClosestPoint(start, finish, hand);
            if (vlen(closest - hand) <= reach + BV_RADIUS)
            {
                /* Prevent reaching through the mesh or a solid obstacle. */
                traceline(hand, closest, TRUE, player);
                if (trace_fraction == 1 &&
                    !(hand_x * closest_x < 0 &&
                      fabs(closest_y) < BV_HALF_WIDTH &&
                      closest_z < BV_NET_HEIGHT + BV_RADIUS))
                {
                    BV_Contact(player, closest);
                    return TRUE;
                }
            }
        }
        player = find(player, classname, "player");
    }
    return FALSE;
};

void(float dt) BV_BallStep =
{
    local vector old, position, launch_velocity, spin;
    local float fraction;
    if (bv_ball_state != BV_LIVE) return;
    old = bv_ball.origin;
    BV_Integrate(old, bv_ball.velocity, bv_ball_spin, dt);
    position = bv_step_position;
    launch_velocity = bv_step_velocity;
    spin = bv_step_spin;
    if (old_x * position_x < 0)
    {
        fraction = fabs(old_x) / (fabs(old_x) + fabs(position_x));
        if (old_z + (position_z - old_z) * fraction < 43 - BV_RADIUS)
            bv_under_net = TRUE;
    }
    if (BV_NetSweep(old, position))
    {
        position = bv_net_position;
        position_x = position_x + (old_x - position_x) * 0.001;
        launch_velocity_x = -launch_velocity_x * 0.22;
        launch_velocity_y = launch_velocity_y * 0.65;
        launch_velocity_z = launch_velocity_z * 0.65;
        spin = spin * 0.4;
        bv_net_touched = TRUE;
        sound(bv_ball, 1, "beach/net.wav", 0.7, 1);
    }
    /* The BSP handles posts and surroundings; the playing surface gets an
     * exact sphere-ground crossing below. Point hull avoids Quake's fixed
     * player-sized tracebox hulls for this small ball.
     */
    traceline(old, position, TRUE, bv_ball);
    if (trace_fraction < 1 && trace_plane_normal_z < 0.5)
    {
        position = trace_endpos + trace_plane_normal * BV_RADIUS;
        launch_velocity = launch_velocity - trace_plane_normal * (launch_velocity * trace_plane_normal) * 1.3;
        spin = spin * 0.4;
    }
    /* Contact only before the first floor crossing; a released shot cannot
     * rescue a ball after it has already landed.
     */
    if (position_z <= BV_RADIUS)
    {
        fraction = BV_Clamp((old_z - BV_RADIUS) / (old_z - position_z), 0, 1);
        position = old + (position - old) * fraction;
        position_z = BV_RADIUS;
        if (BV_TryContacts(old, position)) return;
        BV_FinishRally(position);
        return;
    }
    if (BV_TryContacts(old, position)) return;
    setorigin(bv_ball, position);
    bv_ball.velocity = launch_velocity;
    bv_ball_spin = spin;
    bv_ball.angles = bv_ball.angles + spin * (dt * 180 / BV_PI);
    if (fabs(position_x) > 1100 || fabs(position_y) > 1100 || position_z > 1200)
        BV_FinishRally(position);
};

void() BV_UpdateBall =
{
    local vector heading;
    if (bv_ball_state == BV_HELD && bv_holder != world)
    {
        heading = BV_Heading(bv_holder.v_angle_y);
        setorigin(bv_ball, bv_holder.origin + heading * 30 + '0 0 18');
    }
    /* Retain fractional time, so changing rendering/server frame rates does
     * not change the ball flight. Cap backlog after a pause.
     */
    bv_accumulator = bv_accumulator + BV_Clamp(frametime, 0, 0.25);
    while (bv_accumulator >= BV_STEP)
    {
        BV_BallStep(BV_STEP);
        bv_accumulator = bv_accumulator - BV_STEP;
    }
    if (bv_next_feed > 0 && time >= bv_next_feed && bv_feeder != world)
    {
        bv_next_feed = 0;
        BV_Feed(bv_feeder);
    }
    bv_ball_position = bv_ball.origin;
};
