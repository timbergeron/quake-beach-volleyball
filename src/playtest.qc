// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Optional listen-server integration test: drive the normal input fields
 * through an actual toss, release, hand contact, flight, and landing.
 */
.float bv_play_stage, bv_play_started, bv_play_finished, bv_play_capture;

void() BV_PlayTestInput =
{
    if (!self.bv_play_stage)
    {
        self.bv_play_stage = 1;
        self.bv_play_started = time;
        self.impulse = 20;
        self.bv_arc = 0.35;
        self.bv_sidespin = 0;
        self.bv_topspin = 0.35;
        if (cvar("bv_playtest") == 2) setorigin(self, '50 0 24');
    }
    self.button0 = 0;
    self.button3 = 0;
    self.button2 = 0;
    self.button8 = 0;
    if (self.bv_play_stage == 1 &&
        time - self.bv_play_started >= 0.1 &&
        time - self.bv_play_started < 0.45)
        self.button0 = 1;
};

void() BV_PlayTestObserve =
{
    if (self.bv_preparing && time - self.bv_play_started > 0.3 && !self.bv_play_capture)
    {
        self.bv_play_capture = TRUE;
        localcmd("con_notifytime 0\ncon_notifylines 0\nscr_fade 0\nscreenshot tga\n");
    }
    if (self.bv_play_stage == 1 && self.bv_kind == BV_SERVE)
    {
        self.bv_play_stage = 2;
        dprint("BEACH PLAY PASS serve-contact\n");
        dprint("BEACH PLAY DETAIL charge=", ftos(self.bv_charge),
               " speed=", ftos(self.bv_last_speed), "\n");
    }
    if (self.bv_play_stage == 2 && bv_ball_state == BV_DEAD)
    {
        if (!self.bv_play_finished)
        {
            self.bv_play_finished = time;
            dprint("BEACH PLAY DETAIL landing x=", ftos(bv_ball.origin_x),
                   " y=", ftos(bv_ball.origin_y), "\n");
            if (self.bv_last_result == 1 || self.bv_last_result == 2)
                dprint("BEACH PLAY PASS serve-landed-in\n");
            else
                dprint("BEACH PLAY FAIL serve-landed-in result=", ftos(self.bv_last_result), "\n");
        }
        if (time > self.bv_play_finished + 0.35)
        {
            self.bv_play_stage = 3;
            dprint("BEACH PLAY DONE\n");
            localcmd("quit\n");
        }
    }
    if (time - self.bv_play_started > 6 && self.bv_play_stage < 3)
    {
        self.bv_play_stage = 3;
        dprint("BEACH PLAY FAIL serve-timeout\n");
        localcmd("quit\n");
    }
};
