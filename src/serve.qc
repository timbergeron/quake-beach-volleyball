// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
float(entity player) BV_TossSpeed =
{
    /* Keep the jump toss within overhead reach at the 65 cm jump apex. */
    if (player.bv_serve_style == BV_TOPSPIN_SERVE) return 150;
    return 140;
};

void(entity player, vector contact) BV_BuildServe =
{
    local vector heading, delta;
    local float speed, angle, charge;
    charge = BV_Clamp(player.bv_charge, 0, 1);
    heading = player.bv_aim;
    if (vlen(heading) < 0.5) heading = BV_Heading(player.v_angle_y);
    if (player.bv_isbot)
    {
        delta = player.bv_shot_target - contact;
        delta_z = 0;
        heading = normalize(delta);
    }
    bv_shot_kind = BV_SERVE;
    bv_shot_phase = player.bv_float_seed;
    bv_shot_float = 0;
    if (player.bv_serve_style == BV_TOPSPIN_SERVE)
    {
        speed = 340 + charge * 340;
        // A jump creates the height needed to use the fast, dipping trajectory.
        if (player.flags & FL_ONGROUND) speed = speed * 0.78;
        angle = 4 + BV_Clamp(player.bv_arc, 0, 1) * 16;
        bv_shot_spin = BV_Cross('0 0 1', heading) * (75 + charge * 40);
        bv_shot_spin = bv_shot_spin - '0 0 1' * (player.bv_sidespin * 24);
    }
    else
    {
        speed = 250 + charge * 250;
        angle = 6 + BV_Clamp(player.bv_arc, 0, 1) * 25;
        bv_shot_spin = -'0 0 1' * (player.bv_sidespin * 24);
        bv_shot_float = 1;
    }
    angle = (angle + BV_Clamp(-player.bv_last_pitch, -8, 8) + player.bv_depth * 5) * BV_PI / 180;
    bv_shot_velocity = heading * (cos(angle) * speed);
    bv_shot_velocity_z = sin(angle) * speed;
};
