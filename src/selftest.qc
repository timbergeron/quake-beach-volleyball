// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Runs inside the actual QSS-M QC VM via +set bv_selftest 1. */
float bv_test_pass, bv_test_fail;

void(string name, float condition) BV_Assert =
{
    if (condition)
    {
        bv_test_pass = bv_test_pass + 1;
        dprint("BEACH PASS ", name, "\n");
    }
    else
    {
        bv_test_fail = bv_test_fail + 1;
        dprint("BEACH FAIL ", name, "\n");
    }
};

void() BV_RunSelfTests =
{
    local entity player, saved_self;
    local vector landing, launch_velocity, position, other_position, aim_direction;
    local float low_apex, low_range, saved_time, i, saved_drag, saved_magnus;
    bv_test_pass = 0;
    bv_test_fail = 0;
    saved_self = self;
    saved_time = time;
    saved_drag = autocvar_bv_drag;
    saved_magnus = autocvar_bv_magnus;
    time = 10;
    player = spawn();
    self = player;
    PutClientInServer();
    player.flags = player.flags | FL_ONGROUND;
    player.bv_aim = '1 0 0';
    player.bv_action = 1;
    player.bv_charge = 0.4;
    player.bv_arc = 0.35;
    player.bv_sidespin = 0;
    player.bv_topspin = 0;
    player.bv_serve_contact = TRUE;
    BV_BuildShot(player, '-270 0 80');
    launch_velocity = bv_shot_velocity;
    BV_Assert("serve-technique", bv_shot_kind == BV_SERVE);
    player.bv_charge = 0.85;
    BV_BuildShot(player, '-270 0 80');
    BV_Assert("serve-variable-speed", vlen(bv_shot_velocity) > vlen(launch_velocity) + 100);
    player.bv_arc = 0.05;
    BV_BuildShot(player, '-270 0 80');
    low_apex = bv_shot_velocity_z;
    player.bv_arc = 0.8;
    BV_BuildShot(player, '-270 0 80');
    BV_Assert("serve-variable-arc", bv_shot_velocity_z > low_apex + 100);
    player.bv_serve_contact = FALSE;
    player.bv_action = 2;
    player.bv_arc = 0.1;
    BV_BuildShot(player, '-270 0 65');
    BV_Assert("set-technique-after-serve", bv_shot_kind == BV_SET &&
              bv_shot_velocity_x < 150 && bv_shot_velocity_z > 200);
    low_apex = bv_shot_velocity_z;
    player.bv_arc = 0.9;
    BV_BuildShot(player, '-270 0 65');
    BV_Assert("set-height-control", bv_shot_velocity_z > low_apex + 80);
    player.flags = player.flags - (player.flags & FL_ONGROUND);
    BV_BuildShot(player, '-270 0 115');
    BV_Assert("airborne-roll-technique", bv_shot_kind == BV_ROLL);
    player.bv_action = 1;
    player.bv_arc = 0.1;
    BV_BuildShot(player, '-270 0 115');
    BV_Assert("downward-spike", bv_shot_kind == BV_SPIKE && bv_shot_velocity_z < 0);
    player.flags = player.flags | FL_ONGROUND;
    player.bv_arc = 0.35;
    BV_BuildShot(player, '-270 0 44');
    BV_Assert("forearm-pass-after-spike", bv_shot_kind == BV_PASS &&
              bv_shot_velocity_z > 0 && bv_shot_velocity_x < 250);
    player.bv_sidespin = 1;
    BV_BuildShot(player, '-270 0 44');
    BV_Integrate('-270 0 44', bv_shot_velocity, bv_shot_spin, BV_STEP);
    BV_Assert("sidespin-control-direction", bv_step_velocity_y < 0);
    player.bv_sidespin = 0;

    BV_Predict('-600 0 100', '200 0 180', '0 0 20');
    landing = bv_landing;
    BV_Predict('-600 0 100', '200 0 180', '0 0 -20');
    BV_Assert("opposite-sidespin-curves", landing_y > 5 && bv_landing_y < -5);
    BV_Assert("spin-mirror-symmetry", fabs(landing_y + bv_landing_y) < 0.02);
    BV_Predict('-600 0 100', '200 0 180', '0 0 0');
    low_range = bv_landing_x;
    BV_Predict('-600 0 100', '200 0 180', '0 24 0');
    BV_Assert("topspin-shortens-flight", bv_landing_x < low_range - 5);
    BV_Assert("ground-crossing-at-ball-radius", fabs(bv_landing_z - BV_RADIUS) < 0.001);
    BV_Predict('-600 0 100', '200 0 180', '0 0 0');
    landing = bv_landing;
    BV_Predict('-600 0 100', '200 0 180', '0 0 0');
    BV_Assert("prediction-repeatability", vlen(landing - bv_landing) < 0.001);
    BV_Assert("net-high-speed-sweep", BV_NetSweep('-100 0 60', '100 0 60'));
    BV_Assert("net-crossing-location", fabs(bv_net_position_x + BV_RADIUS + 0.65) < 0.01);
    BV_Assert("net-opposite-side-sweep", BV_NetSweep('100 0 60', '-100 0 60'));
    BV_Assert("clear-net-above-tape", !BV_NetSweep('-100 0 100', '100 0 100'));
    BV_Assert("clear-net-outside-width", !BV_NetSweep('-100 150 60', '100 150 60'));
    BV_Assert("in-court-boundary-radius", BV_InCourt('259 0 3.4'));
    BV_Assert("out-of-court", !BV_InCourt('262 0 3.4'));
    BV_Assert("target-region", BV_OnTarget('208 92 3.4'));
    BV_Assert("between-targets", !BV_OnTarget('144 40 3.4'));

    player.v_angle = '0 15 0';
    BV_BeginPreparation(player, 1);
    aim_direction = player.bv_aim;
    player.v_angle = '-65 100 0';
    player.button0 = 1;
    player.bv_previous_primary = 1;
    self = player;
    PlayerPreThink();
    BV_Assert("free-look-preserves-aim", vlen(player.bv_aim - aim_direction) < 0.001);
    player.button8 = 1;
    PlayerPreThink();
    BV_Assert("wrist-away-reaim", vlen(player.bv_aim - BV_Heading(100)) < 0.001);
    player.button8 = 0;
    player.button0 = 0;
    time = time + 0.4;
    PlayerPreThink();
    BV_Assert("release-arms-contact-window", player.bv_armed_until > time &&
              player.bv_preparing == 0);
    player.v_angle = '0 0 0';
    player.bv_aim = '1 0 0';
    player.bv_action = 1;
    player.bv_last_contact = -1;
    BV_Assert("swept-hand-contact", BV_TryContacts('-340 0 44', '-240 0 44'));
    BV_Assert("contact-consumes-release", player.bv_armed_until == 0);
    BV_Assert("no-double-contact", !BV_TryContacts('-340 0 44', '-240 0 44'));
    player.bv_armed_until = time + 0.18;
    player.bv_last_contact = -1;
    BV_Assert("no-remote-contact", !BV_TryContacts('150 0 44', '200 0 44'));
    time = time + 0.2;
    PlayerPreThink();
    BV_Assert("expired-release-is-miss", player.bv_armed_until == 0);

    player.button2 = 1;
    player.bv_previous_jump = 0;
    player.flags = player.flags | FL_ONGROUND;
    PlayerPreThink();
    BV_Assert("athletic-jump", player.velocity_z > 190 && !(player.flags & FL_ONGROUND));
    player.flags = player.flags | FL_ONGROUND;
    player.velocity = '0 0 0';
    PlayerPreThink();
    BV_Assert("holding-jump-does-not-autohop", player.velocity_z == 0);
    player.button2 = 0;
    player.button7 = 1;
    player.bv_previous_dive = 0;
    PlayerPreThink();
    BV_Assert("dive-and-recovery", player.bv_dive_until > time &&
              player.bv_dive_ready > player.bv_dive_until && player.view_ofs_z == 5);
    player.button7 = 0;
    player.bv_dive_until = 0;
    player.bv_armed_until = 0;

    /* Fixed-step accumulator must give the same flight at 20 and 60 Hz. */
    bv_feeder = world;
    bv_next_feed = 0;
    setorigin(bv_ball, '-600 0 180');
    bv_ball.velocity = '150 0 100';
    bv_ball_spin = '0 0 15';
    bv_ball_state = BV_LIVE;
    bv_accumulator = 0;
    i = 0;
    while (i < 20)
    {
        frametime = 0.05;
        BV_UpdateBall();
        i = i + 1;
    }
    position = bv_ball.origin;
    setorigin(bv_ball, '-600 0 180');
    bv_ball.velocity = '150 0 100';
    bv_ball_spin = '0 0 15';
    bv_ball_state = BV_LIVE;
    bv_accumulator = 0;
    i = 0;
    while (i < 60)
    {
        frametime = 0.016666667;
        BV_UpdateBall();
        i = i + 1;
    }
    other_position = bv_ball.origin;
    BV_Assert("frame-rate-independent-ball", vlen(position - other_position) < 2);
    BV_Predict('-600 0 140', '170 0 100', '0 0 10');
    landing = bv_landing;
    setorigin(bv_ball, '-600 0 140');
    bv_ball.velocity = '170 0 100';
    bv_ball_spin = '0 0 10';
    bv_ball_state = BV_LIVE;
    i = 0;
    while (bv_ball_state == BV_LIVE && i < 1000)
    {
        BV_BallStep(BV_STEP);
        i = i + 1;
    }
    BV_Assert("preview-matches-live-landing", vlen(landing - bv_ball.origin) < 0.1);
    BV_Assert("live-ball-stops-on-sand", bv_ball_state == BV_DEAD &&
              bv_ball.velocity == '0 0 0');
    setorigin(bv_ball, '-30 0 60');
    bv_ball.velocity = '700 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_state = BV_LIVE;
    i = 0;
    while (i < 12)
    {
        BV_BallStep(BV_STEP);
        i = i + 1;
    }
    BV_Assert("live-net-no-tunnelling", bv_ball.origin_x < 0 && bv_ball.velocity_x < 0);

    BV_ReadyServe(player);
    BV_Assert("serve-reset-state", bv_ball_state == BV_HELD && bv_holder == player);
    player.v_angle = '0 0 0';
    BV_BeginPreparation(player, 1);
    BV_Assert("serve-toss", bv_ball_state == BV_LIVE && bv_ball.velocity_z == 140 &&
              player.bv_serve_contact);
    player.bv_mode = 1;
    BV_Feed(player);
    BV_Assert("receive-feeder", bv_ball_state == BV_LIVE && bv_ball.origin_x > 0 &&
              bv_ball.velocity_x < 0);
    player.bv_mode = 2;
    BV_Feed(player);
    BV_Assert("setting-feeder", bv_ball.origin_z == 195);
    player.bv_preparing = 0;
    player.bv_armed_until = 0;
    bv_last_player = player;
    bv_feeder = player;
    BV_FinishRally('208 92 3.4');
    BV_Assert("target-scoring", player.bv_targets == 1 &&
              player.bv_last_result == 1 && bv_next_feed > time);
    BV_FinishRally('280 0 3.4');
    BV_Assert("out-scoring", player.bv_last_result == 3);
    bv_under_net = TRUE;
    BV_FinishRally('208 92 3.4');
    BV_Assert("under-net-is-a-fault", player.bv_last_result == 6 && player.bv_targets == 1);
    bv_under_net = FALSE;
    player.bv_contact_side = -1;
    setorigin(player, '50 0 24');
    BV_FinishRally('208 92 3.4');
    BV_Assert("scoring-uses-contact-side", player.bv_last_result == 1);
    self = player;
    ClientDisconnect();
    remove(player);
    self = saved_self;
    time = saved_time;
    autocvar_bv_drag = saved_drag;
    autocvar_bv_magnus = saved_magnus;
    dprint("BEACH DONE pass=", ftos(bv_test_pass), " fail=", ftos(bv_test_fail), "\n");
};
