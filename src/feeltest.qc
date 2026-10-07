// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Exercise contact outcomes and ordinary controls in the actual QC VM. */
void(entity player, float action) BV_TestContactSetup =
{
    BV_TestReset(player);
    player.bv_action = action;
    player.bv_serve_contact = FALSE;
    player.bv_aim = '1 0 0';
    player.bv_arc = 0.35;
    player.bv_charge = 0.6;
    player.bv_sidespin = 0;
    player.bv_topspin = 0;
    player.bv_last_pitch = 0;
    player.bv_prepare_started = time - 0.5;
    bv_ball.velocity = '-100 0 -100';
    bv_ball_state = BV_LIVE;
    bv_holder = world;
    bv_feeder = world;
    bv_next_feed = 0;
};

void(entity player) BV_RunFeelTests =
{
    local vector centre, clean_velocity, other_velocity, landing, aim;
    local float clean, middle, edge, i, height, short_range, speed, footing;
    local float peak, started, saved_gravity, saved_kick, saved_overlays;
    saved_gravity = autocvar_bv_gravity;
    saved_kick = autocvar_bv_contact_kick;

    BV_TestContactSetup(player, 1);
    BV_ContactZone(player, '-271 0 44');
    centre = bv_hand_position;
    BV_ResolveContact(player, centre);
    clean = bv_contact_quality;
    clean_velocity = bv_contact_velocity;
    BV_Assert("centred-prepared-contact-is-clean", clean >= 0.99);
    player.bv_prepare_started = time - 0.02;
    BV_ResolveContact(player, centre);
    BV_Assert("rushed-contact-loses-power", bv_contact_quality < clean - 0.1 &&
        vlen(bv_contact_velocity) < vlen(clean_velocity) &&
        bv_contact_reason == BV_NOTE_PREPARATION);
    player.bv_prepare_started = time - 0.5;
    BV_ResolveContact(player, centre + '0 1 0' * (bv_hand_radius * 0.5));
    middle = bv_contact_quality;
    BV_ResolveContact(player, centre + '0 1 0' * (bv_hand_radius * 0.95));
    edge = bv_contact_quality;
    other_velocity = bv_contact_velocity;
    BV_Assert("sweet-spot-grades-smoothly", clean > middle && middle > edge && edge > 0.35);
    BV_Assert("glancing-contact-deflects-toward-reach", other_velocity_y > clean_velocity_y + 10 &&
        bv_contact_reason == BV_NOTE_REACH);
    BV_ResolveContact(player, centre - '0 1 0' * (bv_hand_radius * 0.95));
    BV_Assert("opposite-glances-mirror", fabs(bv_contact_velocity_y + other_velocity_y) < 0.01 &&
        fabs(bv_contact_quality - edge) < 0.001);
    BV_Assert("edge-of-reach-remains-playable", BV_Reachable(player,
        centre + '0 1 0' * (bv_hand_radius * 0.99)));
    BV_Assert("outside-hand-reach-still-misses", !BV_Reachable(player,
        centre + '0 1 0' * (bv_hand_radius * 1.01)));

    player.velocity = '185 0 0';
    player.bv_footing = 0;
    BV_ResolveContact(player, centre);
    BV_Assert("running-through-contact-loses-control", bv_contact_quality < clean - 0.2 &&
        bv_contact_reason == BV_NOTE_FOOTING);
    player.velocity = '0 0 0';
    frametime = BV_STEP;
    i = 0;
    while (i < 30) { BV_UpdateFooting(player); i = i + 1; }
    BV_ResolveContact(player, centre);
    BV_Assert("planting-feet-recovers-clean-contact", player.bv_footing > 0.99 &&
        bv_contact_quality >= clean - 0.01);
    player.bv_footing = 0;
    frametime = 0.05;
    i = 0;
    while (i < 5) { BV_UpdateFooting(player); i = i + 1; }
    footing = player.bv_footing;
    player.bv_footing = 0;
    frametime = 0.016666667;
    i = 0;
    while (i < 15) { BV_UpdateFooting(player); i = i + 1; }
    BV_Assert("footing-recovery-is-frame-rate-independent", fabs(footing - player.bv_footing) < 0.001);

    player.bv_footing = 1;
    player.flags = player.flags - (player.flags & FL_ONGROUND);
    player.velocity = '0 0 1' * BV_JumpSpeed();
    setorigin(player, '-70 0 44.8');
    BV_UpdateFooting(player);
    BV_ContactZone(player, '-53 0 97.8');
    BV_ResolveContact(player, bv_hand_position);
    BV_Assert("balanced-jump-keeps-clean-attack", player.bv_footing == 1 &&
        bv_shot_kind == BV_SPIKE && bv_contact_quality > 0.99);

    BV_TestContactSetup(player, 1);
    player.bv_dive_until = time + 0.4;
    player.bv_footing = 0;
    BV_ContactZone(player, '-271 0 26');
    centre = bv_hand_position;
    BV_Contact(player, centre);
    BV_Assert("dive-saves-ball-with-reduced-control", bv_ball_state == BV_LIVE &&
        player.bv_quality < 0.8 && player.bv_quality > 0.35 &&
        player.bv_contact_note == BV_NOTE_DIVE);

    BV_TestContactSetup(player, 1);
    BV_ContactZone(player, '-271 0 44');
    centre = bv_hand_position;
    BV_ResolveContact(player, centre);
    clean_velocity = bv_contact_velocity;
    BV_ResolveContact(player, centre);
    BV_Assert("contact-error-is-repeatable", vlen(clean_velocity - bv_contact_velocity) < 0.001);
    setorigin(player, '288 0 24');
    player.v_angle_y = 180;
    player.bv_aim = '-1 0 0';
    bv_ball.velocity = '100 0 -100';
    BV_ContactZone(player, '271 0 44');
    BV_ResolveContact(player, bv_hand_position);
    BV_Assert("contact-feel-mirrors-between-baselines", fabs(clean_velocity_x + bv_contact_velocity_x) < 0.01 &&
        fabs(clean_velocity_z - bv_contact_velocity_z) < 0.01);

    BV_TestContactSetup(player, 2);
    player.bv_depth = -1;
    BV_BuildShot(player, '-600 0 80');
    height = bv_shot_velocity_z;
    BV_Predict('-600 0 80', bv_shot_velocity, bv_shot_spin);
    short_range = bv_landing_x;
    player.bv_depth = 1;
    BV_BuildShot(player, '-600 0 80');
    BV_Assert("set-depth-preserves-selected-lift", fabs(height - bv_shot_velocity_z) < 0.001);
    BV_Predict('-600 0 80', bv_shot_velocity, bv_shot_spin);
    BV_Assert("set-depth-changes-landing-at-same-power", bv_landing_x > short_range + 100);

    BV_TestContactSetup(player, 1);
    player.flags = player.flags - (player.flags & FL_ONGROUND);
    player.bv_charge = 1;
    player.bv_depth = -1;
    BV_BuildShot(player, '-600 0 130');
    speed = vlen(bv_shot_velocity);
    height = bv_shot_velocity_z;
    BV_Predict('-600 0 130', bv_shot_velocity, bv_shot_spin);
    short_range = bv_landing_x;
    player.bv_depth = 1;
    BV_BuildShot(player, '-600 0 130');
    BV_Assert("hard-short-attack-keeps-arm-speed", fabs(speed - vlen(bv_shot_velocity)) < 0.01 &&
        speed > 700 && height < -200 && bv_shot_velocity_z > 200);
    BV_Predict('-600 0 130', bv_shot_velocity, bv_shot_spin);
    BV_Assert("attack-depth-changes-flight-at-full-power", bv_landing_x > short_range + 100);

    BV_TestContactSetup(player, 1);
    self = player;
    frametime = 0.01;
    i = 0;
    while (i < 20) { player.impulse = 40; PlayerPreThink(); i = i + 1; }
    BV_Assert("short-depth-input-is-clamped", player.bv_depth == -1);
    i = 0;
    while (i < 30) { player.impulse = 41; PlayerPreThink(); i = i + 1; }
    BV_Assert("deep-depth-input-is-clamped", player.bv_depth == 1);
    player.impulse = 42;
    PlayerPreThink();
    BV_Assert("neutral-depth-input-resets-bias", player.bv_depth == 0);

    BV_TestReset(player);
    BV_BeginPreparation(player, 1);
    started = time;
    peak = 140 / autocvar_bv_gravity;
    time = started + peak;
    BV_Assert("serve-gauge-peaks-at-toss-apex", BV_Charge(player) > 0.99 && BV_ServeTiming(player) > 0.99);
    BV_ContactZone(player, '-271 0 95');
    centre = bv_hand_position;
    player.bv_charge = BV_Charge(player);
    BV_ResolveContact(player, centre);
    clean = bv_contact_quality;
    time = started + peak + 0.3;
    player.bv_charge = BV_Charge(player);
    BV_ResolveContact(player, centre);
    BV_Assert("late-serve-loses-timing-and-power", BV_Charge(player) < 0.4 &&
        bv_contact_quality < clean - 0.2 && bv_contact_reason == BV_NOTE_TIMING);
    BV_Release(player);
    BV_Assert("serve-release-cannot-bank-maximum-charge", player.bv_charge < 0.4 &&
        player.bv_armed_until > time);
    autocvar_bv_gravity = 100;
    time = started + 1.4;
    BV_Assert("serve-window-follows-low-gravity", BV_ServeTiming(player) > 0.99 && BV_Charge(player) > 0.99);
    autocvar_bv_gravity = 800;
    time = started + 0.175;
    BV_Assert("serve-window-follows-high-gravity", BV_ServeTiming(player) > 0.99 && BV_Charge(player) > 0.99);
    autocvar_bv_gravity = saved_gravity;
    time = started + 2;

    BV_TestContactSetup(player, 2);
    player.bv_preparing = 2;
    player.bv_quality = 0.73;
    saved_overlays = player.bv_overlays;
    player.bv_overlays = TRUE;
    player.bv_preview_next = 0;
    BV_UpdatePreview(player);
    landing = player.bv_preview_landing;
    BV_Assert("preview-preserves-last-contact-feedback", player.bv_quality == 0.73);
    player.bv_footing = 0;
    player.velocity = '185 0 0';
    player.bv_preview_next = 0;
    BV_UpdatePreview(player);
    BV_Assert("preview-includes-footing-loss", player.bv_preview_landing_x < landing_x - 20);
    player.bv_footing = 1;
    player.velocity = '0 0 0';
    player.bv_preview_next = 0;
    BV_UpdatePreview(player);
    landing = player.bv_preview_landing;
    BV_ContactZone(player, bv_ball.origin);
    BV_Contact(player, bv_hand_position);
    player.bv_preparing = 0;
    i = 0;
    while (bv_ball_state == BV_LIVE && i < 1000) { BV_BallStep(BV_STEP); i = i + 1; }
    BV_Assert("graded-preview-matches-centred-live-shot", bv_ball_state == BV_DEAD &&
        vlen(landing - bv_ball.origin) < 0.1);
    player.bv_overlays = saved_overlays;

    BV_TestContactSetup(player, 1);
    BV_ContactZone(player, '-271 0 44');
    aim = player.bv_aim;
    autocvar_bv_contact_kick = 0;
    BV_Contact(player, bv_hand_position);
    BV_Assert("contact-camera-pulse-can-be-disabled", player.punchangle == '0 0 0');
    autocvar_bv_contact_kick = 1;
    BV_ContactFeedback(player);
    BV_Assert("contact-camera-pulse-is-small-and-keeps-aim", player.punchangle_x < 0 &&
        vlen(player.punchangle) <= 1.5 && player.bv_aim == aim);
    BV_Assert("contact-families-use-distinct-feedback", BV_ContactSample(BV_SET, FALSE) !=
        BV_ContactSample(BV_SPIKE, FALSE) && BV_ContactSample(BV_PASS, TRUE) == "beach/dig.wav");
    autocvar_bv_contact_kick = saved_kick;
};
