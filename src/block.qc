// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* A block is a moving hand surface, not a charged attack. Contact remains on
 * the defender's side of the tape: a set/toss cannot be stolen across the net.
 * The existing 65 cm jump and authored block clips define its reach/window.
 */
void(entity player) BV_ResetBlock =
{
    player.bv_blocking = FALSE;
    player.bv_block_started = 0;
    player.bv_block_contacted = FALSE;
    player.bv_takeoff_at = 0;
    player.bv_defense_role = 0;
};

float(entity player) BV_CanBlock =
{
    local vector facing;
    if (!bv_match || bv_match_phase != BV_MATCH_RALLY || bv_ball_state != BV_LIVE)
        return FALSE;
    if (player != bv_match_owner && player != bv_partner &&
        player != bv_opponent1 && player != bv_opponent2) return FALSE;
    if (bv_touch_team == BV_Team(player) || !bv_touch_team || bv_serve_pending)
        return FALSE;
    if (bv_last_player == world) return FALSE;
    if (bv_last_player.bv_kind == BV_SERVE) return FALSE;
    facing = BV_Heading(player.v_angle_y);
    if (!player.bv_block_started && facing_x * BV_Team(player) > -0.35) return FALSE;
    if (player.origin_x * BV_Team(player) < 18 || fabs(player.origin_x) > 42 ||
        fabs(player.origin_y) > 115 || player.bv_dive_until > time ||
        player.bv_recover_until > time) return FALSE;
    return TRUE;
};

void(entity player) BV_BeginBlock =
{
    local vector normal;
    player.bv_blocking = TRUE;
    player.bv_preparing = 0;
    player.bv_armed_until = 0;
    player.bv_aim_locked = FALSE;
    player.bv_charge = 0;
    player.bv_timing = 0;
    player.bv_receive_committed = FALSE;
    if (!(player.flags & FL_ONGROUND) && !player.bv_block_started)
    {
        player.bv_block_started = player.bv_takeoff_at;
        // Late input cannot restart a jump's contact window.
        if (!player.bv_block_started) player.bv_block_started = time - 0.5;
        player.bv_block_lane = player.origin_y;
        normal = BV_Heading(player.v_angle_y);
        normal_x = -BV_Team(player);
        normal_y = BV_Clamp(normal_y, -0.28, 0.28);
        normal_z = 0.12;
        player.bv_block_normal = normalize(normal);
    }
};

float(entity player) BV_BlockInput =
{
    if (player.flags & FL_ONGROUND)
    {
        player.bv_block_started = 0;
        player.bv_block_contacted = FALSE;
    }
    if (!player.bv_menu_active && player.button3 && !player.button0 && BV_CanBlock(player))
    {
        BV_BeginBlock(player);
        return TRUE;
    }
    player.bv_blocking = FALSE;
    return FALSE;
};

/* Swept sphere against a thin pair-of-hands box. Future queries are used by
 * attack selection; they do not move actors, alter the ball or extend timers.
 * Hands span ~60 cm; above-tape body reach and an airborne player are required.
 */
float bv_block_fraction;
float bv_block_enter, bv_block_leave;
float(float start, float delta, float low, float high) BV_BlockSlab =
{
    local float a, b, swap;
    if (fabs(delta) < 0.00001) return start >= low && start <= high;
    a = (low - start) / delta;
    b = (high - start) / delta;
    if (a > b) { swap = a; a = b; b = swap; }
    if (a > bv_block_enter) bv_block_enter = a;
    if (b < bv_block_leave) bv_block_leave = b;
    return bv_block_enter <= bv_block_leave;
};

float(entity player, vector start, vector finish, float future) BV_BlockSweep =
{
    local vector center, low, high, delta, point;
    local float side, age, bottom, top;
    if (!player.bv_blocking || !player.bv_block_started || player.bv_block_contacted ||
        (player.flags & FL_ONGROUND)) return FALSE;
    age = time + future - player.bv_block_started;
    // Allow the authored arms to rise before enabling the hand surface.
    if (age < 0.18 || age > 0.50) return FALSE;
    side = BV_Team(player);
    if (fabs(player.origin_x) > 42) return FALSE;
    if ((finish_x - start_x) * side <= 0) return FALSE;
    center = player.origin;
    center_z = BV_Clamp(center_z + player.velocity_z * future -
        0.5 * BV_Clamp(autocvar_bv_gravity, 100, 800) * future * future, 24, 256);
    center_x = player.origin_x - side * 16;
    center_y = player.origin_y;
    bottom = center_z + 42;
    top = center_z + 54;
    if (top <= BV_NET_HEIGHT) return FALSE;
    low = center - '3 10 0' - '1 1 1' * BV_RADIUS;
    high = center + '3 10 0' + '1 1 1' * BV_RADIUS;
    low_z = bottom - BV_RADIUS;
    high_z = top + BV_RADIUS;
    if (side > 0) low_x = BV_Clamp(low_x, 0, 256);
    else high_x = BV_Clamp(high_x, -256, 0);
    delta = finish - start;
    bv_block_enter = 0; bv_block_leave = 1;
    if (!BV_BlockSlab(start_x, delta_x, low_x, high_x)) return FALSE;
    if (!BV_BlockSlab(start_y, delta_y, low_y, high_y)) return FALSE;
    if (!BV_BlockSlab(start_z, delta_z, low_z, high_z)) return FALSE;
    point = start + delta * bv_block_enter;
    if (point_x * side < 0) return FALSE;
    // The hand-to-ball path cannot pass through tape, posts or antennae.
    center_z = (bottom + top) * 0.5;
    if (BV_EquipmentSweepRadius(center, point, 0)) return FALSE;
    traceline(center, point, TRUE, player);
    if (trace_fraction != 1) return FALSE;
    bv_block_fraction = bv_block_enter;
    return TRUE;
};

float(vector start, vector finish) BV_FindBlock =
{
    local entity player;
    local float earliest;
    earliest = 2;
    bv_block_actor = world;
    player = find(world, classname, "player");
    while (player != world)
    {
        if (BV_CanBlock(player) && BV_BlockSweep(player, start, finish, 0))
        {
            if (bv_block_fraction < earliest)
            {
                earliest = bv_block_fraction;
                bv_block_actor = player;
            }
        }
        player = find(player, classname, "player");
    }
    if (bv_block_actor == world) return FALSE;
    bv_block_point = start + (finish - start) * earliest;
    return TRUE;
};

void(vector incoming) BV_BlockContact =
{
    local entity player;
    local vector outgoing;
    player = bv_block_actor;
    if (!BV_MatchContact(player)) return;
    bv_touch_was_block = TRUE;
    outgoing = BV_Reflect(incoming, player.bv_block_normal, 0.45, 0.8);
    setorigin(bv_ball, bv_block_point + player.bv_block_normal * 0.08);
    bv_ball.velocity = outgoing;
    bv_ball_spin = bv_ball_spin * 0.2;
    bv_ball_float = 0;
    bv_live_time = 0;
    bv_net_touched = bv_under_net = bv_antenna_touched = FALSE;
    bv_last_player = player;
    player.bv_block_contacted = TRUE;
    player.bv_contact_latched = TRUE;
    player.bv_latch_offset = bv_block_point - player.origin;
    player.bv_latch_radius = 20;
    player.bv_last_contact = time;
    player.bv_kind = BV_BLOCK;
    player.bv_last_speed = vlen(outgoing) / 32;
    player.bv_feedback_at = time;
    player.bv_last_result = 0;
    player.bv_message = "BLOCK - two touches left";
    player.bv_contact_note = BV_NOTE_CLEAN;
    player.bv_quality = 1;
    sound(bv_ball, 1, "beach/pass.wav", 0.8, 1);
};
