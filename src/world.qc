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
    clientstat(32, 2, bv_arc);
    clientstat(33, 2, bv_sidespin);
    clientstat(34, 2, bv_charge);
    clientstat(35, 2, bv_kind);
    clientstat(36, 2, bv_state);
    clientstat(37, 2, bv_last_speed);
    clientstat(38, 2, bv_quality);
    clientstat(39, 2, bv_targets);
    clientstat(40, 2, bv_attempts);
    clientstat(41, 2, bv_mode);
    clientstat(42, 2, bv_topspin);
    clientstat(43, 2, bv_aim_locked);
    clientstat(45, 2, bv_last_result);
    globalstat(48, 3, "bv_ball_position");
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
