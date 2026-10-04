// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Reproductions of input and collision failures found during the bug pass. */
void(entity player) BV_TestReset =
{
    setorigin(player, '-288 0 24');
    player.v_angle = '0 0 0';
    player.flags = player.flags | FL_ONGROUND;
    player.velocity = '0 0 0';
    player.button0 = 0;
    player.button3 = 0;
    player.button2 = 0;
    player.button7 = 0;
    player.bv_last_contact = -1;
    player.bv_dive_until = 0;
    player.bv_footing = 1;
    player.bv_depth = 0;
    BV_ReadyServe(player);
};

void(entity player) BV_RunBugTests =
{
    local float started, i, targets;
    BV_TestReset(player);
    player.bv_mode = 2;
    BV_Feed(player, FALSE);
    BV_FinishRally('-270 0 3.4');
    BV_BeginPreparation(player, 2);
    started = player.bv_prepare_started;
    time = time + 1.4;
    frametime = 0.01;
    BV_UpdateBall();
    BV_Assert("autofeed-keeps-early-preparation", player.bv_preparing == 2 &&
        player.bv_prepare_started == started && player.bv_aim_locked);
    player.button3 = 1;
    player.bv_previous_secondary = 1;
    self = player;
    PlayerPreThink();
    player.button3 = 0;
    PlayerPreThink();
    BV_Assert("autofeed-held-shot-can-release", player.bv_armed_until > time && player.bv_charge == 1);
    BV_Feed(player, FALSE);
    BV_Assert("manual-feed-clears-old-contact", player.bv_preparing == 0 && player.bv_armed_until == 0);

    BV_TestReset(player);
    player.bv_dive_until = time + 0.4;
    player.view_ofs_z = 5;
    player.bv_last_contact = time;
    BV_ReadyServe(player);
    BV_Assert("ready-serve-cancels-dive", player.bv_dive_until <= time && player.view_ofs_z == 27);
    BV_Assert("ready-serve-clears-contact-cooldown", player.bv_last_contact < time - 0.22);

    BV_TestReset(player);
    BV_Predict('-10 200 20', '500 0 0', '0 0 0');
    BV_Assert("outside-net-width-is-not-under-net", !bv_predict_under_net);
    setorigin(bv_ball, '-10 200 20');
    bv_ball.velocity = '500 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_state = BV_LIVE;
    bv_last_player = player;
    i = 0;
    while (bv_ball_state == BV_LIVE && i < 1000)
    {
        BV_BallStep(BV_STEP);
        i = i + 1;
    }
    BV_Assert("outside-net-width-scores-out", player.bv_last_result == BV_RESULT_OUT);

    BV_TestReset(player);
    BV_Predict('-3 0 3.5', '600 0 -100', '0 0 0');
    BV_Assert("floor-before-plane-preview", !bv_predict_under_net && bv_landing_x < 0);
    setorigin(bv_ball, '-3 0 3.5');
    bv_ball.velocity = '600 0 -100';
    bv_ball_spin = '0 0 0';
    bv_ball_state = BV_LIVE;
    bv_last_player = player;
    player.bv_contact_side = -1;
    BV_BallStep(0.01);
    BV_Assert("floor-before-plane-live", player.bv_last_result == BV_RESULT_OWN &&
        !bv_under_net && bv_ball.origin_x < 0);

    BV_TestReset(player);
    setorigin(player, '-25 0 24');
    player.bv_action = 1;
    player.bv_aim = '1 0 0';
    player.bv_charge = 0.4;
    player.bv_prepare_started = time - 0.4;
    player.bv_armed_until = time + 0.18;
    setorigin(bv_ball, '-35 0 60');
    bv_ball.velocity = '700 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_state = BV_LIVE;
    BV_BallStep(0.05);
    BV_Assert("hand-before-net-has-no-net-fault", player.bv_last_contact == time && !bv_net_touched);

    BV_TestReset(player);
    BV_Assert("falling-ball-hits-net-tape", BV_NetSweep('0 0 110', '0 0 60'));
    BV_Assert("net-overlap-cannot-tunnel", BV_NetSweep('2 0 60', '-2 0 59'));
    BV_Assert("net-overlap-can-move-away", !BV_NetSweep('2 0 60', '20 0 60'));
    setorigin(bv_ball, '0 0 110');
    bv_ball.velocity = '0 0 -300';
    bv_ball_spin = '0 0 0';
    bv_ball_state = BV_LIVE;
    BV_BallStep(0.1);
    BV_Assert("live-net-tape-bounces-up", bv_net_touched && bv_ball.velocity_z > 0);
    /* The positive half of the tape must not score an opponent-court hit. */
    setorigin(bv_ball, '2 0 110');
    bv_last_player = player;
    player.bv_contact_side = -1;
    targets = player.bv_targets;
    i = 0;
    while (bv_ball_state == BV_LIVE && i < 1100)
    {
        BV_BallStep(BV_STEP);
        i = i + 1;
    }
    BV_Assert("net-stall-finishes-the-attempt", bv_ball_state == BV_DEAD &&
        player.bv_last_result == BV_RESULT_NET && player.bv_targets == targets);
    BV_Predict('2 0 110', '0 0 -300', '0 0 0');
    BV_Assert("net-stall-preview-matches-live", BV_AttemptResult(bv_landing, -1,
        bv_predict_net, bv_predict_under_net, bv_flight_time) == BV_RESULT_NET);

    BV_TestReset(player);
    setorigin(bv_ball, '208 92 120');
    bv_ball.velocity = '0 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_state = BV_LIVE;
    bv_last_player = player;
    player.bv_contact_side = -1;
    bv_live_time = BV_MAX_FLIGHT;
    targets = player.bv_targets;
    BV_BallStep(BV_STEP);
    BV_Assert("expired-airborne-ball-cannot-score", bv_ball_state == BV_DEAD &&
        player.bv_last_result == BV_RESULT_OUT && player.bv_targets == targets);

    BV_TestReset(player);
    setorigin(bv_ball, '0 144 120');
    bv_ball.velocity = '0 0 -200';
    bv_ball_spin = '0 0 0';
    bv_ball_state = BV_LIVE;
    BV_BallStep(0.2);
    BV_Assert("post-top-does-not-let-ball-through", bv_ball.origin_z >= 91 + BV_RADIUS - 0.01 &&
        bv_ball.velocity_z > 0 && !bv_net_touched);
};
