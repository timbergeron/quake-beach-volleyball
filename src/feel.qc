// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Original preparation/contact tuning inspired by Virtua Tennis's documented
 * positioning controls. Flight continues through the ordinary ball integrator.
 */
var float autocvar_bv_contact_kick = 1;
vector bv_shot_velocity, bv_shot_spin;
float bv_shot_kind;
vector bv_contact_velocity, bv_contact_spin;
float bv_contact_quality, bv_contact_reason;
void(entity player, vector contact) BV_BuildShot;

float(float value) BV_Smooth =
{
    value = BV_Clamp(value, 0, 1);
    return value * value * (3 - 2 * value);
};

float(entity player) BV_ServeTiming =
{
    local float peak, error;
    peak = 140 / BV_Clamp(autocvar_bv_gravity, 100, 800);
    error = fabs(time - player.bv_prepare_started - peak);
    return 1 - BV_Smooth((error - 0.07) / 0.3);
};

float(entity player) BV_Charge =
{
    local float peak, age;
    age = time - player.bv_prepare_started;
    if (!player.bv_serve_contact) return BV_Clamp(age / 0.75, 0, 1);
    peak = 140 / BV_Clamp(autocvar_bv_gravity, 100, 800);
    /* The serve gauge rises toward the apex, then falls. Waiting longer
     * cannot bank a maximum-power serve after the useful toss window.
     */
    return BV_Clamp(1 - fabs(age - peak) / peak, 0, 1);
};

void(entity player) BV_UpdateFooting =
{
    local vector horizontal;
    local float target, dt;
    horizontal = player.velocity;
    horizontal_z = 0;
    dt = BV_Clamp(frametime, 0, 0.25);
    if (player.bv_dive_until > time) target = 0;
    else if (player.flags & FL_ONGROUND)
        target = 1 - BV_Clamp((vlen(horizontal) - 25) / 160, 0, 1);
    else return; // Carry takeoff footing through a deliberate jump attack.
    player.bv_footing = BV_Clamp(player.bv_footing +
        BV_Clamp(target - player.bv_footing, -dt * 4, dt * 4), 0, 1);
};

void(entity player, vector contact) BV_GradeContact =
{
    local vector horizontal, offset;
    local float preparation, stretch, moving, footing;
    BV_ContactZone(player, contact);
    offset = contact - bv_hand_position;
    stretch = BV_Smooth((vlen(offset) / bv_hand_radius - 0.25) / 0.75);
    preparation = BV_Clamp((time - player.bv_prepare_started) / 0.25, 0, 1);
    horizontal = player.velocity;
    horizontal_z = 0;
    moving = BV_Clamp(vlen(horizontal) / 185, 0, 1);
    footing = BV_Clamp(player.bv_footing, 0, 1);
    bv_contact_quality = (0.84 + preparation * 0.16) * (1 - stretch * 0.38) *
        (0.82 + footing * 0.18) * (1 - moving * 0.12);
    bv_contact_reason = BV_NOTE_CLEAN;
    if (preparation < 0.8) bv_contact_reason = BV_NOTE_PREPARATION;
    if (footing < 0.7 || moving > 0.4) bv_contact_reason = BV_NOTE_FOOTING;
    if (stretch > 0.35) bv_contact_reason = BV_NOTE_REACH;
    if (player.bv_dive_until > time)
    {
        bv_contact_quality = bv_contact_quality * 0.82;
        bv_contact_reason = BV_NOTE_DIVE;
    }
    if (player.bv_serve_contact)
    {
        bv_contact_quality = bv_contact_quality * (0.72 + BV_ServeTiming(player) * 0.28);
        if (BV_ServeTiming(player) < 0.75) bv_contact_reason = BV_NOTE_TIMING;
    }
    bv_contact_quality = BV_Clamp(bv_contact_quality, 0.35, 1);
};

/* Candidate bot flights and the final contact use the same placement loss,
 * incoming momentum and spin. This helper only writes contact outputs.
 */
void(entity player, vector contact) BV_ApplyContact =
{
    local vector horizontal, offset, right;
    local float stretch, lateral, carry;
    BV_ContactZone(player, contact);
    offset = contact - bv_hand_position;
    stretch = BV_Smooth((vlen(offset) / bv_hand_radius - 0.25) / 0.75);
    horizontal = player.velocity;
    horizontal_z = 0;
    right = BV_Cross(player.bv_aim, '0 0 1');
    if (vlen(right) < 0.5) right = BV_Cross(BV_Heading(player.v_angle_y), '0 0 1');
    lateral = BV_Clamp((offset * right) / bv_hand_radius, -1, 1);
    bv_contact_velocity = bv_shot_velocity * bv_contact_quality;
    /* Glancing contacts lose placement in the direction of the reach,
     * consistently rather than through a random error roll.
     */
    bv_contact_velocity = bv_contact_velocity + right *
        (lateral * vlen(bv_shot_velocity) * stretch * 0.12);
    bv_contact_velocity = bv_contact_velocity + horizontal * (0.12 * (1 - bv_contact_quality));
    carry = stretch * 0.08;
    if (bv_shot_kind == BV_PASS) carry = carry + 0.035;
    if (bv_shot_kind == BV_SET) carry = carry + 0.015;
    if (bv_shot_kind == BV_SERVE) carry = 0;
    bv_contact_velocity = bv_contact_velocity + bv_ball.velocity * carry;
    bv_contact_spin = bv_shot_spin * bv_contact_quality - '0 0 1' * (lateral * stretch * 8);
};

void(entity player, vector contact) BV_ResolveContact =
{
    BV_GradeContact(player, contact);
    BV_BuildShot(player, contact);
    BV_ApplyContact(player, contact);
};

string(float kind, float diving) BV_ContactSample =
{
    if (diving) return "beach/dig.wav";
    if (kind == BV_SET) return "beach/set.wav";
    if (kind == BV_SPIKE) return "beach/spike.wav";
    if (kind == BV_ROLL) return "beach/roll.wav";
    if (kind == BV_SERVE) return "beach/serve.wav";
    return "beach/pass.wav";
};

void(entity player) BV_ContactFeedback =
{
    local float kick;
    kick = 0.6;
    if (player.bv_kind == BV_SET) kick = 0.3;
    if (player.bv_kind == BV_ROLL) kick = 0.45;
    if (player.bv_kind == BV_SPIKE) kick = 1.5;
    if (player.bv_kind == BV_SERVE) kick = 1.1;
    if (player.bv_dive_until > time) kick = 0.8;
    player.punchangle_x = -kick * player.bv_quality * BV_Clamp(autocvar_bv_contact_kick, 0, 1);
    sound(bv_ball, 1, BV_ContactSample(player.bv_kind, player.bv_dive_until > time),
        0.4 + player.bv_quality * 0.35, 1);
};
