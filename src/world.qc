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
    precache_model("progs/bv_ball.mdl");
    precache_model("progs/bv_marker.mdl");
    precache_model("progs/player.mdl");
    precache_sound("beach/hit.wav");
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
    bv_ball = spawn();
    bv_ball.classname = "volleyball";
    bv_ball.movetype = MOVETYPE_NONE;
    bv_ball.solid = SOLID_NOT;
    setmodel(bv_ball, "progs/bv_ball.mdl");
    setsize(bv_ball, '-3.4 -3.4 -3.4', '3.4 3.4 3.4');
    setorigin(bv_ball, '-260 0 48');
    bv_ball_state = BV_IDLE;
    bv_holder = world;
    bv_last_player = world;
    bv_feeder = world;
    bv_tests_ran = FALSE;
    bv_accumulator = 0;
    bv_live_time = 0;
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
    BV_UpdateBall();
};
