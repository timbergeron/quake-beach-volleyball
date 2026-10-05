// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Matching frame order in the original athlete and hands models in assets.py.
 * Preparation holds a readable pose; contact moves into a follow-through.
 */
void(entity player) BV_Animate =
{
    local vector horizontal;
    local float pose, elapsed;
    horizontal = player.velocity;
    horizontal_z = 0;
    pose = 0;
    if (vlen(horizontal) > 20) pose = 1 + floor(time * 8) - floor(time * 4) * 2;
    if (player.bv_preparing || player.bv_armed_until > time)
    {
        pose = 3;
        if (player.bv_action == 2) pose = 4;
        if (!(player.flags & FL_ONGROUND)) pose = 5;
        if (player.bv_serve_contact) pose = 6;
    }
    elapsed = time - player.bv_last_contact;
    if (player.bv_recover_until > time)
    {
        pose = 7;
        if (player.bv_kind == BV_SET) pose = 8;
        if (player.bv_kind == BV_SPIKE || player.bv_kind == BV_ROLL ||
            player.bv_kind == BV_SERVE) pose = 9;
        if (elapsed > 0.12) pose = 10;
    }
    if (player.bv_dive_until > time) pose = 11;
    player.frame = pose;
    player.weaponframe = pose;
};
