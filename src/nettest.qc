// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
void(entity player) BV_RunNetTests =
{
    local float attempts, saved_time, score;
    local vector landing;
    saved_time = time;
    BV_TestReset(player);
    BV_Assert("net-md3-spawned-without-solid-mesh", bv_net != world &&
        bv_net.modelindex > 0 && bv_net.solid == SOLID_NOT);
    BV_Assert("net-wings-extend-past-court", BV_NetSweep('-40 135 60', '40 135 60'));
    BV_Assert("lower-band-catches-overlapping-ball", BV_NetSweep('-40 0 43', '40 0 43'));
    BV_Assert("ball-clears-below-regulation-panel", !BV_NetSweep('-40 0 41', '40 0 41') &&
        BV_UnderNetSweep('-40 0 41', '40 0 41'));
    BV_Assert("post-side-uses-rounded-sphere-sweep", BV_EquipmentSweep('-40 164 60', '40 164 60') &&
        bv_equipment_kind == 2 && bv_equipment_normal_y > 0.5 && bv_equipment_position_x < -5);
    BV_Assert("post-rounded-corner-is-clear", !BV_EquipmentSweep('-40 167 60', '40 167 60'));
    BV_Assert("post-overlap-can-move-away", !BV_EquipmentSweep('-4 160 60', '-30 160 60'));
    BV_EquipmentSweep('0 160 200', '0 160 30');
    BV_Assert("post-crown-stops-high-speed-descent", bv_equipment_kind == 2 &&
        fabs(bv_equipment_position_z - BV_POST_HEIGHT - BV_RADIUS) < 0.01 &&
        bv_equipment_normal_z > 0.99);
    BV_EquipmentSweep('-40 160 84', '40 160 84');
    BV_Assert("post-crown-glance-has-curved-normal", bv_equipment_kind == 2 &&
        bv_equipment_normal_z > 0.8 && bv_equipment_normal_x < -0.3);
    BV_Assert("antenna-above-net-is-swept", BV_EquipmentSweep('-40 128.16 95', '40 128.16 95') &&
        bv_equipment_kind == 3 && fabs(bv_equipment_position_x + 3.32) < 0.01);
    BV_Assert("opposite-antenna-is-swept", BV_EquipmentSweep('40 -128.16 95', '-40 -128.16 95') &&
        bv_equipment_kind == 3 && fabs(bv_equipment_position_x - 3.32) < 0.01);
    BV_Assert("ball-clears-above-antenna-tip", !BV_EquipmentSweep('-40 128.16 108', '40 128.16 108'));

    bv_hand_radius = 30;
    bv_hand_position = '-10 160 60';
    BV_Assert("hands-cannot-reach-through-padded-post", !BV_Reachable(player, '10 160 60'));
    BV_Assert("hands-remain-clear-on-near-post-side", BV_Reachable(player, '-20 160 60'));
    bv_hand_position = '-10 133 60';
    BV_Assert("hands-cannot-reach-through-net-wing", !BV_Reachable(player, '10 133 60'));
    bv_hand_position = '-10 128.16 95';
    BV_Assert("hands-cannot-reach-through-antenna", !BV_Reachable(player, '10 128.16 95'));

    BV_Predict('-12 128.16 95', '1500 0 0', '0 0 0');
    landing = bv_landing;
    BV_Assert("prediction-classifies-antenna-contact", bv_predict_antenna &&
        BV_AttemptResult(landing, -1, bv_predict_net, bv_predict_under_net,
            bv_predict_antenna, bv_flight_time) == BV_RESULT_ANTENNA);
    attempts = player.bv_attempts;
    setorigin(bv_ball, '-12 128.16 95');
    bv_ball.velocity = '1500 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_state = BV_LIVE;
    bv_last_player = player;
    BV_BallStep(BV_STEP);
    BV_Assert("live-antenna-contact-matches-forecast", bv_ball_state == BV_DEAD &&
        bv_antenna_touched && player.bv_last_result == BV_RESULT_ANTENNA &&
        vlen(bv_ball.origin - landing) < 0.02);
    BV_BallStep(BV_STEP);
    BV_Assert("antenna-attempt-counts-once", player.bv_attempts == attempts + 1);
    BV_ReadyServe(player);
    BV_Assert("next-serve-clears-antenna-fault", !bv_antenna_touched);
    BV_Predict('-600 0 100', '200 0 180', '0 0 0');
    BV_Assert("next-forecast-clears-antenna-fault", !bv_predict_antenna);

    BV_TestReset(player);
    setorigin(bv_ball, '-12 160 60');
    bv_ball.velocity = '1500 0 0';
    bv_ball_state = BV_LIVE;
    BV_BallStep(BV_STEP);
    BV_Assert("live-post-contact-is-a-rebound", bv_ball_state == BV_LIVE &&
        bv_ball.velocity_x < 0 && !bv_net_touched && !bv_antenna_touched);
    BV_Predict('-12 160 60', '1500 0 0', '0 0 0');
    BV_Assert("forecast-includes-post-rebound", bv_landing_x < -100 && !bv_predict_antenna);

    bv_net_started = -1;
    BV_NetImpact('0 -90 60', '400 0 0');
    BV_Assert("cloth-impact-selects-side-and-location", bv_net.frame == 1);
    time = time + 0.17;
    BV_UpdateNet();
    BV_Assert("cloth-impact-advances-decay-pose", bv_net.frame == 3);
    time = time + 0.5;
    BV_UpdateNet();
    BV_Assert("cloth-impact-settles-back-to-rest", bv_net.frame == 0 && bv_net_started < 0);
    BV_NetImpact('0 90 60', '-400 0 0');
    BV_Assert("opposite-cloth-impact-uses-mirrored-poses", bv_net.frame == 31);
    bv_net.frame = 0;
    bv_net_started = -1;
    time = saved_time;

    BV_StartMatch(player);
    bv_match_phase = BV_MATCH_RALLY;
    bv_touch_team = -1;
    bv_antenna_touched = TRUE;
    score = bv_away_score;
    BV_FinishRally('0 128.16 95');
    BV_Assert("antenna-touch-awards-opponent-point", bv_away_score == score + 1 &&
        bv_match_phase == BV_MATCH_POINT && bv_point_reason == BV_RESULT_ANTENNA);
    BV_FinishRally('0 128.16 95');
    BV_Assert("antenna-point-awarded-once", bv_away_score == score + 1);
    BV_StopMatch();
    BV_TestReset(player);
};

float bv_net_view_started, bv_net_view_reported;

void(entity player) BV_NetVisualSetup =
{
    local float view;
    view = cvar("bv_netview");
    player.movetype = MOVETYPE_NOCLIP;
    player.weaponmodel = "";
    player.bv_overlays = FALSE;
    bv_ball.modelindex = 0;
    setorigin(player, '-215 -235 125');
    player.v_angle = '17 47.5 0';
    if (view == 2) { setorigin(player, '200 0 70'); player.v_angle = '9 180 0'; }
    if (view == 3) { setorigin(player, '-45 -75 44'); player.v_angle = '0 0 0'; }
    if (view == 4) { setorigin(player, '-24 -188 49'); player.v_angle = '0 57.7 0'; }
    if (view == 5) { setorigin(player, '-65 0 34'); player.v_angle = '0 0 0'; }
    if (view == 6) { setorigin(player, '-65 100 68'); player.v_angle = '0 23.4 0'; }
    if (view == 7) { setorigin(player, '-8 -144 49'); player.v_angle = '0 346 0'; }
    player.angles = player.v_angle;
    player.fixangle = TRUE;
    bv_net_view_started = FALSE;
    bv_net_view_reported = FALSE;
};

void() BV_NetVisualInput =
{
    local float view;
    view = cvar("bv_netview");
    if ((view != 5 && view != 6) || time < 1.93 || bv_net_view_started) return;
    bv_net_view_started = TRUE;
    bv_holder = world;
    bv_ball_state = BV_LIVE;
    bv_last_player = self;
    setmodel(bv_ball, "progs/bv_ball.md3");
    setorigin(bv_ball, '-15 0 60');
    if (view == 6) setorigin(bv_ball, '-15 128.16 95');
    bv_ball.velocity = '600 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_float = 0;
    bv_live_time = 0;
    self.bv_contact_side = -1;
};

void() BV_NetVisualObserve =
{
    if (!bv_net_view_started || bv_net_view_reported) return;
    if (cvar("bv_netview") == 5 && bv_net_touched && bv_net.frame > 0 && bv_ball.velocity_x < 0)
    {
        bv_net_view_reported = TRUE;
        dprint("BEACH NET PASS live-mesh-impact-and-recoil\n");
    }
    if (cvar("bv_netview") == 6 && bv_antenna_touched && bv_ball_state == BV_DEAD &&
        self.bv_last_result == BV_RESULT_ANTENNA)
    {
        bv_net_view_reported = TRUE;
        dprint("BEACH NET PASS live-antenna-fault\n");
    }
};
