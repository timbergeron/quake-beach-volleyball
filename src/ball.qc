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
.float bv_preview_result, bv_preview_range, bv_preview_height;
.float bv_feedback_at, bv_feedback_age, bv_in_reach, bv_feed_delay;
.float bv_depth, bv_footing, bv_contact_note, bv_timing;
.vector bv_preview_landing;
.vector bv_aim;
.entity bv_marker;
.string bv_message;
.float button3, button4, button5, button6, button7, button8;
.float gravity;
.float bv_isbot, bv_assisted, bv_overlays, bv_recover_until, bv_recovery;
.float bv_plan_kind, bv_plan_next, bv_jump_ready;
.vector bv_goal, bv_shot_target;
.float bv_shot_apex;
.float bv_match_hint;
.float bv_contact_latched, bv_latch_radius;
.vector bv_latch_offset, bv_dive_direction;
.float bv_serve_style, bv_float_seed, bv_receive_contact, bv_receiving;
.float bv_receive_committed, bv_release_timing, bv_release_error;
.vector bv_read_direction;
.float bv_anim_clip, bv_anim_started, bv_anim_next, bv_anim_phase;
.float bv_anim_air, bv_anim_air_started;
.float bv_anim_cut;
.vector bv_swing_aim;

entity bv_match_owner, bv_partner, bv_opponent1, bv_opponent2, bv_server;
float bv_match, bv_home_score, bv_away_score, bv_match_phase;
float bv_serving_team, bv_touch_team, bv_touches, bv_serve_pending;
float bv_match_next, bv_match_goal;
float bv_point_reason;
entity bv_touch_actor;
vector bv_partner_position, bv_opponent1_position, bv_opponent2_position;
entity bv_shadow;

void(entity player) BV_StartMatch;
void() BV_StopMatch;
void(vector position) BV_MatchLanding;
float(entity player, vector point) BV_MatchEligible;
float(entity player) BV_MatchContact;
float(entity player) BV_Team;
void(entity player, vector contact) BV_BotBuildShot;
void() BV_UpdateMatch;
void(entity player) BV_Animate;
void(entity player) BV_ResetAnimation;
void(entity player) BV_RunAnimationTests;
void() BV_MatchTestInput;
void() BV_MatchTestObserve;

entity bv_ball, bv_holder, bv_last_player, bv_feeder;
vector bv_ball_spin;
float bv_ball_state, bv_accumulator, bv_next_feed, bv_net_touched, bv_under_net;
float bv_antenna_touched;
float bv_live_time;
float bv_ball_float, bv_ball_phase;
vector bv_ball_position;

void(entity player, vector contact) BV_Contact;
void(entity player, float automatic) BV_Feed;
float(entity player) BV_Charge;
float(entity player) BV_ServeTiming;
float(entity player) BV_IsReceiving;
void(vector point, vector incoming) BV_NetImpact;

float(vector position) BV_InCourt =
{
    return fabs(position_x) <= BV_HALF_LENGTH + BV_RADIUS &&
           fabs(position_y) <= BV_HALF_WIDTH + BV_RADIUS;
};

/* Six practice zones per side, shown on the overhead HUD. Keep these bounds
 * matched to BV_MapTargets so placement scoring has a visible reference.
 */
float(vector position) BV_OnTarget =
{
    local float x, y;
    x = fabs(position_x);
    y = fabs(position_y);
    return (fabs(x - 80) <= 28 || fabs(x - 208) <= 28) &&
           (y <= 26 || fabs(y - 92) <= 26);
};

float(vector position, float side, float net, float under) BV_LandingResult =
{
    if (under) return BV_RESULT_UNDER;
    if (!BV_InCourt(position)) return BV_RESULT_OUT;
    if (position_x * side >= 0)
    {
        if (net) return BV_RESULT_NET;
        return BV_RESULT_OWN;
    }
    if (BV_OnTarget(position)) return BV_RESULT_TARGET;
    return BV_RESULT_IN;
};

float(vector position, float side, float net, float under, float antenna,
      float duration) BV_AttemptResult =
{
    if (antenna) return BV_RESULT_ANTENNA;
    /* Expiring in midair is a miss, even above an opponent target. Keep
     * this classification shared by live scoring and the training preview.
     */
    if (duration >= BV_MAX_FLIGHT && !under)
    {
        if (net) return BV_RESULT_NET;
        return BV_RESULT_OUT;
    }
    return BV_LandingResult(position, side, net, under);
};

void(vector position) BV_FinishRally =
{
    bv_ball_state = BV_DEAD;
    bv_ball.velocity = '0 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_float = 0;
    setorigin(bv_ball, position);
    if (bv_match)
    {
        BV_MatchLanding(position);
        return;
    }
    if (bv_last_player != world)
    {
        bv_last_player.bv_attempts = bv_last_player.bv_attempts + 1;
        bv_last_player.bv_feedback_at = time;
        bv_last_player.bv_last_result = BV_AttemptResult(position,
            bv_last_player.bv_contact_side, bv_net_touched, bv_under_net,
            bv_antenna_touched, bv_live_time);
        if (bv_last_player.bv_last_result == BV_RESULT_ANTENNA)
        {
            bv_last_player.bv_message = "ANTENNA - keep the ball inside the rods";
        }
        else if (bv_last_player.bv_last_result == BV_RESULT_UNDER)
        {
            bv_last_player.bv_message = "UNDER NET";
        }
        else if (bv_last_player.bv_last_result == BV_RESULT_OUT)
        {
            bv_last_player.bv_message = "OUT - reduce power or change arc";
        }
        else if (bv_last_player.bv_last_result == BV_RESULT_OWN ||
                 bv_last_player.bv_last_result == BV_RESULT_NET)
        {
            if (bv_net_touched)
                bv_last_player.bv_message = "NET - give the ball more clearance";
            else
                bv_last_player.bv_message = "OWN COURT - prepare the next contact";
        }
        else if (bv_last_player.bv_last_result == BV_RESULT_TARGET)
        {
            bv_last_player.bv_targets = bv_last_player.bv_targets + 1;
            bv_last_player.bv_message = "TARGET HIT";
            sound(bv_ball, 1, "beach/target.wav", 0.7, 1);
        }
        else
        {
            bv_last_player.bv_message = "IN - try placing the next shot on a target";
        }
    }
    if (bv_feeder != world && bv_feeder.bv_mode > 0)
        bv_next_feed = time + 1.35;
};

vector bv_hand_position;
float bv_hand_radius;

void(entity player, vector ball) BV_ContactZone =
{
    local float height;
    height = 20;
    bv_hand_radius = 25 + BV_RADIUS;
    if (player.bv_action == 2) height = 45;
    if (player.bv_action == 1 && !BV_IsReceiving(player) && ball_z > player.origin_z + 36 &&
        (!bv_match || player.bv_match_hint != BV_HINT_RECEIVE) &&
        (!player.bv_isbot || player.bv_plan_kind != BV_PASS))
    {
        height = 53;
        bv_hand_radius = 30 + BV_RADIUS;
    }
    if (player.bv_serve_contact)
    {
        /* The extended serving hand meets the ball near the toss apex. */
        height = 71;
        if (player.bv_serve_style == BV_TOPSPIN_SERVE && !(player.flags & FL_ONGROUND))
            height = 53;
        bv_hand_radius = 23 + BV_RADIUS;
    }
    if (player.bv_dive_until > time)
    {
        height = 2;
        bv_hand_radius = 32 + BV_RADIUS;
    }
    bv_hand_position = player.origin + BV_Heading(player.v_angle_y) * 17 +
                       '0 0 1' * height;
};

/* A slow ball can remain in the hands after a recovery timer expires.
 * Release the latch only after separation from the original contact volume;
 * changing shot buttons or poses cannot manufacture a second touch.
 */
void(entity player, vector point) BV_UpdateContactLatch =
{
    if (player.bv_contact_latched &&
        vlen(point - player.origin - player.bv_latch_offset) > player.bv_latch_radius + 2)
        player.bv_contact_latched = FALSE;
};

void() BV_ClearContactLatches =
{
    local entity player;
    player = find(world, classname, "player");
    while (player != world)
    {
        player.bv_contact_latched = FALSE;
        player = find(player, classname, "player");
    }
};

/* The timing cue and actual contact share both reach and obstruction checks. */
float(entity player, vector point) BV_Reachable =
{
    if (vlen(point - bv_hand_position) > bv_hand_radius) return FALSE;
    traceline(bv_hand_position, point, TRUE, player);
    if (trace_fraction != 1) return FALSE;
    if (bv_hand_position_x * point_x < 0 &&
        fabs(point_y) < BV_NET_HALF_LENGTH &&
        point_z < BV_NET_HEIGHT + BV_RADIUS) return FALSE;
    // The visible equipment has no BSP hull for balls or hands. Use the same
    // swept volumes so the cue, manual release and assisted hits cannot reach
    // through padding, net wings or rods.
    return !BV_EquipmentSweepRadius(bv_hand_position, point, 0);
};

/* Release arms a short contact window. A fast ball crossing the hands
 * between frames can still be hit, but cannot be hit across the court.
 */
float(vector start, vector finish) BV_TryContacts =
{
    local entity player;
    local vector closest;
    local float ready, radius;
    player = find(world, classname, "player");
    while (player != world)
    {
        BV_UpdateContactLatch(player, start);
        ready = FALSE;
        if (player.bv_armed_until >= time && player.bv_armed_until > 0)
            ready = TRUE;
        if (player.bv_assisted && player.bv_preparing &&
            time - player.bv_prepare_started >= 0.12)
            ready = TRUE;
        if (player.bv_serve_contact && player.bv_preparing &&
            BV_ServeTiming(player) < 0.92) ready = FALSE;
        if (player.bv_isplayer && ready && !player.bv_contact_latched &&
            time >= player.bv_recover_until &&
            time - player.bv_last_contact > 0.22)
        {
            BV_ContactZone(player, start);
            closest = BV_ClosestPoint(start, finish, bv_hand_position);
            radius = bv_hand_radius;
            if (player.bv_preparing) bv_hand_radius = radius * 0.45;
            if (BV_Reachable(player, closest) && BV_MatchEligible(player, closest))
            {
                if (player.bv_preparing) player.bv_charge = BV_Charge(player);
                BV_Contact(player, closest);
                return TRUE;
            }
        }
        player = find(player, classname, "player");
    }
    return FALSE;
};

void(float dt) BV_BallStep =
{
    local vector old, position, launch_velocity, spin, impact, normal;
    local float fraction, event;
    if (bv_ball_state != BV_LIVE) return;
    bv_live_time = bv_live_time + dt;
    if (bv_live_time > BV_MAX_FLIGHT)
    {
        /* A ball balanced on the tape must not stall an automatic drill. */
        BV_FinishRally(bv_ball.origin);
        return;
    }
    old = bv_ball.origin;
    BV_IntegrateFlight(old, bv_ball.velocity, bv_ball_spin, dt, bv_ball_float, bv_ball_phase);
    bv_ball_phase = bv_step_phase;
    position = bv_step_position;
    launch_velocity = bv_step_velocity;
    spin = bv_step_spin;
    impact = position;
    fraction = 1;
    event = 0;
    normal = '0 0 0';
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
    /* Point traces avoid Quake's fixed player-sized hulls. Include raised
     * horizontal surfaces as well as post sides; the sand event is earlier
     * than its point trace because it already accounts for the ball radius.
     */
    traceline(old, position, TRUE, bv_ball);
    if (!trace_startsolid && trace_fraction < fraction)
    {
        event = 3;
        impact = trace_endpos + trace_plane_normal * BV_RADIUS;
        normal = trace_plane_normal;
    }
    /* A hand contact before an obstacle consumes the shot without recording
     * a future net/floor event. Never search beyond the first obstacle.
     */
    if (BV_TryContacts(old, impact)) return;
    if (BV_UnderNetSweep(old, impact))
    {
        bv_under_net = TRUE;
        if (bv_match)
        {
            BV_FinishRally(impact);
            return;
        }
    }
    position = impact;
    if (event == 5)
    {
        bv_antenna_touched = TRUE;
        sound(bv_ball, 1, "beach/net.wav", 0.7, 1);
        BV_FinishRally(position);
        return;
    }
    if (event == 1)
    {
        BV_FinishRally(position);
        return;
    }
    if (event == 2)
    {
        BV_NetImpact(position, launch_velocity);
        position = position + normal * 0.01;
        launch_velocity = BV_Reflect(launch_velocity, normal, 0.22, 0.65);
        spin = spin * 0.4;
        bv_ball_float = bv_ball_float * 0.4;
        bv_net_touched = TRUE;
        sound(bv_ball, 1, "beach/net.wav", 0.7, 1);
    }
    if (event == 3 || event == 4)
    {
        position = position + normal * 0.01;
        launch_velocity = BV_Reflect(launch_velocity, normal, 0.3, 1);
        spin = spin * 0.4;
        bv_ball_float = bv_ball_float * 0.4;
    }
    setorigin(bv_ball, position);
    bv_ball.velocity = launch_velocity;
    bv_ball_spin = spin;
    BV_AdvanceBallRotation(spin, dt);
    bv_ball.angles = bv_draw_angles;
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
        BV_Feed(bv_feeder, TRUE);
    }
    bv_ball_position = bv_ball.origin;
    if (bv_shadow != world)
    {
        if (bv_ball.origin_z > BV_RADIUS && BV_InCourt(bv_ball.origin))
        {
            setmodel(bv_shadow, "progs/bv_shadow.mdl");
            setorigin(bv_shadow, '0 0 0.5' +
                '1 0 0' * bv_ball.origin_x + '0 1 0' * bv_ball.origin_y);
        }
        else bv_shadow.modelindex = 0;
    }
};
