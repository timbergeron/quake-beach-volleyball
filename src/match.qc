// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
var float autocvar_bv_match_points = 7;
entity(vector position, float side) BV_SpawnBot;
void() BV_UpdateBots;

float(entity actor) BV_Team =
{
    if (actor == bv_match_owner || actor == bv_partner) return -1;
    return 1;
};

void() BV_StopMatch =
{
    if (!bv_match) return;
    bv_match = FALSE;
    bv_match_phase = 0;
    bv_next_feed = 0;
    bv_holder = world;
    bv_last_player = world;
    bv_feeder = world;
    bv_touch_actor = world;
    bv_server = world;
    bv_ball_state = BV_IDLE;
    bv_ball.velocity = '0 0 0';
    if (bv_partner != world) remove(bv_partner);
    if (bv_opponent1 != world) remove(bv_opponent1);
    if (bv_opponent2 != world) remove(bv_opponent2);
    bv_partner = world;
    bv_opponent1 = world;
    bv_opponent2 = world;
    bv_match_owner.bv_preparing = 0;
    bv_match_owner.bv_armed_until = 0;
    bv_match_owner.bv_match_hint = 0;
    bv_match_owner.bv_contact_latched = FALSE;
    bv_match_owner = world;
};

void(entity actor, vector position) BV_ResetActor =
{
    setorigin(actor, position);
    actor.velocity = '0 0 0';
    actor.flags = actor.flags | FL_ONGROUND;
    actor.bv_preparing = 0;
    actor.bv_armed_until = 0;
    actor.bv_serve_contact = 0;
    actor.bv_charge = 0;
    actor.bv_last_contact = -1;
    actor.bv_recover_until = 0;
    actor.bv_dive_until = 0;
    actor.bv_dive_ready = 0;
    actor.bv_jump_ready = 0;
    actor.bv_contact_latched = FALSE;
    actor.bv_receive_contact = FALSE;
    actor.bv_receive_committed = FALSE;
    actor.bv_receiving = FALSE;
    actor.bv_footing = 1;
    actor.bv_aim_locked = 0;
    actor.bv_plan_next = 0;
    BV_ResetAnimation(actor);
};

void() BV_MatchServe =
{
    BV_ResetActor(bv_match_owner, '-185 -58 24');
    BV_ResetActor(bv_partner, '-78 58 24');
    BV_ResetActor(bv_opponent1, '78 -58 24');
    BV_ResetActor(bv_opponent2, '185 58 24');
    bv_match_owner.v_angle = '0 0 0';
    bv_match_owner.angles = '0 0 0';
    bv_match_owner.fixangle = TRUE;
    bv_server = bv_opponent2;
    if (bv_serving_team < 0) bv_server = bv_match_owner;
    if (bv_server.bv_isbot)
    {
        bv_server.bv_serve_style = BV_FLOAT_SERVE;
        if (bv_home_score + bv_away_score != floor((bv_home_score + bv_away_score) / 2) * 2)
            bv_server.bv_serve_style = BV_TOPSPIN_SERVE;
    }
    BV_ReadyServe(bv_server);
    bv_feeder = world;
    bv_server.bv_plan_next = time + 0.7;
    bv_server.bv_plan_kind = BV_SERVE;
    bv_server.bv_shot_target = '-185 -58 44';
    bv_server.bv_shot_apex = 145;
    bv_match_phase = BV_MATCH_SERVE;
    bv_touch_team = 0;
    bv_touches = 0;
    bv_touch_actor = world;
    bv_serve_pending = FALSE;
};

void(entity player) BV_StartMatch =
{
    BV_StopMatch();
    bv_match_owner = player;
    bv_match = TRUE;
    bv_home_score = 0;
    bv_away_score = 0;
    bv_match_goal = BV_Clamp(floor(autocvar_bv_match_points), 3, 21);
    // Keep the player's contact preference when starting a new session.
    // New players start with manual contact in PutClientInServer.
    player.bv_mode = 0;
    player.bv_marker.modelindex = 0;
    bv_partner = BV_SpawnBot('-78 58 24', -1);
    bv_opponent1 = BV_SpawnBot('78 -58 24', 1);
    bv_opponent2 = BV_SpawnBot('185 58 24', 1);
    bv_serving_team = 1;
    BV_MatchServe();
    bprint("Beach doubles: first to ", ftos(bv_match_goal), ", win by two.\n");
};

void(float winner, string reason) BV_MatchPoint =
{
    if (bv_match_phase >= BV_MATCH_POINT) return;
    bv_ball_state = BV_DEAD;
    bv_ball.velocity = '0 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_float = 0;
    bv_holder = world;
    if (winner < 0) bv_home_score = bv_home_score + 1;
    else bv_away_score = bv_away_score + 1;
    bv_serving_team = winner;
    bv_match_phase = BV_MATCH_POINT;
    bv_match_next = time + 2;
    bv_match_owner.bv_message = reason;
    bv_point_reason = BV_RESULT_IN;
    if (reason == "OUT") bv_point_reason = BV_RESULT_OUT;
    if (reason == "UNDER NET") bv_point_reason = BV_RESULT_UNDER;
    if (reason == "ANTENNA") bv_point_reason = BV_RESULT_ANTENNA;
    if (reason == "DOUBLE CONTACT") bv_point_reason = BV_POINT_DOUBLE;
    if (reason == "FOUR TOUCHES") bv_point_reason = BV_POINT_FOUR;
    bprint("Point: ", reason, " | YOU ", ftos(bv_home_score), " - ",
        ftos(bv_away_score), " BOTS\n");
    if ((bv_home_score >= bv_match_goal || bv_away_score >= bv_match_goal) &&
        fabs(bv_home_score - bv_away_score) >= 2)
    {
        bv_match_phase = BV_MATCH_OVER;
        bprint("Match finished. Press 5 to play again, or 1-4 for practice.\n");
    }
};

void(vector position) BV_MatchLanding =
{
    local float winner;
    winner = -bv_touch_team;
    if (bv_touch_team == 0) winner = -bv_serving_team;
    if (bv_antenna_touched) BV_MatchPoint(winner, "ANTENNA");
    else if (!bv_under_net && bv_live_time < BV_MAX_FLIGHT && BV_InCourt(position))
    {
        winner = -1;
        if (position_x < 0) winner = 1;
        BV_MatchPoint(winner, "BALL DOWN");
    }
    else if (bv_under_net) BV_MatchPoint(winner, "UNDER NET");
    else BV_MatchPoint(winner, "OUT");
};

float(entity player, vector point) BV_MatchEligible =
{
    if (!bv_match) return TRUE;
    if (player != bv_match_owner && player != bv_partner &&
        player != bv_opponent1 && player != bv_opponent2) return FALSE;
    if (bv_match_phase >= BV_MATCH_POINT) return FALSE;
    if (bv_match_phase == BV_MATCH_SERVE) return player == bv_server;
    if (point_x * BV_Team(player) < -BV_RADIUS) return FALSE;
    if (bv_serve_pending && BV_Team(player) == bv_serving_team) return FALSE;
    return TRUE;
};

float(entity player) BV_MatchContact =
{
    local float side;
    if (!bv_match) return TRUE;
    side = BV_Team(player);
    if (bv_match_phase == BV_MATCH_SERVE)
    {
        bv_match_phase = BV_MATCH_RALLY;
        bv_serve_pending = TRUE;
    }
    else if (bv_touch_team == side)
    {
        if (bv_touch_actor == player)
        {
            BV_MatchPoint(-side, "DOUBLE CONTACT");
            return FALSE;
        }
        if (bv_touches >= 3)
        {
            BV_MatchPoint(-side, "FOUR TOUCHES");
            return FALSE;
        }
    }
    if (bv_touch_team != side) bv_touches = 0;
    bv_touches = bv_touches + 1;
    bv_touch_team = side;
    bv_touch_actor = player;
    /* The serve is not one of the receiving team's three touches. */
    if (bv_serve_pending) bv_touches = 0;
    return TRUE;
};

void() BV_UpdateMatch =
{
    if (!bv_match) return;
    if (bv_serve_pending && bv_ball.origin_x * bv_serving_team < -BV_RADIUS)
        bv_serve_pending = FALSE;
    if (bv_match_phase == BV_MATCH_POINT && time >= bv_match_next)
        BV_MatchServe();
    BV_UpdateBots();
    bv_partner_position = bv_partner.origin;
    bv_opponent1_position = bv_opponent1.origin;
    bv_opponent2_position = bv_opponent2.origin;
};
