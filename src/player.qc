// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
void() BV_PlayTestInput;
void() BV_PlayTestObserve;
void() BV_BotTestInput;
void() BV_BotTestObserve;
void() BV_ReceiveTestInput;
void() BV_ReceiveTestObserve;

/* Shot recipes expose continuous power/arc/spin while sharing the forces.
 * Pitch at preparation adds a small launch-angle adjustment. Looking at the
 * incoming ball after preparation does not change the stored shot direction.
 */
void(entity player, vector contact) BV_BuildShot =
{
    local vector heading, launch_velocity, spin;
    local float charge, arc, speed, angle, apex, top;
    bv_shot_float = 0;
    bv_shot_phase = 0;
    if (player.bv_serve_contact)
    {
        BV_BuildServe(player, contact);
        return;
    }
    if (BV_IsReceiving(player))
    {
        BV_BuildReceive(player, contact);
        return;
    }
    if (player.bv_isbot)
    {
        BV_BotBuildShot(player, contact);
        return;
    }
    speed = 0;
    angle = 0;
    launch_velocity = '0 0 0';
    heading = player.bv_aim;
    if (vlen(heading) < 0.5) heading = BV_Heading(player.v_angle_y);
    charge = BV_Clamp(player.bv_charge, 0, 1);
    arc = BV_Clamp(player.bv_arc, 0, 1);
    top = player.bv_topspin;
    bv_shot_kind = BV_PASS;
    if (player.bv_action == 2 && !(player.flags & FL_ONGROUND) &&
             contact_z > BV_NET_HEIGHT)
    {
        bv_shot_kind = BV_ROLL;
        speed = 100 + charge * 220;
        angle = 15 + arc * 65;
        top = top * 0.4;
    }
    else if (player.bv_action == 2)
    {
        bv_shot_kind = BV_SET;
        apex = 65 + arc * 165;
        launch_velocity = heading * (12 + charge * 125);
        launch_velocity_z = sqrt(2 * BV_Clamp(autocvar_bv_gravity, 100, 800) * apex);
        top = top * 0.08;
    }
    else if (contact_z > player.origin_z + 36 &&
             (!(player.flags & FL_ONGROUND) || contact_z > BV_NET_HEIGHT))
    {
        bv_shot_kind = BV_SPIKE;
        speed = 190 + charge * 530;
        angle = BV_Clamp(-38 + arc * 93 + player.bv_depth * 28 +
            BV_Clamp(-player.bv_last_pitch, -12, 12), -75, 70);
    }
    else
    {
        apex = 32 + arc * 130;
        launch_velocity = heading * (45 + charge * 180);
        launch_velocity_z = sqrt(2 * BV_Clamp(autocvar_bv_gravity, 100, 800) * apex);
        top = top * 0.12;
    }
    if (speed > 0)
    {
        angle = angle * BV_PI / 180;
        launch_velocity = heading * (cos(angle) * speed);
        launch_velocity_z = sin(angle) * speed;
    }
    /* Depth changes travel independently of preparation/power. Attacks keep
     * their arm speed and change angle; softer strokes retain their set arc.
     */
    if (bv_shot_kind != BV_SPIKE)
    {
        launch_velocity_x = launch_velocity_x * (1 + player.bv_depth * 0.5);
        launch_velocity_y = launch_velocity_y * (1 + player.bv_depth * 0.5);
    }
    /* Sidespin bends the flight; cut/wrist direction is the stored heading.
     * Topspin rotates about the lateral axis and causes downward lift.
     */
    /* At yaw zero, camera-right is -Y: positive control bends right. */
    spin = '0 0 1' * (-player.bv_sidespin * 24);
    spin = spin + BV_Cross('0 0 1', heading) * (top * 28);
    if (bv_shot_kind == BV_SET) spin = spin * 0.12;
    if (bv_shot_kind == BV_PASS) spin = spin * 0.35;
    bv_shot_velocity = launch_velocity;
    bv_shot_spin = spin;
};

void(entity player, vector contact) BV_Contact =
{
    local vector cut_direction;
    player.bv_receive_contact = BV_IsReceiving(player);
    if (!BV_MatchContact(player))
    {
        player.bv_receive_contact = FALSE;
        return;
    }
    BV_ResolveContact(player, contact);
    player.bv_contact_latched = TRUE;
    player.bv_latch_offset = bv_hand_position - player.origin;
    player.bv_latch_radius = bv_hand_radius;
    player.bv_timing = 0;
    if (player.bv_serve_contact) player.bv_timing = BV_ServeTiming(player);
    if (player.bv_receive_contact) player.bv_timing = BV_ReceiveTiming(player);
    setorigin(bv_ball, contact);
    bv_ball.velocity = bv_contact_velocity;
    bv_ball_spin = bv_contact_spin;
    bv_ball_float = bv_shot_float;
    bv_ball_phase = bv_shot_phase;
    bv_ball_state = BV_LIVE;
    bv_live_time = 0;
    bv_last_player = player;
    bv_holder = world;
    player.bv_last_contact = time;
    player.bv_armed_until = 0;
    player.bv_preparing = 0;
    player.bv_serve_contact = 0;
    player.bv_receive_contact = FALSE;
    player.bv_receive_committed = FALSE;
    player.bv_aim_locked = FALSE;
    player.bv_kind = bv_shot_kind;
    /* A cut is a short angled attack, authored from the change in stored
     * heading during this preparation. Spin controls alone do not select it.
     * Capture at contact so looking around during recovery cannot change it.
     */
    player.bv_anim_cut = FALSE;
    if (player.bv_kind == BV_SPIKE && player.bv_depth < -0.2 &&
        player.bv_swing_aim * player.bv_aim < 0.94)
    {
        player.bv_anim_cut = 1;
        cut_direction = BV_Cross(player.bv_swing_aim, player.bv_aim);
        if (cut_direction_z < 0)
            player.bv_anim_cut = -1;
    }
    player.bv_quality = bv_contact_quality;
    player.bv_contact_note = bv_contact_reason;
    player.bv_feedback_at = time;
    player.bv_contact_side = 1;
    if (player.origin_x <= 0) player.bv_contact_side = -1;
    player.bv_last_result = 0;
    player.bv_last_speed = vlen(bv_contact_velocity) / 32;
    player.bv_message = "CONTACT";
    player.bv_recovery = 0.24;
    if (player.bv_kind == BV_SET) player.bv_recovery = 0.28;
    if (player.bv_kind == BV_ROLL) player.bv_recovery = 0.36;
    if (player.bv_kind == BV_SPIKE) player.bv_recovery = 0.5;
    if (player.bv_kind == BV_SERVE) player.bv_recovery = 0.45;
    if (player.bv_dive_until > time) player.bv_recovery = 0.75;
    player.bv_recover_until = time + player.bv_recovery;
    BV_ContactFeedback(player);
};

void(entity player) BV_ReadyServe =
{
    local vector position;
    BV_ClearContactLatches();
    bv_holder = player;
    bv_ball_state = BV_HELD;
    bv_live_time = 0;
    bv_ball.velocity = '0 0 0';
    bv_ball_spin = '0 0 0';
    bv_ball_float = 0;
    bv_ball_phase = 0;
    BV_ResetBallRotation();
    bv_ball.angles = '0 0 0';
    bv_last_player = world;
    bv_feeder = player;
    bv_next_feed = 0;
    bv_net_touched = 0;
    bv_under_net = 0;
    bv_antenna_touched = FALSE;
    player.bv_mode = 0;
    player.bv_preparing = 0;
    player.bv_armed_until = 0;
    player.bv_serve_contact = 0;
    player.bv_receive_contact = FALSE;
    player.bv_receive_committed = FALSE;
    player.bv_receiving = FALSE;
    player.bv_aim_locked = 0;
    player.bv_charge = 0;
    player.bv_timing = 0;
    player.bv_last_result = 0;
    player.bv_feedback_at = -100;
    player.bv_preview_result = 0;
    player.bv_preview_next = 0;
    if (player.bv_marker != world) player.bv_marker.modelindex = 0;
    player.bv_dive_until = 0;
    BV_ResetAnimation(player);
    player.bv_last_contact = -1;
    player.bv_recover_until = 0;
    player.view_ofs = '0 0 27';
    player.punchangle = '0 0 0';
    if (fabs(player.origin_x) < BV_HALF_LENGTH + 20)
    {
        position = player.origin;
        if (position_x <= 0) position_x = -288;
        else position_x = 288;
        position_z = 24;
        setorigin(player, position);
        player.velocity = '0 0 0';
        player.bv_footing = 1;
        player.v_angle_y = 0;
        if (position_x > 0) player.v_angle_y = 180;
        player.angles_y = player.v_angle_y;
        player.fixangle = TRUE;
    }
    player.bv_message = "SERVE - choose position; hold LMB, release to strike";
};

void(entity player, float automatic) BV_Feed =
{
    local vector start, target, launch_velocity;
    local float side, angle, speed;
    local vector heading;
    if (!player.bv_isplayer) return;
    heading = '0 0 0';
    BV_ClearContactLatches();
    if (!player.bv_mode) player.bv_mode = 1;
    side = 1;
    if (player.origin_x > 0) side = -1;
    target = player.origin + '0 0 22';
    target_x = target_x + side * 18;
    start = target;
    if (player.bv_mode == 1)
    {
        start_x = side * 288;
        start_y = BV_Clamp(player.origin_y * 0.5, -100, 100);
        start_z = 98;
        speed = 480;
        angle = 15;
        if (player.bv_serve_style == BV_TOPSPIN_SERVE)
        {
            start_z = 103;
            speed = 680;
            angle = 7;
        }
        heading = target - start;
        heading_z = 0;
        heading = normalize(heading);
        launch_velocity = heading * (cos(angle * BV_PI / 180) * speed) +
            '0 0 1' * (sin(angle * BV_PI / 180) * speed);
        player.bv_message = "RECEIVE - aim platform; release at hands; F/V cushion";
    }
    else
    {
        start_x = player.origin_x + side * 30;
        start_z = 195;
        target_z = player.origin_z + 48;
        launch_velocity = BV_BallisticVelocity(start, target, 220);
        player.bv_message = "SET - hold RMB; release as the ball reaches your hands";
        if (player.bv_mode == 3)
            player.bv_message = "ATTACK - jump, then release LMB or RMB for a roll";
    }
    setorigin(bv_ball, start);
    bv_ball.velocity = launch_velocity;
    bv_ball_spin = '0 0 0';
    bv_ball_float = 0;
    bv_ball_phase = random() * 2 * BV_PI;
    BV_ResetBallRotation();
    bv_ball.angles = '0 0 0';
    if (player.bv_mode == 1)
    {
        if (player.bv_serve_style == BV_TOPSPIN_SERVE)
            bv_ball_spin = BV_Cross('0 0 1', heading) * 110;
        else bv_ball_float = 1;
    }
    bv_ball_state = BV_LIVE;
    bv_live_time = 0;
    bv_holder = world;
    bv_last_player = world;
    bv_feeder = player;
    bv_next_feed = 0;
    bv_net_touched = 0;
    bv_under_net = 0;
    bv_antenna_touched = FALSE;
    player.bv_armed_until = 0;
    player.bv_serve_contact = 0;
    player.bv_receive_committed = FALSE;
    player.bv_receive_contact = FALSE;
    player.bv_last_contact = -1;
    player.bv_timing = 0;
    player.bv_recover_until = 0;
    if (!automatic || !player.bv_preparing)
    {
        player.bv_preparing = 0;
        player.bv_aim_locked = 0;
        player.bv_charge = 0;
    }
    player.bv_preview_result = 0;
    player.bv_preview_next = 0;
    player.bv_marker.modelindex = 0;
};

void(entity player, float action) BV_BeginPreparation =
{
    player.bv_preparing = action;
    player.bv_action = action;
    player.bv_prepare_started = time;
    player.bv_charge = 0;
    player.bv_aim = BV_Heading(player.v_angle_y);
    player.bv_swing_aim = player.bv_aim;
    player.bv_last_pitch = player.v_angle_x;
    player.bv_aim_locked = TRUE;
    player.bv_armed_until = 0;
    player.bv_receive_committed = FALSE;
    player.bv_read_direction = BV_ReadIncoming(player);
    if (bv_ball_state == BV_HELD && bv_holder == player)
    {
        player.bv_serve_contact = TRUE;
        bv_ball_state = BV_LIVE;
        bv_live_time = 0;
        setorigin(bv_ball, player.origin + player.bv_aim * 22 + '0 0 43');
        bv_ball.velocity = '0 0 1' * BV_TossSpeed(player);
        bv_ball_float = 0;
        bv_ball_phase = 0;
        player.bv_float_seed = random() * 2 * BV_PI;
        bv_holder = world;
    }
};

void(entity player) BV_Release =
{
    if (!player.bv_preparing) return;
    player.bv_charge = BV_Charge(player);
    player.bv_receive_committed = BV_IsReceiving(player);
    if (player.bv_receive_committed)
    {
        player.bv_release_error = BV_ReceiveError(player);
        player.bv_release_timing = 1 - BV_Smooth((fabs(player.bv_release_error) - 0.035) / 0.12);
    }
    player.bv_preparing = 0;
    player.bv_armed_until = time + 0.18;
};

void(entity player) BV_UpdatePreview =
{
    local vector contact, distance;
    local float side;
    if (player.bv_overlays && (player.bv_preparing || player.bv_armed_until > time))
    {
        if (time < player.bv_preview_next) return;
        player.bv_preview_next = time + 0.08;
        BV_ContactZone(player, bv_ball.origin);
        contact = bv_hand_position;
        BV_ResolveContact(player, contact);
        BV_PredictFlight(contact, bv_contact_velocity, bv_contact_spin, bv_shot_float, bv_shot_phase);
        player.bv_preview_landing = bv_landing;
        distance = bv_landing - contact;
        distance_z = 0;
        player.bv_preview_range = vlen(distance) / 32;
        player.bv_preview_height = bv_apex / 32;
        side = 1;
        if (player.origin_x <= 0) side = -1;
        player.bv_preview_result = BV_AttemptResult(bv_landing, side,
            bv_predict_net, bv_predict_under_net, bv_predict_antenna, bv_flight_time);
        setorigin(player.bv_marker, bv_landing + '0 0 -2.5');
        /* The marker is a training overlay; its projected alias shadow would
         * otherwise cover this thin ring just above the playing surface.
         */
        player.bv_marker.effects = BV_EF_FULLBRIGHT | BV_EF_NOSHADOW;
        /* setmodel restores modelindex after hiding it between shots. */
        setmodel(player.bv_marker, "progs/bv_marker.mdl");
    }
    else
    {
        player.bv_marker.modelindex = 0;
        player.bv_preview_result = 0;
    }
};

void(entity player) BV_NetVisualSetup;
void() BV_NetVisualInput;
void() BV_NetVisualObserve;
void(entity player) BV_HandVisualSetup;
void() BV_HandVisualObserve;

void() PlayerPreThink =
{
    local float action, pulse, speed, eye_height;
    local vector heading, horizontal;
    if (!self.bv_isplayer) return;
    if (cvar("bv_playtest")) BV_PlayTestInput();
    if (cvar("bv_matchtest")) BV_MatchTestInput();
    if (cvar("bv_bottest")) BV_BotTestInput();
    if (cvar("bv_receivetest")) BV_ReceiveTestInput();
    if (cvar("bv_netview")) BV_NetVisualInput();
    BV_UpdateFooting(self);
    self.gravity = BV_Clamp(autocvar_bv_gravity, 100, 800) /
                   BV_Clamp(cvar("sv_gravity"), 1, 2000);
    pulse = self.impulse;
    self.impulse = 0;
    if (pulse == 10) self.bv_arc = BV_Clamp(self.bv_arc + 0.05, 0, 1);
    if (pulse == 11) self.bv_arc = BV_Clamp(self.bv_arc - 0.05, 0, 1);
    if (pulse == 12)
    {
        self.bv_sidespin = 0;
        self.bv_topspin = 0.35;
    }
    if (pulse == 13)
    {
        self.bv_topspin = self.bv_topspin + 0.5;
        if (self.bv_topspin > 1) self.bv_topspin = -1;
    }
    if (pulse == 40) self.bv_depth = BV_Clamp(self.bv_depth - 0.1, -1, 1);
    if (pulse == 41) self.bv_depth = BV_Clamp(self.bv_depth + 0.1, -1, 1);
    if (pulse == 42) self.bv_depth = 0;
    if (pulse == 43) self.bv_assisted = !self.bv_assisted;
    if (pulse == 44) self.bv_overlays = !self.bv_overlays;
    if (pulse == 45 && !self.bv_serve_contact)
    {
        if (self.bv_serve_style == BV_TOPSPIN_SERVE) self.bv_serve_style = BV_FLOAT_SERVE;
        else self.bv_serve_style = BV_TOPSPIN_SERVE;
    }
    if (pulse == 34) BV_StartMatch(self);
    if (pulse == 30 || (pulse >= 31 && pulse <= 33)) BV_StopMatch();
    if (pulse == 30 || (pulse == 20 && !bv_match)) BV_ReadyServe(self);
    if (pulse >= 31 && pulse <= 33)
    {
        self.bv_mode = pulse - 30;
        if (self.bv_mode == 3)
        {
            setorigin(self, '-70 0 24');
            self.velocity = '0 0 0';
            self.bv_footing = 1;
            self.angles = '0 0 0';
            self.v_angle = '0 0 0';
            self.fixangle = TRUE;
        }
        BV_Feed(self, FALSE);
    }
    if (pulse == 21 && !bv_match) BV_Feed(self, FALSE);
    self.bv_sidespin = BV_Clamp(self.bv_sidespin +
        (self.button5 - self.button4) * frametime * 1.6, -1, 1);

    action = 0;
    if (self.button0 && !self.bv_previous_primary) action = 1;
    if (self.button3 && !self.bv_previous_secondary) action = 2;
    if (action && !self.bv_preparing && time >= self.bv_recover_until)
        BV_BeginPreparation(self, action);
    if (self.bv_preparing)
    {
        self.bv_charge = BV_Charge(self);
        self.bv_timing = 0;
        if (self.bv_serve_contact) self.bv_timing = BV_ServeTiming(self);
        else if (BV_IsReceiving(self)) self.bv_timing = BV_ReceiveTiming(self);
        if (self.button8)
        {
            self.bv_aim = BV_Heading(self.v_angle_y);
            self.bv_last_pitch = self.v_angle_x;
            self.bv_read_direction = BV_ReadIncoming(self);
        }
        if ((self.bv_preparing == 1 && !self.button0) ||
            (self.bv_preparing == 2 && !self.button3))
            BV_Release(self);
    }
    self.bv_previous_primary = self.button0;
    self.bv_previous_secondary = self.button3;
    if (self.bv_armed_until > 0 && time > self.bv_armed_until)
    {
        self.bv_armed_until = 0;
        self.bv_serve_contact = 0;
        self.bv_receive_committed = FALSE;
        self.bv_aim_locked = 0;
        self.bv_message = "MISS - release when the ball is within reach";
        self.bv_last_result = BV_RESULT_MISS;
        self.bv_feedback_at = time;
    }

    if (self.button2 && !self.bv_previous_jump &&
        (self.flags & FL_ONGROUND) && self.bv_dive_until <= time)
    {
        self.velocity_z = BV_JumpSpeed();
        self.flags = self.flags - (self.flags & FL_ONGROUND);
    }
    self.bv_previous_jump = self.button2;
    if (self.button7 && !self.bv_previous_dive &&
        time >= self.bv_dive_ready && (self.flags & FL_ONGROUND))
    {
        heading = BV_Heading(self.v_angle_y);
        horizontal = self.velocity;
        horizontal_z = 0;
        if (vlen(horizontal) > 20) heading = normalize(horizontal);
        self.velocity = heading * 250 + '0 0 55';
        self.flags = self.flags - (self.flags & FL_ONGROUND);
        self.bv_dive_until = time + 0.48;
        self.bv_footing = 0;
        self.bv_dive_ready = time + 1.15;
    }
    self.bv_previous_dive = self.button7;
    eye_height = 27;
    if (self.bv_dive_until > time) eye_height = 5;
    /* Ease the camera into a dive and back up without changing hand reach. */
    self.view_ofs_z = self.view_ofs_z + BV_Clamp(eye_height - self.view_ofs_z,
        -120 * frametime, 120 * frametime);
    horizontal = self.velocity;
    horizontal_z = 0;
    speed = 185;
    if (self.bv_recover_until > time) speed = 135;
    if (self.bv_dive_until > time) speed = 250;
    if (vlen(horizontal) > speed)
    {
        horizontal = normalize(horizontal) * speed;
        self.velocity_x = horizontal_x;
        self.velocity_y = horizontal_y;
    }
    self.bv_state = bv_ball_state;
    self.bv_receiving = BV_IsReceiving(self);
};

void() PlayerPostThink =
{
    local vector position;
    if (!self.bv_isplayer) return;
    position = self.origin;
    position_x = BV_Clamp(position_x, -750, 750);
    position_y = BV_Clamp(position_y, -750, 750);
    if (bv_match && self == bv_match_owner)
    {
        position_x = BV_Clamp(position_x, -340, -20);
        position_y = BV_Clamp(position_y, -180, 180);
    }
    if (position != self.origin) setorigin(self, position);
    self.bv_state = bv_ball_state;
    self.bv_feedback_age = BV_Clamp(time - self.bv_feedback_at, 0, 100);
    self.bv_feed_delay = 0;
    if (bv_feeder == self && bv_next_feed > time)
        self.bv_feed_delay = bv_next_feed - time;
    self.bv_in_reach = FALSE;
    BV_UpdateContactLatch(self, bv_ball.origin);
    if (bv_ball_state == BV_LIVE &&
        !self.bv_contact_latched &&
        (self.bv_preparing || self.bv_armed_until > time) &&
        time - self.bv_last_contact > 0.22 && time >= self.bv_recover_until &&
        BV_MatchEligible(self, bv_ball.origin))
    {
        BV_ContactZone(self, bv_ball.origin);
        if (self.bv_assisted && self.bv_preparing) bv_hand_radius = bv_hand_radius * 0.45;
        self.bv_in_reach = BV_Reachable(self, bv_ball.origin);
    }
    BV_UpdatePreview(self);
    BV_Animate(self);
    if (cvar("bv_playtest")) BV_PlayTestObserve();
    if (cvar("bv_matchtest")) BV_MatchTestObserve();
    if (cvar("bv_bottest")) BV_BotTestObserve();
    if (cvar("bv_receivetest")) BV_ReceiveTestObserve();
    if (cvar("bv_netview")) BV_NetVisualObserve();
    if (cvar("bv_handview")) BV_HandVisualObserve();
};

void() PutClientInServer =
{
    self.classname = "player";
    self.bv_isplayer = TRUE;
    self.health = 100;
    self.max_health = 100;
    self.takedamage = 0;
    self.deadflag = 0;
    self.movetype = MOVETYPE_WALK;
    self.solid = SOLID_BBOX;
    self.flags = 8;
    self.view_ofs = '0 0 27';
    self.weaponmodel = "progs/bv_hands.md3";
    BV_ResetAnimation(self);
    self.weapon = 0;
    self.items = 0;
    self.bv_arc = 0.35;
    self.bv_topspin = 0.35;
    self.bv_serve_style = BV_FLOAT_SERVE;
    self.bv_contact_side = -1;
    self.bv_last_contact = -1;
    self.bv_footing = 1;
    self.bv_overlays = TRUE;
    self.bv_message = "R SERVE | T FEED | 1-4 DRILLS | H HELP";
    setmodel(self, "progs/bv_athlete.md3");
    setsize(self, '-16 -16 -24', '16 16 32');
    setorigin(self, '-288 0 24');
    self.angles = '0 0 0';
    self.v_angle = '0 0 0';
    self.fixangle = TRUE;
    self.bv_marker = spawn();
    self.bv_marker.movetype = MOVETYPE_NONE;
    self.bv_marker.solid = SOLID_NOT;
    setmodel(self.bv_marker, "progs/bv_marker.mdl");
    self.bv_marker.modelindex = 0;
    if (bv_ball_state == BV_IDLE) BV_ReadyServe(self);
    /* Compact screenshot fixture exercises the widest spin labels and help. */
    if (cvar("bv_visualtest") == 2)
    {
        self.bv_arc = 1;
        self.bv_sidespin = -1;
        self.bv_topspin = -1;
    }
    if (cvar("bv_netview")) BV_NetVisualSetup(self);
    if (cvar("bv_handview")) BV_HandVisualSetup(self);
};

void() ClientConnect = {};
void() ClientKill =
{
    if (bv_match && self == bv_match_owner) BV_StartMatch(self);
    else if (!bv_match) BV_ReadyServe(self);
};
void() ClientDisconnect =
{
    if (self == bv_match_owner) BV_StopMatch();
    self.bv_isplayer = FALSE;
    if (self.bv_marker != world) remove(self.bv_marker);
    if (bv_holder == self) bv_holder = world;
    if (bv_last_player == self) bv_last_player = world;
    if (bv_feeder == self)
    {
        bv_feeder = world;
        bv_next_feed = 0;
        bv_ball_state = BV_IDLE;
    }
};
void() SetNewParms = {};
void() SetChangeParms = {};
