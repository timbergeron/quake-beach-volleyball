// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Rules, swept contacts, commitment and tactical decisions in the real VM. */
void(entity player) BV_BlockTestRally =
{
    BV_MatchServe();
    bv_match_phase = BV_MATCH_RALLY;
    bv_ball_state = BV_LIVE;
    bv_holder = world;
    bv_serve_pending = FALSE;
    bv_touch_team = 1; bv_touches = 3;
    bv_touch_actor = bv_opponent1;
    bv_last_player = bv_opponent1;
    bv_opponent1.bv_kind = BV_SPIKE;
    setorigin(player, '-22 0 44');
    player.flags = player.flags - (player.flags & FL_ONGROUND);
    player.v_angle = '0 0 0';
    player.bv_takeoff_at = time - 0.25;
    player.velocity = '0 0 0';
    BV_BeginBlock(player);
    setorigin(bv_ball, '30 0 94');
    bv_ball.velocity = '-500 0 -20';
    bv_ball_spin = '0 12 3';
    bv_live_time = 0;
};

void(entity player) BV_RunBlockTests =
{
    local vector normal, before, launch;
    local float started, saved_time, score;
    saved_time = time;
    BV_TestReset(player);
    BV_StartMatch(player);
    BV_BlockTestRally(player);
    BV_Assert("block-sweeps-fast-incoming-ball", BV_FindBlock('30 0 94', '-30 0 94') &&
        bv_block_actor == player && bv_block_point_x <= 0 && bv_block_point_x > -14);
    BV_Assert("block-cannot-steal-opponent-set", !BV_FindBlock('30 0 94', '5 0 94'));
    BV_Assert("cut-outside-committed-hands-beats-block", !BV_FindBlock('30 30 94', '-30 30 94'));
    BV_Assert("roll-above-hands-beats-block", !BV_FindBlock('30 0 120', '-30 0 120'));
    BV_Assert("block-does-not-catch-outgoing-ball", !BV_FindBlock('-30 0 94', '30 0 94'));
    time = time + 0.3;
    BV_Assert("early-jump-leaves-opening", !BV_FindBlock('30 0 94', '-30 0 94'));
    time = time - 0.3;
    player.flags = player.flags | FL_ONGROUND;
    BV_Assert("grounded-hands-are-not-a-block", !BV_FindBlock('30 0 94', '-30 0 94'));
    player.flags = player.flags - (player.flags & FL_ONGROUND);
    bv_opponent1.bv_kind = BV_SERVE;
    BV_Assert("serve-cannot-be-blocked", !BV_FindBlock('30 0 94', '-30 0 94'));
    bv_opponent1.bv_kind = BV_SPIKE;
    bv_serve_pending = TRUE;
    BV_Assert("serve-crossing-cannot-be-blocked", !BV_FindBlock('30 0 94', '-30 0 94'));
    bv_serve_pending = FALSE;
    normal = player.bv_block_normal;
    started = player.bv_block_started;
    player.v_angle_y = 70;
    player.button3 = 1;
    BV_BlockInput(player);
    BV_Assert("look-cannot-retarget-airborne-block", player.bv_block_normal == normal &&
        player.bv_block_started == started && player.bv_block_lane == 0);
    BV_BallStep(0.12);
    BV_Assert("live-block-physically-reflects-ball", bv_ball.velocity_x > 0 &&
        bv_last_player == player && player.bv_kind == BV_BLOCK && bv_block_point_x <= 0);
    BV_Assert("block-does-not-add-attack-power", vlen(bv_ball.velocity) < 500 && bv_ball_float == 0);
    BV_Assert("beach-block-counts-first-team-touch", bv_touch_team == -1 &&
        bv_touches == 1 && bv_touch_was_block);
    BV_Assert("one-jump-cannot-repeat-block-touch", !BV_FindBlock('30 0 94', '-30 0 94'));
    BV_Assert("blocker-can-play-next-team-touch", BV_MatchContact(player) &&
        bv_touches == 2 && !bv_touch_was_block && bv_match_phase == BV_MATCH_RALLY);
    BV_MatchContact(bv_partner);
    BV_Assert("block-leaves-two-ordinary-touches", bv_touches == 3 && bv_match_phase == BV_MATCH_RALLY);
    BV_MatchContact(player);
    BV_Assert("block-plus-three-touches-is-four-touch-fault", bv_match_phase == BV_MATCH_POINT &&
        bv_point_reason == BV_POINT_FOUR);

    BV_BlockTestRally(player);
    BV_FindBlock('30 0 94', '-30 0 94');
    BV_BlockContact('-500 0 0');
    BV_FinishRally('270 0 3.4');
    BV_Assert("block-deflected-out-is-charged-to-blocker", bv_serving_team == 1 &&
        bv_point_reason == BV_RESULT_OUT);

    BV_BlockTestRally(player);
    BV_FindBlock('30 0 94', '-30 0 94');
    BV_BlockContact('-500 0 0');
    BV_MatchContact(player);
    BV_MatchContact(player);
    BV_Assert("block-double-contact-exception-is-consumed-once", bv_match_phase == BV_MATCH_POINT &&
        bv_point_reason == BV_POINT_DOUBLE);

    BV_BlockTestRally(player);
    bv_touch_team = -1;
    BV_Assert("own-team-set-cannot-be-blocked", !BV_FindBlock('30 0 94', '-30 0 94'));
    bv_touch_team = 1;
    setorigin(player, '-22 0 24');
    player.flags = player.flags | FL_ONGROUND;
    player.bv_block_started = 0;
    player.bv_previous_secondary = player.bv_previous_jump = 0;
    player.button3 = player.button2 = 1;
    self = player;
    PlayerPreThink();
    BV_Assert("rmb-and-jump-start-contextual-block", player.bv_blocking &&
        player.bv_block_started == time && !player.bv_preparing && !(player.flags & FL_ONGROUND));
    BV_Animate(player);
    BV_Assert("block-uses-authored-body-and-hand-animation", player.bv_anim_clip == BV_ANIM_BLOCK_PIKE &&
        player.weaponframe == player.frame);
    player.bv_block_started = time - 0.3;
    player.bv_anim_next = 0;
    BV_Animate(player);
    BV_Assert("block-hands-visible-at-contact-phase", player.frame >= BV_ANIM_BLOCK_PIKE + 6 &&
        player.frame < BV_ANIM_BLOCK_PIKE + BV_ANIM_BLOCK_PIKE_COUNT);
    CSEv_BeachMenu_f(TRUE);
    BV_Assert("menu-cancels-block-input", !player.bv_blocking && !player.bv_block_started);
    CSEv_BeachMenu_f(FALSE);

    BV_BlockTestRally(player);
    BV_ResetActor(player, '-180 -58 24');
    BV_ResetActor(bv_partner, '-60 58 24');
    setorigin(bv_ball, '65 70 130');
    bv_ball.velocity = '0 0 30';
    bv_touches = 2;
    BV_PlanDefense(-1);
    BV_Assert("front-teammate-takes-block-role", bv_partner.bv_defense_role == 1 &&
        player.bv_defense_role == 2 && bv_partner.bv_goal_x == -22);
    BV_ResetActor(player, '-22 58 24');
    BV_ResetActor(bv_partner, '-150 -58 24');
    BV_PlanDefense(-1);
    BV_Assert("human-at-net-gets-partner-court-coverage", player.bv_defense_role == 1 &&
        bv_partner.bv_defense_role == 2 && bv_partner.bv_goal_x == -145 && bv_partner.bv_goal_y < 0);
    BV_ResetActor(player, '-35 58 24');
    BV_ResetActor(bv_partner, '-22 -58 24');
    player.bv_blocking = TRUE;
    BV_PlanDefense(-1);
    BV_Assert("human-block-intent-sends-front-partner-to-cover", player.bv_defense_role == 1 &&
        bv_partner.bv_defense_role == 2 && !bv_partner.bv_blocking);
    BV_ResetActor(bv_opponent1, '22 70 44');
    bv_opponent1.flags = bv_opponent1.flags - (bv_opponent1.flags & FL_ONGROUND);
    bv_opponent1.bv_takeoff_at = time - 0.2;
    bv_opponent1.v_angle_y = 180;
    BV_BeginBlock(bv_opponent1);
    BV_ResetActor(bv_opponent2, '180 -70 24');
    BV_Assert("mirrored-team-block-has-same-reach", BV_BlockSweep(bv_opponent1,
        '-30 70 94', '30 70 94', 0));
    before = bv_opponent1.origin;
    launch = bv_ball.velocity;
    score = BV_AttackScore('-45 70 100', '400 0 -60', '0 0 0', -1);
    BV_Assert("attacker-recognizes-committed-block", score == -4);
    BV_Assert("attack-query-preserves-live-state", bv_opponent1.origin == before &&
        bv_ball.velocity == launch && bv_opponent1.bv_block_started == time - 0.2);
    BV_ResetActor(player, '-62 70 47');
    player.flags = player.flags - (player.flags & FL_ONGROUND);
    player.bv_preparing = player.bv_action = 1;
    player.bv_prepare_started = time - 0.75;
    player.bv_aim = '1 0 0';
    player.bv_match_hint = BV_HINT_ATTACK;
    bv_touch_team = -1; bv_touches = 2; bv_touch_actor = bv_partner;
    bv_last_player = bv_partner;
    BV_ChooseAttack(player, '-45 70 100');
    BV_ApplyContact(player, '-45 70 100');
    score = BV_AttackScore('-45 70 100', bv_contact_velocity, bv_contact_spin, -1);
    BV_Assert("attack-selection-finds-opening-around-block", score > -4 &&
        (bv_shot_kind == BV_ROLL || bv_opponent1.bv_block_lane != player.bv_shot_target_y));
    bv_touch_team = -1; bv_touches = 1; bv_touch_actor = player;
    bv_touch_was_block = TRUE;
    BV_ResetActor(player, '-22 0 24');
    BV_ResetActor(bv_partner, '-200 70 24');
    BV_Assert("receiver-selection-can-choose-blocker-after-deflection",
        BV_SelectReceiver(-1, '-22 0 44') == player);
    BV_PlanDefense(-1);
    BV_Assert("defense-releases-roles-on-team-touch", !player.bv_defense_role && !bv_partner.bv_defense_role);
    BV_StopMatch();
    BV_TestReset(player);
    BV_Assert("practice-clears-block-state", !player.bv_blocking && !player.bv_block_started &&
        !bv_touch_was_block);
    time = saved_time;
};

.float bv_block_test_started, bv_block_test_capture, bv_block_test_done;

/* Incoming balls are controlled fixtures; controls, bot decisions, movement,
 * gravity, swept hand contact and the resulting rebound remain fully live.
 */
void() BV_BlockTestInput =
{
    local float mode;
    mode = cvar("bv_blocktest");
    if (!self.bv_block_test_started)
    {
        self.bv_block_test_started = time;
        BV_StartMatch(self);
        BV_BlockTestRally(self);
        BV_ResetActor(self, '-22 0 24');
        BV_ResetActor(bv_partner, '-150 -58 24');
        BV_ResetActor(bv_opponent1, '65 0 24');
        bv_opponent1.bv_kind = BV_SPIKE;
        BV_ResetActor(bv_opponent2, '180 70 24');
        setorigin(bv_ball, '65 0 102');
        bv_ball.velocity = '-240 0 0';
        bv_ball_spin = '0 0 0';
        self.v_angle = '-20 0 0';
        if (mode == 2)
        {
            bv_opponent1.bv_kind = BV_ROLL;
            setorigin(bv_ball, '65 0 100');
            bv_ball.velocity = '-100 0 145';
        }
        if (mode == 3)
        {
            BV_ResetActor(self, '-125 -55 24');
            BV_ResetActor(bv_opponent1, '22 0 24');
            BV_ResetActor(bv_opponent2, '160 -58 24');
            self.bv_kind = BV_SPIKE;
            bv_last_player = self;
            bv_touch_actor = self;
            bv_touch_team = -1;
            setorigin(bv_ball, '-65 0 102');
            bv_ball.velocity = '240 0 0';
            self.v_angle = '-12 21 0';
        }
        self.fixangle = TRUE;
        self.bv_previous_jump = self.bv_previous_secondary = 0;
        localcmd("con_notifytime 0\ncon_notifylines 0\nscr_fade 0\n");
    }
    self.button0 = self.button3 = self.button2 = 0;
    self.velocity_x = self.velocity_y = 0;
    if (mode != 3)
    {
        self.button3 = 1;
        if (time - self.bv_block_test_started < 0.05) self.button2 = 1;
    }
};

void() BV_BlockTestObserve =
{
    local entity blocker, cover;
    local float mode, age, success;
    mode = cvar("bv_blocktest");
    age = time - self.bv_block_test_started;
    blocker = self; cover = bv_partner;
    if (mode == 3) { blocker = bv_opponent1; cover = bv_opponent2; }
    if (!self.bv_block_test_capture && blocker.bv_block_started &&
        time - blocker.bv_block_started >= 0.25)
    {
        self.bv_block_test_capture = TRUE;
        if (blocker.origin_z > 35 && blocker.bv_anim_clip == BV_ANIM_BLOCK_PIKE)
            dprint("BEACH BLOCK PASS physical-jump-and-pose\n");
        else dprint("BEACH BLOCK FAIL physical-jump-and-pose\n");
        if (blocker.bv_defense_role == 1 && cover.bv_defense_role == 2 &&
            fabs(cover.origin_x) > 100 && fabs(cover.bv_goal_x) == 145)
            dprint("BEACH BLOCK PASS coordinated-court-coverage\n");
        else dprint("BEACH BLOCK FAIL coordinated-court-coverage\n");
        localcmd("screenshot tga\n");
    }
    success = FALSE;
    if (mode != 2 && blocker.bv_kind == BV_BLOCK && bv_touch_was_block &&
        bv_touches == 1 && bv_ball.velocity_x * BV_Team(blocker) < 0)
        success = TRUE;
    if (mode == 2 && bv_ball.origin_x < -20 && !blocker.bv_block_contacted &&
        age > 0.6 && bv_ball_state == BV_LIVE) success = TRUE;
    if (success && !self.bv_block_test_done)
    {
        self.bv_block_test_done = time;
        dprint("BEACH BLOCK PASS live-contact-or-roll-opening\n");
        localcmd("screenshot tga\n");
    }
    if (self.bv_block_test_done && time > self.bv_block_test_done + 0.12)
    {
        dprint("BEACH BLOCK DONE\n");
        localcmd("quit\n");
    }
    if (age > 3)
    {
        dprint("BEACH BLOCK FAIL timeout\n");
        localcmd("quit\n");
    }
};
