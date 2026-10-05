// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
void() BV_RunSelfTests;
float bv_tests_ran;

void() main = {};
void() info_player_start = {};
void() info_player_deathmatch = {};
void() light = {};

void() func_illusionary =
{
    self.movetype = MOVETYPE_NONE;
    self.solid = SOLID_NOT;
    setmodel(self, self.model);
    setorigin(self, self.origin);
};

void() worldspawn =
{
    local float style;
    style = 0;
    precache_model("progs/bv_ball.md3");
    precache_model("progs/bv_marker.mdl");
    precache_model("progs/bv_athlete.mdl");
    precache_model("progs/bv_hands.mdl");
    precache_model("progs/bv_shadow.mdl");
    precache_sound("beach/pass.wav");
    precache_sound("beach/set.wav");
    precache_sound("beach/spike.wav");
    precache_sound("beach/roll.wav");
    precache_sound("beach/serve.wav");
    precache_sound("beach/dig.wav");
    precache_sound("beach/sand.wav");
    cvar_set("sv_sound_land", "beach/sand.wav");
    precache_sound("beach/net.wav");
    precache_sound("beach/target.wav");
    precache_sound("beach/ocean.wav");
    while (style < 64)
    {
        lightstyle(style, "m");
        style = style + 1;
    }
    checkextension("EXT_CSQC");
    clientstat(BV_STAT_ARC, 2, bv_arc);
    clientstat(BV_STAT_SIDE, 2, bv_sidespin);
    clientstat(BV_STAT_CHARGE, 2, bv_charge);
    clientstat(BV_STAT_KIND, 2, bv_kind);
    clientstat(BV_STAT_STATE, 2, bv_state);
    clientstat(BV_STAT_SPEED, 2, bv_last_speed);
    clientstat(BV_STAT_QUALITY, 2, bv_quality);
    clientstat(BV_STAT_TARGETS, 2, bv_targets);
    clientstat(BV_STAT_ATTEMPTS, 2, bv_attempts);
    clientstat(BV_STAT_MODE, 2, bv_mode);
    clientstat(BV_STAT_TOP, 2, bv_topspin);
    clientstat(BV_STAT_AIM_LOCKED, 2, bv_aim_locked);
    clientstat(BV_STAT_RESULT, 2, bv_last_result);
    globalstat(BV_STAT_BALL, 3, "bv_ball_position");
    clientstat(BV_STAT_PLAYER, 3, origin);
    clientstat(BV_STAT_PREVIEW, 3, bv_preview_landing);
    clientstat(BV_STAT_PREVIEW_RESULT, 2, bv_preview_result);
    clientstat(BV_STAT_PREVIEW_RANGE, 2, bv_preview_range);
    clientstat(BV_STAT_PREVIEW_HEIGHT, 2, bv_preview_height);
    clientstat(BV_STAT_FEEDBACK_AGE, 2, bv_feedback_age);
    clientstat(BV_STAT_REACH, 2, bv_in_reach);
    clientstat(BV_STAT_FEED_DELAY, 2, bv_feed_delay);
    clientstat(BV_STAT_DEPTH, 2, bv_depth);
    clientstat(BV_STAT_CONTACT_NOTE, 2, bv_contact_note);
    clientstat(BV_STAT_TIMING, 2, bv_timing);
    clientstat(BV_STAT_SERVING, 2, bv_serve_contact);
    clientstat(BV_STAT_SERVE_STYLE, 2, bv_serve_style);
    clientstat(BV_STAT_RECEIVING, 2, bv_receiving);
    globalstat(BV_STAT_MATCH, 2, "bv_match");
    globalstat(BV_STAT_HOME_SCORE, 2, "bv_home_score");
    globalstat(BV_STAT_AWAY_SCORE, 2, "bv_away_score");
    globalstat(BV_STAT_TOUCHES, 2, "bv_touches");
    globalstat(BV_STAT_TOUCH_TEAM, 2, "bv_touch_team");
    globalstat(BV_STAT_PHASE, 2, "bv_match_phase");
    globalstat(BV_STAT_SERVE_TEAM, 2, "bv_serving_team");
    clientstat(BV_STAT_ASSISTED, 2, bv_assisted);
    clientstat(BV_STAT_OVERLAYS, 2, bv_overlays);
    clientstat(BV_STAT_RECOVERY, 2, bv_recover_until);
    clientstat(BV_STAT_HINT, 2, bv_match_hint);
    globalstat(BV_STAT_POINT_REASON, 2, "bv_point_reason");
    globalstat(BV_STAT_PARTNER, 3, "bv_partner_position");
    globalstat(BV_STAT_OPPONENT1, 3, "bv_opponent1_position");
    globalstat(BV_STAT_OPPONENT2, 3, "bv_opponent2_position");
    bv_ball = spawn();
    bv_ball.classname = "volleyball";
    bv_ball.movetype = MOVETYPE_NONE;
    bv_ball.solid = SOLID_NOT;
    setmodel(bv_ball, "progs/bv_ball.md3");
    setsize(bv_ball, '-3.4 -3.4 -3.4', '3.4 3.4 3.4');
    setorigin(bv_ball, '-260 0 48');
    bv_ball_state = BV_IDLE;
    bv_holder = world;
    bv_last_player = world;
    bv_feeder = world;
    bv_tests_ran = FALSE;
    bv_accumulator = 0;
    bv_live_time = 0;
    bv_shadow = spawn();
    bv_shadow.movetype = MOVETYPE_NONE;
    bv_shadow.solid = SOLID_NOT;
    bv_shadow.effects = BV_EF_NOSHADOW;
    setmodel(bv_shadow, "progs/bv_shadow.mdl");
    bv_shadow.modelindex = 0;
    ambientsound('0 480 32', "beach/ocean.wav", 0.18, 0);
};

void() StartFrame =
{
    if (cvar("bv_selftest") && !bv_tests_ran)
    {
        bv_tests_ran = TRUE;
        BV_RunSelfTests();
        localcmd("quit\n");
        return;
    }
    BV_UpdateMatch();
    BV_UpdateBall();
};
