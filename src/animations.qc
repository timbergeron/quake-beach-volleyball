// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* The 24 Hz source clips share body/view-model frame ranges. Quake blends
 * single alias poses over 0.1 seconds, so send a new sample at that cadence.
 * Contact and movement remain owned by gameplay, never by animation frames.
 */
float(float start, float count, float phase, float looping) BV_AnimationFrame =
{
    if (looping) phase = phase - floor(phase);
    else phase = BV_Clamp(phase, 0, 1);
    if (looping) return start + floor(phase * count);
    return start + floor(phase * (count - 1));
};

void(entity player, float start, float count, float phase, float looping) BV_Animation =
{
    if (player.bv_anim_clip != start || time >= player.bv_anim_next)
    {
        player.frame = BV_AnimationFrame(start, count, phase, looping);
        player.weaponframe = player.frame;
        player.bv_anim_next = time + 0.1;
    }
    player.bv_anim_clip = start;
};

void(entity player) BV_ResetAnimation =
{
    player.bv_anim_clip = -1;
    player.bv_anim_started = -1;
    player.bv_anim_next = 0;
    player.bv_anim_phase = 0;
    player.bv_anim_air = FALSE;
    player.bv_anim_air_started = time;
    player.bv_anim_cut = FALSE;
};

void(entity player) BV_Animate =
{
    local vector horizontal, heading, left;
    local float start, count, elapsed, age, phase, forward, sideways, airborne, attack;
    horizontal = player.velocity;
    horizontal_z = 0;
    airborne = !(player.flags & FL_ONGROUND);
    if (airborne && !player.bv_anim_air) player.bv_anim_air_started = time;
    if (!airborne && player.bv_anim_air) player.bv_anim_started = time;
    player.bv_anim_air = airborne;
    age = time - player.bv_anim_air_started;
    elapsed = time - player.bv_last_contact;
    if (player.bv_dive_until > time)
    {
        BV_Animation(player, BV_ANIM_DIVE, BV_ANIM_DIVE_COUNT,
            (time - player.bv_dive_until + 0.48) / 0.48, FALSE);
        return;
    }
    if (player.bv_dive_until > 0 && time < player.bv_dive_until + 0.67)
    {
        BV_Animation(player, BV_ANIM_GETUP, BV_ANIM_GETUP_COUNT,
            (time - player.bv_dive_until) / 0.67, FALSE);
        return;
    }
    if (player.bv_recover_until > time)
    {
        start = BV_ANIM_PASS; count = BV_ANIM_PASS_COUNT;
        if (player.bv_kind == BV_SET) { start = BV_ANIM_SET; count = BV_ANIM_SET_COUNT; }
        if (player.bv_kind == BV_SPIKE) { start = BV_ANIM_SPIKE; count = BV_ANIM_SPIKE_COUNT; }
        if (player.bv_kind == BV_SPIKE && player.bv_anim_cut)
        { start = BV_ANIM_CUT; count = BV_ANIM_CUT_COUNT; }
        if (player.bv_kind == BV_ROLL) { start = BV_ANIM_ROLL; count = BV_ANIM_ROLL_COUNT; }
        if (player.bv_kind == BV_SERVE) { start = BV_ANIM_FLOAT_SERVE; count = BV_ANIM_FLOAT_SERVE_COUNT; }
        BV_Animation(player, start, count, elapsed / player.bv_recovery, FALSE);
        if (start == BV_ANIM_CUT && player.bv_anim_cut < 0)
            player.weaponframe = BV_VIEW_ANIM_CUT_AWAY + player.frame - BV_ANIM_CUT;
        return;
    }
    if (player.bv_preparing || player.bv_armed_until > time)
    {
        elapsed = time - player.bv_prepare_started;
        if (player.bv_serve_contact)
        {
            start = BV_ANIM_FLOAT_LOAD; count = BV_ANIM_FLOAT_LOAD_COUNT;
            phase = elapsed / 0.4;
            if (player.bv_serve_style == BV_TOPSPIN_SERVE)
            {
                start = BV_ANIM_JUMP_SERVE; count = BV_ANIM_JUMP_SERVE_COUNT;
                phase = elapsed / (BV_TossSpeed(player) / BV_Clamp(autocvar_bv_gravity, 100, 800));
            }
            BV_Animation(player, start, count, phase, FALSE);
            return;
        }
        /* Match hints describe the team plan, while the held input chooses
         * the actual stroke. Grounded RMB always loads a hand set, including
         * when the team is calling for an attack. Airborne RMB may be a roll.
         */
        attack = FALSE;
        if (player.bv_action == 1 || airborne)
        {
            if (player.bv_mode == 3) attack = TRUE;
            if (player.bv_match_hint == BV_HINT_ATTACK) attack = TRUE;
            if (player.bv_plan_kind == BV_SPIKE) attack = TRUE;
            if (airborne && bv_ball.origin_z > player.origin_z + 36) attack = TRUE;
        }
        if (BV_IsReceiving(player)) attack = FALSE;
        if (attack)
        {
            if (airborne)
            {
                start = BV_ANIM_TAKEOFF; count = BV_ANIM_TAKEOFF_COUNT;
                phase = BV_Clamp(age / 0.26, 0, 1) * 0.7;
                if (age >= 0.26)
                {
                    start = BV_ANIM_ATTACK_LOAD; count = BV_ANIM_ATTACK_LOAD_COUNT;
                    phase = (age - 0.26) / 0.27;
                }
            }
            else
            {
                start = BV_ANIM_APPROACH; count = BV_ANIM_APPROACH_COUNT;
                phase = BV_Clamp(elapsed / 0.55, 0, 0.7);
            }
            BV_Animation(player, start, count, phase, FALSE);
            return;
        }
        if (player.bv_action == 2)
            BV_Animation(player, BV_ANIM_SET_LOAD, BV_ANIM_SET_LOAD_COUNT, elapsed / 0.32, FALSE);
        else BV_Animation(player, BV_ANIM_PASS_LOAD, BV_ANIM_PASS_LOAD_COUNT, elapsed / 0.25, FALSE);
        return;
    }
    if (airborne)
    {
        BV_Animation(player, BV_ANIM_TAKEOFF, BV_ANIM_TAKEOFF_COUNT,
            BV_Clamp(age / 0.26, 0, 1) * 0.7, FALSE);
        return;
    }
    if (player.bv_anim_started > 0 && time < player.bv_anim_started + 0.3)
    {
        BV_Animation(player, BV_ANIM_LAND, BV_ANIM_LAND_COUNT,
            (time - player.bv_anim_started) / 0.3, FALSE);
        return;
    }
    if (vlen(horizontal) > 20)
    {
        /* Accumulate distance instead of global time: stopping does not reset
         * the stride and changing speed cannot make the feet jump in phase.
         */
        player.bv_anim_phase = player.bv_anim_phase + vlen(horizontal) * frametime / 100;
        heading = BV_Heading(player.v_angle_y);
        left = '-1 1 0';
        left_x = -heading_y; left_y = heading_x;
        forward = horizontal * heading;
        sideways = horizontal * left;
        start = BV_ANIM_RUN; count = BV_ANIM_RUN_COUNT;
        if (forward < -fabs(sideways)) { start = BV_ANIM_BACKPEDAL; count = BV_ANIM_BACKPEDAL_COUNT; }
        if (sideways > fabs(forward)) { start = BV_ANIM_SHUFFLE_L; count = BV_ANIM_SHUFFLE_L_COUNT; }
        if (sideways < -fabs(forward)) { start = BV_ANIM_SHUFFLE_R; count = BV_ANIM_SHUFFLE_R_COUNT; }
        BV_Animation(player, start, count, player.bv_anim_phase, TRUE);
        return;
    }
    BV_Animation(player, BV_ANIM_READY, BV_ANIM_READY_COUNT, time / 1.2, TRUE);
};
