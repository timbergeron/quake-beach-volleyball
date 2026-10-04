// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
vector bv_shot_velocity, bv_shot_spin;
float bv_shot_kind;
void() BV_PlayTestInput;
void() BV_PlayTestObserve;

/* Shot recipes expose continuous power/arc/spin while sharing the forces.
 * Pitch at preparation adds a small launch-angle adjustment. Looking at the
 * incoming ball after preparation does not change the stored shot direction.
 */
void(entity player, vector contact) BV_BuildShot =
{
    local vector heading, launch_velocity, spin;
    local float charge, arc, speed, angle, apex, top;
    speed = 0;
    angle = 0;
    launch_velocity = '0 0 0';
    heading = player.bv_aim;
    if (vlen(heading) < 0.5) heading = BV_Heading(player.v_angle_y);
    charge = BV_Clamp(player.bv_charge, 0, 1);
    arc = BV_Clamp(player.bv_arc, 0, 1);
    top = player.bv_topspin;
    bv_shot_kind = BV_PASS;
    if (player.bv_serve_contact)
    {
        bv_shot_kind = BV_SERVE;
        speed = 220 + charge * 480;
        angle = 7 + arc * 58 + BV_Clamp(-player.bv_last_pitch, -12, 12);
    }
    else if (player.bv_action == 2 && !(player.flags & FL_ONGROUND) &&
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
        angle = -38 + arc * 93 + BV_Clamp(-player.bv_last_pitch, -12, 12);
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
    local float quality, preparation, lateral;
    local vector launch_velocity;
    BV_BuildShot(player, contact);
    preparation = BV_Clamp((time - player.bv_prepare_started) / 0.25, 0, 1);
    quality = 0.72 + preparation * 0.28;
    lateral = vlen(contact - player.origin - '0 0 32');
    if (lateral > 60) quality = quality * 0.86;
    if (vlen(player.velocity) > 150 && bv_shot_kind == BV_SET)
        quality = quality * 0.85;
    launch_velocity = bv_shot_velocity * quality;
    /* Off-balance contact loses control in a repeatable direction. */
    launch_velocity = launch_velocity + player.velocity * (0.08 * (1 - preparation));
    setorigin(bv_ball, contact);
    bv_ball.velocity = launch_velocity;
    bv_ball_spin = bv_shot_spin * quality;
    bv_ball_state = BV_LIVE;
    bv_last_player = player;
    bv_holder = world;
    player.bv_last_contact = time;
    player.bv_armed_until = 0;
    player.bv_serve_contact = 0;
    player.bv_aim_locked = FALSE;
    player.bv_kind = bv_shot_kind;
    player.bv_quality = quality;
    player.bv_contact_side = 1;
    if (player.origin_x <= 0) player.bv_contact_side = -1;
    player.bv_last_result = 0;
    player.bv_last_speed = vlen(launch_velocity) / 32;
    player.bv_message = "CONTACT";
    sound(bv_ball, 1, "beach/hit.wav", 0.6 + player.bv_charge * 0.35, 1);
};

void(entity player) BV_ReadyServe =
{
    local vector position;
    bv_holder = player;
    bv_ball_state = BV_HELD;
    bv_ball.velocity = '0 0 0';
    bv_ball_spin = '0 0 0';
    bv_last_player = world;
    bv_feeder = player;
    bv_next_feed = 0;
    bv_net_touched = 0;
    bv_under_net = 0;
    player.bv_mode = 0;
    player.bv_preparing = 0;
    player.bv_armed_until = 0;
    player.bv_serve_contact = 0;
    player.bv_aim_locked = 0;
    player.bv_charge = 0;
    player.bv_last_result = 0;
    if (fabs(player.origin_x) < BV_HALF_LENGTH + 20)
    {
        position = player.origin;
        if (position_x <= 0) position_x = -288;
        else position_x = 288;
        position_z = 24;
        setorigin(player, position);
        player.velocity = '0 0 0';
    }
    player.bv_message = "SERVE - choose position; hold LMB, release to strike";
};

void(entity player) BV_Feed =
{
    local vector start, target, launch_velocity;
    local float side;
    if (!player.bv_isplayer) return;
    if (!player.bv_mode) player.bv_mode = 1;
    side = 1;
    if (player.origin_x > 0) side = -1;
    target = player.origin + '0 0 22';
    target_x = target_x + side * 18;
    start = target;
    if (player.bv_mode == 1)
    {
        start_x = side * 190;
        start_y = BV_Clamp(player.origin_y * 0.5, -100, 100);
        start_z = 115;
        launch_velocity = BV_BallisticVelocity(start, target, 185);
        launch_velocity_x = launch_velocity_x * 1.15;
        player.bv_message = "RECEIVE - get behind the ball; prepare a pass";
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
    bv_ball_state = BV_LIVE;
    bv_holder = world;
    bv_last_player = world;
    bv_feeder = player;
    bv_next_feed = 0;
    bv_net_touched = 0;
    bv_under_net = 0;
    player.bv_armed_until = 0;
    player.bv_serve_contact = 0;
    player.bv_preparing = 0;
    player.bv_aim_locked = 0;
    player.bv_charge = 0;
    player.bv_last_result = 0;
};

void(entity player, float action) BV_BeginPreparation =
{
    player.bv_preparing = action;
    player.bv_action = action;
    player.bv_prepare_started = time;
    player.bv_charge = 0;
    player.bv_aim = BV_Heading(player.v_angle_y);
    player.bv_last_pitch = player.v_angle_x;
    player.bv_aim_locked = TRUE;
    player.bv_armed_until = 0;
    if (bv_ball_state == BV_HELD && bv_holder == player)
    {
        player.bv_serve_contact = TRUE;
        bv_ball_state = BV_LIVE;
        setorigin(bv_ball, player.origin + player.bv_aim * 22 + '0 0 43');
        bv_ball.velocity = '0 0 140';
        bv_holder = world;
    }
};

void(entity player) BV_Release =
{
    if (!player.bv_preparing) return;
    player.bv_charge = BV_Clamp((time - player.bv_prepare_started) / 0.75, 0, 1);
    player.bv_preparing = 0;
    player.bv_armed_until = time + 0.18;
};

void(entity player) BV_UpdatePreview =
{
    local vector contact;
    if (player.bv_preparing || player.bv_armed_until > time)
    {
        if (time < player.bv_preview_next) return;
        player.bv_preview_next = time + 0.08;
        contact = player.origin + player.bv_aim * 18 + '0 0 32';
        if (player.bv_action == 2) contact_z = player.origin_z + 45;
        if (player.bv_serve_contact ||
            (!(player.flags & FL_ONGROUND) && player.bv_action == 1))
            contact_z = player.origin_z + 53;
        BV_BuildShot(player, contact);
        BV_Predict(contact, bv_shot_velocity, bv_shot_spin);
        setorigin(player.bv_marker, bv_landing + '0 0 -2.5');
        /* The marker is a training overlay; its projected alias shadow would
         * otherwise cover this thin ring just above the playing surface.
         */
        player.bv_marker.effects = BV_EF_FULLBRIGHT | BV_EF_NOSHADOW;
        /* setmodel restores modelindex after hiding it between shots. */
        setmodel(player.bv_marker, "progs/bv_marker.mdl");
    }
    else player.bv_marker.modelindex = 0;
};

void() PlayerPreThink =
{
    local float action, pulse, speed;
    local vector heading, horizontal;
    if (!self.bv_isplayer) return;
    if (cvar("bv_playtest")) BV_PlayTestInput();
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
    if (pulse == 20 || pulse == 30) BV_ReadyServe(self);
    if (pulse >= 31 && pulse <= 33)
    {
        self.bv_mode = pulse - 30;
        if (self.bv_mode == 3)
        {
            setorigin(self, '-70 0 24');
            self.velocity = '0 0 0';
        }
        BV_Feed(self);
    }
    if (pulse == 21) BV_Feed(self);
    self.bv_sidespin = BV_Clamp(self.bv_sidespin +
        (self.button5 - self.button4) * frametime * 1.6, -1, 1);

    action = 0;
    if (self.button0 && !self.bv_previous_primary) action = 1;
    if (self.button3 && !self.bv_previous_secondary) action = 2;
    if (action && !self.bv_preparing) BV_BeginPreparation(self, action);
    if (self.bv_preparing)
    {
        self.bv_charge = BV_Clamp((time - self.bv_prepare_started) / 0.75, 0, 1);
        if (self.button8)
        {
            self.bv_aim = BV_Heading(self.v_angle_y);
            self.bv_last_pitch = self.v_angle_x;
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
        self.bv_aim_locked = 0;
        self.bv_message = "MISS - release when the ball is within reach";
        self.bv_last_result = 5;
    }

    if (self.button2 && !self.bv_previous_jump &&
        (self.flags & FL_ONGROUND) && self.bv_dive_until <= time)
    {
        self.velocity_z = 202;
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
        self.bv_dive_ready = time + 1.15;
    }
    self.bv_previous_dive = self.button7;
    self.view_ofs = '0 0 27';
    if (self.bv_dive_until > time) self.view_ofs = '0 0 5';
    horizontal = self.velocity;
    horizontal_z = 0;
    speed = 185;
    if (self.bv_dive_until > time) speed = 250;
    if (vlen(horizontal) > speed)
    {
        horizontal = normalize(horizontal) * speed;
        self.velocity_x = horizontal_x;
        self.velocity_y = horizontal_y;
    }
    self.bv_state = bv_ball_state;
};

void() PlayerPostThink =
{
    local vector position;
    if (!self.bv_isplayer) return;
    position = self.origin;
    position_x = BV_Clamp(position_x, -750, 750);
    position_y = BV_Clamp(position_y, -750, 750);
    if (position != self.origin) setorigin(self, position);
    self.bv_state = bv_ball_state;
    BV_UpdatePreview(self);
    if (cvar("bv_playtest")) BV_PlayTestObserve();
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
    self.weaponmodel = "";
    self.weapon = 0;
    self.items = 0;
    self.bv_arc = 0.35;
    self.bv_topspin = 0.35;
    self.bv_contact_side = -1;
    self.bv_last_contact = -1;
    self.bv_message = "R SERVE | T FEED | 1-4 DRILLS | H HELP";
    setmodel(self, "progs/player.mdl");
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
};

void() ClientConnect = {};
void() ClientKill = { BV_ReadyServe(self); };
void() ClientDisconnect =
{
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
