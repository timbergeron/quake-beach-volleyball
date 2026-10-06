// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
void(entity player) BV_RunMatchRules =
{
    local vector point;
    local float contacts;
    BV_TestReset(player);
    BV_StartMatch(player);
    BV_Assert("doubles-spawns-three-physical-athletes", bv_partner.bv_isbot &&
        bv_opponent1.bv_isbot && bv_opponent2.bv_isbot &&
        bv_partner.solid == SOLID_BBOX && bv_partner.movetype == MOVETYPE_STEP);
    BV_Assert("doubles-starts-with-opponent-serve", bv_server == bv_opponent2 &&
        bv_match_phase == BV_MATCH_SERVE && bv_ball_state == BV_HELD);
    BV_Assert("receive-cannot-touch-serve-toss", !BV_MatchEligible(player, player.origin));
    BV_Assert("server-can-contact-toss", BV_MatchEligible(bv_server, bv_ball.origin));
    BV_MatchContact(bv_server);
    BV_Assert("server-waits-for-net-crossing", !BV_MatchEligible(bv_server, bv_ball.origin));
    bv_serve_pending = FALSE;
    BV_Assert("reach-cannot-cross-opponent-half", !BV_MatchEligible(player, '20 0 100'));
    BV_MatchContact(player);
    BV_Assert("receive-starts-three-touch-count", bv_touches == 1 && bv_touch_team == -1);
    BV_MatchContact(bv_partner);
    BV_MatchContact(player);
    BV_Assert("partner-set-human-attack-allowed", bv_touches == 3 && bv_match_phase == BV_MATCH_RALLY);
    BV_MatchContact(bv_partner);
    BV_Assert("fourth-touch-awards-opponent", bv_away_score == 1 && bv_match_phase == BV_MATCH_POINT);
    BV_MatchPoint(1, "TEST");
    BV_Assert("point-awarded-once", bv_away_score == 1);
    BV_MatchServe();
    bv_match_phase = BV_MATCH_RALLY;
    bv_serve_pending = FALSE;
    BV_MatchContact(player);
    BV_MatchContact(player);
    BV_Assert("consecutive-same-player-touch-faults", bv_away_score == 2);
    BV_MatchServe();
    bv_match_phase = BV_MATCH_RALLY;
    bv_touch_team = -1;
    bv_under_net = FALSE;
    bv_live_time = 1;
    BV_FinishRally('100 0 3.4');
    BV_Assert("opponent-ground-scores-home", bv_home_score == 1);
    BV_MatchServe();
    bv_match_phase = BV_MATCH_RALLY;
    bv_touch_team = -1;
    BV_FinishRally('270 0 3.4');
    BV_Assert("out-charged-to-last-touch", bv_away_score == 3);
    BV_MatchServe();
    bv_match_phase = BV_MATCH_RALLY;
    bv_touch_team = 1;
    bv_under_net = TRUE;
    BV_FinishRally('-100 0 3.4');
    BV_Assert("under-net-fault-charged-to-last-touch", bv_home_score == 2);
    BV_StopMatch();
    BV_Assert("practice-removes-match-state", !bv_match && bv_partner == world &&
        bv_server == world && bv_match_owner == world && bv_ball_state == BV_IDLE);
    BV_Assert("practice-removes-bot-entities", !find(player, classname, "player"));
    BV_TestReset(player);
    player.bv_assisted = TRUE;
    BV_BeginPreparation(player, 1);
    player.bv_serve_contact = FALSE;
    player.bv_prepare_started = time - 1;
    BV_ContactZone(player, player.origin + '0 0 20');
    point = bv_hand_position;
    BV_Assert("held-assist-never-reaches-remote-ball", !BV_TryContacts(point + '0 100 0', point + '0 101 0'));
    player.bv_recover_until = time + 0.3;
    BV_Assert("recovery-prevents-instant-contact", !BV_TryContacts(point, point));
    player.bv_recover_until = 0;
    contacts = player.bv_last_contact;
    BV_Assert("held-assist-contacts-within-hands", BV_TryContacts(point, point) &&
        player.bv_last_contact != contacts && !player.bv_preparing);
    BV_Assert("pass-creates-recovery-commitment", player.bv_recover_until > time);
    BV_TestReset(player);
    player.bv_assisted = FALSE;
    player.bv_recover_until = time + 0.3;
    player.bv_previous_primary = 0;
    player.button0 = 1;
    PlayerPreThink();
    BV_Assert("recovery-rejects-second-preparation", !player.bv_preparing);
    BV_TestReset(player);
    player.bv_overlays = FALSE;
    BV_BeginPreparation(player, 1);
    BV_UpdatePreview(player);
    BV_Assert("overlays-hide-landing-marker", player.bv_marker.modelindex == 0 && player.bv_preview_result == 0);
    player.bv_overlays = TRUE;
    BV_Assert("hands-model-and-preparation-pose", player.weaponmodel == "progs/bv_hands.md3");
    BV_Animate(player);
    BV_Assert("serve-preparation-visible", player.weaponframe >= BV_ANIM_FLOAT_LOAD &&
        player.weaponframe < BV_ANIM_FLOAT_LOAD + BV_ANIM_FLOAT_LOAD_COUNT);
    BV_StartMatch(player);
    bv_home_score = bv_match_goal;
    bv_away_score = bv_match_goal - 1;
    bv_match_phase = BV_MATCH_RALLY;
    BV_MatchPoint(1, "TEST DEUCE");
    BV_Assert("equal-scores-continue-past-goal", bv_match_phase == BV_MATCH_POINT);
    bv_match_phase = BV_MATCH_RALLY;
    BV_MatchPoint(-1, "TEST ADVANTAGE");
    BV_Assert("one-point-lead-continues", bv_match_phase == BV_MATCH_POINT);
    bv_match_phase = BV_MATCH_RALLY;
    BV_MatchPoint(-1, "TEST WIN");
    BV_Assert("two-point-lead-finishes-match", bv_match_phase == BV_MATCH_OVER);
    BV_StopMatch();
    /* Keep the practice test client's cleanup path valid. */
    BV_TestReset(player);
};
