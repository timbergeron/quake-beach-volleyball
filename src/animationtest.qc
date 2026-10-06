// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Exercise clip selection through real player state, including MD3 frames
 * above 255, directional footwork, preparation, and the recovery boundary.
 */
void(entity player) BV_RunAnimationTests =
{
    local float saved_time, saved_frametime, first, phase;
    saved_time = time;
    saved_frametime = frametime;
    BV_TestReset(player);
    bv_ball_state = BV_IDLE;
    bv_holder = world;
    player.bv_preparing = 0;
    player.bv_armed_until = 0;
    player.bv_serve_contact = 0;
    player.bv_mode = 0;
    player.bv_match_hint = 0;
    player.bv_plan_kind = 0;
    player.bv_dive_until = 0;
    player.bv_recover_until = 0;
    BV_ResetAnimation(player);
    BV_Animate(player);
    BV_Assert("animation-idle-has-valid-body-and-hands", player.frame >= BV_ANIM_READY &&
        player.frame < BV_ANIM_READY + BV_ANIM_READY_COUNT && player.frame == player.weaponframe);
    player.velocity = '0 120 0';
    frametime = 0.02;
    BV_Animate(player);
    BV_Assert("animation-left-shuffle-follows-local-travel", player.bv_anim_clip == BV_ANIM_SHUFFLE_L);
    player.velocity = '0 -120 0';
    BV_Animate(player);
    BV_Assert("animation-right-shuffle-follows-local-travel", player.bv_anim_clip == BV_ANIM_SHUFFLE_R);
    player.velocity = '-120 0 0';
    BV_Animate(player);
    BV_Assert("animation-backpedal-keeps-facing-net", player.bv_anim_clip == BV_ANIM_BACKPEDAL);
    player.v_angle_y = 180;
    BV_Animate(player);
    BV_Assert("animation-opposite-side-footwork-mirrors", player.bv_anim_clip == BV_ANIM_RUN);
    player.v_angle_y = 0;
    player.velocity = '0 0 0';
    phase = player.bv_anim_phase;
    BV_Animate(player);
    BV_Assert("animation-stopping-preserves-stride-phase", player.bv_anim_phase == phase);

    BV_BeginPreparation(player, 2);
    time = time + 0.4;
    BV_Animate(player);
    BV_Assert("animation-deep-set-holds-loaded-pose", player.frame == BV_ANIM_SET_LOAD + BV_ANIM_SET_LOAD_COUNT - 1);
    player.bv_preparing = 0;
    player.bv_kind = BV_SET;
    player.bv_last_contact = time;
    player.bv_recovery = 0.28;
    player.bv_recover_until = time + 0.28;
    BV_Animate(player);
    first = player.frame;
    time = time + 0.11;
    BV_Animate(player);
    BV_Assert("animation-set-contact-advances-follow-through", player.frame > first &&
        player.frame < BV_ANIM_SET + BV_ANIM_SET_COUNT);
    time = time + 0.4;
    BV_BeginPreparation(player, 1);
    player.bv_mode = 3;
    time = time + 0.4;
    BV_Animate(player);
    BV_Assert("animation-ground-attack-sweeps-both-arms-back", player.bv_anim_clip == BV_ANIM_APPROACH);
    player.flags = player.flags - (player.flags & FL_ONGROUND);
    BV_Animate(player);
    BV_Assert("animation-jump-starts-at-takeoff", player.bv_anim_clip == BV_ANIM_TAKEOFF);
    time = time + 0.4;
    BV_Animate(player);
    BV_Assert("animation-airborne-attack-draws-bow-arm", player.bv_anim_clip == BV_ANIM_ATTACK_LOAD);
    player.bv_preparing = 0;
    player.bv_armed_until = 0;
    player.bv_dive_until = time + 0.48;
    BV_Animate(player);
    BV_Assert("animation-dive-uses-extended-frame-number", player.frame >= BV_ANIM_DIVE &&
        player.frame < BV_ANIM_DIVE + BV_ANIM_DIVE_COUNT && player.weaponframe > 255);
    time = time + 0.5;
    BV_Animate(player);
    BV_Assert("animation-dive-finish-plays-getup", player.bv_anim_clip == BV_ANIM_GETUP);
    BV_Assert("animation-loop-never-enters-adjacent-clip", BV_AnimationFrame(BV_ANIM_RUN,
        BV_ANIM_RUN_COUNT, 1, TRUE) == BV_ANIM_RUN);
    BV_Assert("animation-hold-clamps-to-clip-end", BV_AnimationFrame(BV_ANIM_SET_LOAD,
        BV_ANIM_SET_LOAD_COUNT, 100, FALSE) == BV_ANIM_SET_LOAD + BV_ANIM_SET_LOAD_COUNT - 1);

    BV_TestReset(player);
    BV_ResetAnimation(player);
    bv_ball_state = BV_LIVE;
    bv_holder = world;
    player.bv_dive_until = 0;
    BV_BeginPreparation(player, 1);
    BV_Assert("animation-stores-initial-swing-heading", player.bv_swing_aim == player.bv_aim);
    player.flags = player.flags - (player.flags & FL_ONGROUND);
    player.bv_depth = -0.5;
    player.bv_aim = normalize('1 1 0');
    BV_Contact(player, player.origin + '18 0 64');
    BV_Animate(player);
    BV_Assert("animation-short-angled-contact-selects-cut", player.bv_kind == BV_SPIKE &&
        player.bv_anim_cut == 1 && player.bv_anim_clip == BV_ANIM_CUT);
    player.v_angle_y = 180;
    time = time + 0.11;
    BV_Animate(player);
    BV_Assert("animation-cut-persists-after-looking-away", player.bv_anim_clip == BV_ANIM_CUT);
    player.bv_swing_aim = '1 0 0';
    player.bv_aim = normalize('1 -1 0');
    BV_Contact(player, player.origin + '18 0 64');
    BV_Animate(player);
    BV_Assert("animation-wrist-away-uses-extra-hand-frames", player.bv_anim_cut == -1 &&
        player.weaponframe == BV_VIEW_ANIM_CUT_AWAY + player.frame - BV_ANIM_CUT);
    player.bv_aim = '1 0 0';
    player.bv_sidespin = 1;
    BV_Contact(player, player.origin + '18 0 64');
    BV_Animate(player);
    BV_Assert("animation-spin-alone-keeps-straight-spike", !player.bv_anim_cut &&
        player.bv_anim_clip == BV_ANIM_SPIKE);
    player.bv_aim = normalize('1 1 0');
    player.bv_depth = 0.5;
    BV_Contact(player, player.origin + '18 0 64');
    BV_Animate(player);
    BV_Assert("animation-deep-angled-attack-keeps-spike", !player.bv_anim_cut &&
        player.bv_anim_clip == BV_ANIM_SPIKE);
    player.bv_recover_until = 0;
    player.bv_preparing = 1;
    player.bv_serve_contact = TRUE;
    player.bv_serve_style = BV_FLOAT_SERVE;
    player.bv_prepare_started = time;
    BV_Animate(player);
    BV_Assert("animation-float-serve-loads-dedicated-palm", player.bv_anim_clip == BV_ANIM_FLOAT_LOAD);
    player.bv_preparing = 0;
    player.bv_kind = BV_SERVE;
    player.bv_last_contact = time;
    player.bv_recovery = 0.45;
    player.bv_recover_until = time + 0.45;
    BV_Animate(player);
    BV_Assert("animation-float-contact-uses-firm-palm-follow-through", player.bv_anim_clip == BV_ANIM_FLOAT_SERVE);
    time = saved_time;
    frametime = saved_frametime;
    BV_TestReset(player);
};
