// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* MD3 cloth flex is cosmetic; the shared swept collision stays deterministic. */
entity bv_net;
float bv_net_started, bv_net_region, bv_net_direction;

void() BV_SpawnNet =
{
    bv_net = spawn();
    bv_net.classname = "beach_net";
    bv_net.movetype = MOVETYPE_NONE;
    bv_net.solid = SOLID_NOT;
    bv_net.effects = BV_EF_NOSHADOW;
    setmodel(bv_net, "progs/bv_net.md3");
    setorigin(bv_net, '0 0 0');
    bv_net_started = -1;
};

void(vector point, vector incoming) BV_NetImpact =
{
    if (bv_net == world) return;
    // Repeated overlap resolution must not restart one cloth impact forever.
    if (time - bv_net_started < 0.08) return;
    if (vlen(incoming) < 25) return;
    bv_net_region = 1;
    if (point_y < -45) bv_net_region = 0;
    if (point_y > 45) bv_net_region = 2;
    bv_net_direction = 0;
    if (incoming_x < 0) bv_net_direction = 1;
    bv_net_started = time;
    bv_net.frame = 1 + (bv_net_region * 2 + bv_net_direction) * 6;
};

void() BV_UpdateNet =
{
    local float phase;
    if (bv_net == world || bv_net_started < 0) return;
    phase = floor((time - bv_net_started) / 0.08);
    if (phase >= 6)
    {
        bv_net.frame = 0;
        bv_net_started = -1;
        return;
    }
    bv_net.frame = 1 + (bv_net_region * 2 + bv_net_direction) * 6 + phase;
};
