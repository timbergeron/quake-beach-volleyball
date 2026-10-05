// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
.float bv_receive_test_started, bv_receive_test_released, bv_receive_test_capture;
.float bv_receive_test_contact;

void() BV_ReceiveTestInput =
{
    local vector delta, goal;
    local float release_error;
    if (!self.bv_receive_test_started)
    {
        self.bv_receive_test_started = time;
        setorigin(self, '-185 0 24');
        self.bv_mode = 1;
        self.bv_serve_style = BV_FLOAT_SERVE;
        if (cvar("bv_receivetest") == 2 || cvar("bv_receivetest") == 4)
            self.bv_serve_style = BV_TOPSPIN_SERVE;
        self.bv_assisted = FALSE;
        self.bv_depth = -0.4;
        BV_Feed(self, FALSE);
        bv_ball_phase = 0.4;
        localcmd("con_notifytime 0\ncon_notifylines 0\nscr_fade 0\n");
    }
    self.button0 = 0;
    self.button3 = 0;
    self.button2 = 0;
    self.button8 = 0;
    self.v_angle = '0 0 0';
    self.angles = '0 0 0';
    self.fixangle = TRUE;
    self.velocity_x = 0;
    self.velocity_y = 0;
    if (bv_last_player == self) return;
    BV_Forecast(44);
    goal = bv_intercept - '17 0 0';
    delta = goal - self.origin;
    delta_z = 0;
    if (vlen(delta) > 2)
    {
        delta = normalize(delta) * BV_Clamp(vlen(delta) * 8, 0, 170);
        self.velocity_x = delta_x;
        self.velocity_y = delta_y;
    }
    if (time - self.bv_receive_test_started < 0.08 || self.bv_receive_test_released) return;
    self.button0 = 1;
    release_error = 0.015;
    if (cvar("bv_receivetest") == 3) release_error = 0.1;
    if (cvar("bv_receivetest") == 4) release_error = -0.06;
    if (self.bv_preparing && BV_ReceiveError(self) <= release_error)
    {
        self.button0 = 0;
        self.bv_receive_test_released = TRUE;
    }
};

void() BV_ReceiveTestObserve =
{
    local float good;
    if (!self.bv_receive_test_capture && self.bv_preparing &&
        time > self.bv_receive_test_started + 0.25)
    {
        self.bv_receive_test_capture = TRUE;
        localcmd("screenshot tga\n");
    }
    if (bv_last_player == self && !self.bv_receive_test_contact)
    {
        self.bv_receive_test_contact = time;
        good = FALSE;
        if (self.bv_receive_test_released && self.bv_kind == BV_PASS && bv_ball_float == 0 &&
            bv_ball.velocity_x > 0 && bv_ball.velocity_z > 20) good = TRUE;
        if (good) dprint("BEACH RECEIVE PASS manual-physical-contact\n");
        else dprint("BEACH RECEIVE FAIL contact\n");
        good = FALSE;
        if (cvar("bv_receivetest") <= 2)
        {
            if (self.bv_quality > 0.9 && self.bv_timing > 0.99) good = TRUE;
        }
        else if (cvar("bv_receivetest") == 3)
        {
            if (self.bv_quality < 0.8 && self.bv_contact_note == BV_NOTE_EARLY) good = TRUE;
        }
        else if (self.bv_quality < 0.9 && self.bv_contact_note == BV_NOTE_LATE) good = TRUE;
        if (good) dprint("BEACH RECEIVE PASS timing-and-control\n");
        else dprint("BEACH RECEIVE FAIL timing-and-control\n");
        dprint("BEACH RECEIVE DETAIL quality=", ftos(self.bv_quality),
            " timing=", ftos(self.bv_timing), " note=", ftos(self.bv_contact_note), "\n");
        localcmd("screenshot tga\n");
    }
    if (self.bv_receive_test_contact && time > self.bv_receive_test_contact + 0.3)
    {
        dprint("BEACH RECEIVE DONE\n");
        localcmd("quit\n");
    }
    if (time > self.bv_receive_test_started + 3)
    {
        dprint("BEACH RECEIVE FAIL timeout\n");
        localcmd("quit\n");
    }
};
