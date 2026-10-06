// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Decisions are exercised in the real QC VM; the live fixture below also
 * checks engine movement, gravity, hand reach and dig recovery at two rates.
 */
void(entity player) BV_RunBotTests =
{
    local entity actor;
    local vector centre, contact, chosen, before, launch, spin;
    local float baseline, score, saved_time, saved_wind;
    saved_time = time;
    saved_wind = autocvar_bv_wind_y;
    BV_TestReset(player);
    player.bv_assisted = TRUE;
    BV_BeginPreparation(player, 1);
    player.bv_serve_contact = FALSE;
    player.bv_prepare_started = time - 1;
    BV_ContactZone(player, player.origin + '0 0 20');
    centre = bv_hand_position;
    BV_TryContacts(centre, centre);
    time = time + 1;
    BV_BeginPreparation(player, 1);
    player.bv_prepare_started = time - 1;
    BV_Assert("continuous-overlap-cannot-recontact-after-recovery", !BV_TryContacts(centre, centre));
    BV_BeginPreparation(player, 2);
    player.bv_prepare_started = time - 1;
    BV_ContactZone(player, centre);
    centre = bv_hand_position;
    BV_Assert("changing-pose-does-not-release-contact-latch", !BV_TryContacts(centre, centre));
    BV_TryContacts(centre + '0 100 0', centre + '0 101 0');
    BV_Assert("separation-allows-next-practice-touch", BV_TryContacts(centre, centre));
    BV_Feed(player, FALSE);
    BV_Assert("new-feed-clears-contact-latch", !player.bv_contact_latched);

    BV_StartMatch(player);
    bv_match_phase = BV_MATCH_RALLY;
    bv_serve_pending = FALSE;
    actor = bv_partner;
    BV_ResetActor(actor, '-65 0 62');
    actor.flags = actor.flags - (actor.flags & FL_ONGROUND);
    actor.v_angle_y = 0;
    actor.bv_action = 1;
    actor.bv_plan_kind = BV_SPIKE;
    actor.bv_preparing = 1;
    actor.bv_prepare_started = time - 1;
    actor.bv_aim = '1 0 0';
    contact = '-48 0 115';
    bv_ball.velocity = '0 0 0';
    bv_ball_spin = '0 0 0';
    BV_ResetActor(bv_opponent1, '100 -95 24');
    BV_ResetActor(bv_opponent2, '210 -95 24');
    BV_GradeContact(actor, contact);
    BV_BotTargetShot(actor, contact, '190 -75 3.4', BV_SPIKE);
    BV_ApplyContact(actor, contact);
    baseline = BV_AttackScore(contact, bv_contact_velocity, bv_contact_spin, -1);
    before = bv_ball.origin;
    BV_ResolveContact(actor, contact);
    chosen = actor.bv_shot_target;
    launch = bv_contact_velocity;
    spin = bv_contact_spin;
    score = BV_AttackScore(contact, launch, spin, -1);
    BV_Assert("attack-prefers-open-side-of-both-defenders", chosen_y > 20 && score > baseline);
    BV_Assert("attack-search-preserves-live-ball-and-defenders", bv_ball.origin == before &&
        bv_ball.velocity == '0 0 0' && bv_opponent1.origin == '100 -95 24' &&
        bv_opponent2.origin == '210 -95 24');
    BV_Predict(contact, launch, spin);
    BV_Assert("chosen-attack-has-valid-graded-flight", !bv_predict_net && !bv_predict_under_net &&
        bv_landing_x > 0 && BV_InCourt(bv_landing) && bv_flight_time < 4);
    BV_ResolveContact(actor, contact);
    BV_Assert("attack-selection-is-repeatable", chosen == actor.bv_shot_target &&
        vlen(launch - bv_contact_velocity) < 0.001 && vlen(spin - bv_contact_spin) < 0.001);
    BV_ResetActor(bv_opponent1, '100 95 24');
    BV_ResetActor(bv_opponent2, '210 95 24');
    BV_ResolveContact(actor, contact);
    BV_Assert("attack-mirrors-open-court-placement", actor.bv_shot_target_y < -20 &&
        fabs(actor.bv_shot_target_y + chosen_y) < 0.001);
    BV_ResetActor(bv_opponent2, '100 -95 24');
    BV_ResolveContact(actor, contact);
    BV_Assert("moving-second-defender-changes-shot-choice", actor.bv_shot_target != chosen &&
        actor.bv_shot_target_y != -chosen_y);
    autocvar_bv_wind_y = 60;
    BV_ResolveContact(actor, contact);
    BV_Predict(contact, bv_contact_velocity, bv_contact_spin);
    BV_Assert("wind-is-included-in-attack-validation", !bv_predict_net && !bv_predict_under_net &&
        bv_landing_x > 0 && BV_InCourt(bv_landing));
    autocvar_bv_wind_y = saved_wind;
    BV_Assert("unsafe-under-net-attack-is-rejected", BV_AttackScore('-48 0 20', '500 0 0',
        '0 0 0', -1) == -10000);
    BV_Assert("unsafe-long-attack-is-rejected", BV_AttackScore('-48 0 115', '600 0 300',
        '0 0 0', -1) == -10000);
    setorigin(actor, '-65 0 32');
    BV_ResetActor(bv_opponent1, '230 -70 24');
    BV_ResetActor(bv_opponent2, '230 70 24');
    BV_ResolveContact(actor, '-48 0 85');
    BV_Assert("low-attack-chooses-roll-over-blocked-spikes", bv_shot_kind == BV_ROLL);
    BV_Predict('-48 0 85', bv_contact_velocity, bv_contact_spin);
    BV_Assert("low-contact-roll-clears-net-and-lands-in", !bv_predict_net && !bv_predict_under_net &&
        bv_landing_x > 0 && BV_InCourt(bv_landing));
    actor.bv_dive_until = time + 0.3;
    bv_touch_team = -1;
    bv_touches = 1;
    bv_touch_actor = actor;
    setorigin(bv_ball, '-100 0 95');
    bv_ball.velocity = '0 0 -15';
    BV_PlanBot(actor, -1, TRUE);
    BV_Assert("diving-teammate-dig-hands-set-role-to-human", bv_home_receiver == player);

    actor = bv_opponent1;
    BV_ResetActor(actor, '78 -58 24');
    bv_touch_team = -1;
    bv_touches = 3;
    bv_touch_actor = player;
    BV_ResetActor(bv_opponent2, '185 58 24');
    actor.bv_recover_until = time + 2;
    BV_Assert("receiver-selection-accounts-for-recovery", BV_SelectReceiver(1, '105 -58 44') == bv_opponent2);
    actor.bv_recover_until = 0;
    setorigin(bv_ball, '165 -58 65');
    bv_ball.velocity = '0 0 -85';
    bv_ball_spin = '0 0 0';
    BV_Forecast(44);
    centre = bv_intercept;
    BV_Assert("reachable-emergency-ball-triggers-dive", BV_TryBotDive(actor, 1));
    BV_Assert("dive-keeps-normal-forecast-for-other-bots", centre == bv_intercept);
    BV_Assert("dive-has-physical-launch-and-low-footing", actor.velocity_x == 250 &&
        actor.velocity_z == 55 && !(actor.flags & FL_ONGROUND) && actor.bv_footing == 0);
    BV_Assert("diving-receiver-keeps-team-commitment", BV_SelectReceiver(1, '185 58 44') == actor);
    time = actor.bv_dive_until + 0.01;
    actor.flags = actor.flags | FL_ONGROUND;
    BV_MoveBot(actor);
    BV_Assert("missed-dive-still-requires-recovery", actor.bv_recover_until > time + 0.6 &&
        !actor.bv_preparing && !actor.bv_dive_until);
    BV_Forecast(44);
    BV_Assert("recovering-bot-cannot-dive-again", !BV_TryBotDive(actor, 1));
    BV_ResetActor(actor, '78 -58 24');
    setorigin(bv_ball, '105 -58 65');
    BV_Forecast(44);
    BV_Assert("normally-reachable-ball-does-not-trigger-dive", !BV_TryBotDive(actor, 1));
    setorigin(bv_ball, '230 -58 65');
    BV_Forecast(44);
    BV_Assert("unreachable-ball-does-not-trigger-futile-dive", !BV_TryBotDive(actor, 1));
    setorigin(bv_ball, '-100 -58 65');
    BV_Forecast(44);
    BV_Assert("bot-cannot-dive-across-opponent-half", !BV_TryBotDive(actor, 1));
    actor.bv_dive_ready = time + 1;
    actor.bv_contact_latched = TRUE;
    BV_MatchServe();
    BV_Assert("next-serve-clears-dive-and-contact-state", !actor.bv_dive_ready &&
        !actor.bv_dive_until && !actor.bv_contact_latched);
    BV_StopMatch();
    time = saved_time;
    BV_TestReset(player);
};

.float bv_bot_test_started, bv_bot_test_capture;
float bv_bot_test_contact, bv_bot_test_recovery;

void() BV_BotTestInput =
{
    if (!self.bv_bot_test_started)
    {
        /* Let the startup console finish closing before capturing the dig. */
        if (time < 2) return;
        self.bv_bot_test_started = time;
        BV_StartMatch(self);
        bv_match_phase = BV_MATCH_RALLY;
        bv_touch_team = -1;
        bv_touches = 3;
        bv_touch_actor = self;
        bv_serve_pending = FALSE;
        bv_holder = world;
        bv_server.bv_serve_contact = FALSE;
        bv_ball_state = BV_LIVE;
        bv_bot_plan_at = 0;
        setorigin(bv_ball, '165 -58 65');
        bv_ball.velocity = '0 0 -85';
        bv_ball_spin = '0 0 0';
        /* Start after the attack is already descending into the receiver's
         * court. Every later movement and collision runs through live play.
         */
        BV_BeginPreparation(bv_opponent1, 1);
        bv_opponent1.bv_prepare_started = time - 0.3;
        self.v_angle = '-8 0 0';
        self.fixangle = TRUE;
        localcmd("con_notifytime 0\ncon_notifylines 0\nscr_fade 0\n");
    }
    self.button0 = 0;
    self.button3 = 0;
    self.button2 = 0;
    self.velocity_x = 0;
    self.velocity_y = 0;
};

void() BV_BotTestObserve =
{
    if (!self.bv_bot_test_started) return;
    if (bv_opponent1.bv_dive_until > time && !self.bv_bot_test_capture &&
        time > self.bv_bot_test_started + 0.12)
    {
        self.bv_bot_test_capture = TRUE;
        if (bv_opponent1.frame >= BV_ANIM_DIVE &&
            bv_opponent1.frame < BV_ANIM_DIVE + BV_ANIM_DIVE_COUNT && bv_opponent1.origin_x > 98)
            dprint("BEACH BOT PASS physical-dive-and-pose\n");
        else dprint("BEACH BOT FAIL dive-movement\n");
        localcmd("screenshot tga\n");
    }
    if (bv_touch_actor == bv_opponent1 && !bv_bot_test_contact)
    {
        bv_bot_test_contact = time;
        if (bv_opponent1.bv_kind == BV_PASS && bv_opponent1.bv_contact_note == BV_NOTE_DIVE &&
            bv_opponent1.bv_quality < 0.8 && bv_opponent1.bv_recover_until >= time + 0.74)
            dprint("BEACH BOT PASS live-emergency-dig\n");
        else dprint("BEACH BOT FAIL dig-contact\n");
        localcmd("screenshot tga\n");
    }
    if (bv_bot_test_contact && !bv_bot_test_recovery && time > bv_bot_test_contact + 0.5)
    {
        bv_bot_test_recovery = TRUE;
        if (!bv_opponent1.bv_preparing && bv_opponent1.bv_recover_until > time &&
            bv_opponent1.origin_x >= 20)
            dprint("BEACH BOT PASS dig-recovery\n");
        else dprint("BEACH BOT FAIL dig-recovery\n");
        dprint("BEACH BOT DONE\n");
        localcmd("quit\n");
    }
    if (time > self.bv_bot_test_started + 3)
    {
        dprint("BEACH BOT FAIL timeout\n");
        localcmd("quit\n");
    }
};
