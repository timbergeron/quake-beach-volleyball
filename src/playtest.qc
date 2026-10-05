// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
/* Optional listen-server integration test: drive the normal input fields
 * through an actual toss, release, hand contact, flight, and landing.
 */
.float bv_play_stage, bv_play_started, bv_play_finished, bv_play_capture;
.float bv_play_contact_capture;

void() BV_PlayTestInput =
{
    local float release_at;
    if (!self.bv_play_stage)
    {
        self.bv_play_stage = 1;
        self.bv_play_started = time;
        self.impulse = 20;
        self.bv_arc = 0.35;
        self.bv_sidespin = 0;
        self.bv_topspin = 0.35;
        if (cvar("bv_playtest") == 5) self.bv_serve_style = BV_TOPSPIN_SERVE;
        if (cvar("bv_playtest") == 2) setorigin(self, '50 0 24');
    }
    self.button0 = 0;
    self.button3 = 0;
    self.button2 = 0;
    self.button8 = 0;
    release_at = 0.45;
    if (cvar("bv_playtest") == 3) release_at = 0.55;
    if (cvar("bv_playtest") == 4) release_at = 0.85;
    if (cvar("bv_playtest") == 5)
    {
        release_at = 0.77;
        if (time - self.bv_play_started >= 0.1 && time - self.bv_play_started < 0.12)
            self.button2 = 1;
    }
    if (self.bv_play_stage == 1 &&
        time - self.bv_play_started >= 0.1 &&
        time - self.bv_play_started < release_at)
        self.button0 = 1;
};

void() BV_PlayTestObserve =
{
    local float capture_at, quality_ok, landed_ok;
    capture_at = 0.3;
    if (cvar("bv_playtest") == 3) capture_at = 0.52;
    if (cvar("bv_playtest") == 4) capture_at = 0.77;
    if (cvar("bv_playtest") == 5) capture_at = 0.62;
    if (self.bv_preparing && time - self.bv_play_started > capture_at && !self.bv_play_capture)
    {
        self.bv_play_capture = TRUE;
        localcmd("con_notifytime 0\ncon_notifylines 0\nscr_fade 0\nscreenshot tga\n");
    }
    if (self.bv_play_stage == 1 && self.bv_kind == BV_SERVE)
    {
        self.bv_play_stage = 2;
        dprint("BEACH PLAY PASS serve-contact\n");
        dprint("BEACH PLAY DETAIL charge=", ftos(self.bv_charge),
               " speed=", ftos(self.bv_last_speed));
        dprint(" quality=", ftos(self.bv_quality),
               " timing=", ftos(self.bv_timing), "\n");
        quality_ok = self.bv_quality > 0.8;
        if (cvar("bv_playtest") == 3)
        {
            quality_ok = FALSE;
            if (self.bv_quality > 0.9 && self.bv_timing > 0.9) quality_ok = TRUE;
        }
        if (cvar("bv_playtest") == 4)
        {
            quality_ok = FALSE;
            if (self.bv_quality < 0.8 && self.bv_timing < 0.5 &&
                self.bv_contact_note == BV_NOTE_TIMING) quality_ok = TRUE;
        }
        if (quality_ok) dprint("BEACH PLAY PASS serve-quality\n");
        else dprint("BEACH PLAY FAIL serve-quality\n");
        if (cvar("bv_playtest") == 5)
        {
            if (!(self.flags & FL_ONGROUND) && self.bv_last_speed > 19 &&
                bv_ball_spin_y > 90 && bv_ball_float == 0)
                dprint("BEACH PLAY PASS live-jump-topspin\n");
            else dprint("BEACH PLAY FAIL live-jump-topspin\n");
        }
    }
    if (self.bv_play_stage == 2 && bv_ball_state == BV_DEAD)
    {
        if (!self.bv_play_finished)
        {
            self.bv_play_finished = time;
            dprint("BEACH PLAY DETAIL landing x=", ftos(bv_ball.origin_x),
                   " y=", ftos(bv_ball.origin_y), "\n");
            /* This FTEQCC build can lose the final store when assigning a
             * logical chain to a local. Branches keep every test meaningful.
             */
            landed_ok = FALSE;
            if (self.bv_last_result == BV_RESULT_TARGET || self.bv_last_result == BV_RESULT_IN)
                landed_ok = TRUE;
            if (cvar("bv_playtest") == 4)
            {
                if (!landed_ok) dprint("BEACH PLAY PASS late-serve-misses\n");
                else dprint("BEACH PLAY FAIL late-serve-misses\n");
            }
            else if (landed_ok) dprint("BEACH PLAY PASS serve-landed-in\n");
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
    if (self.bv_play_stage == 2 && time > self.bv_last_contact + 0.12 &&
        !self.bv_play_contact_capture)
    {
        self.bv_play_contact_capture = TRUE;
        localcmd("screenshot tga\n");
    }
    if (time - self.bv_play_started > 6 && self.bv_play_stage < 3)
    {
        self.bv_play_stage = 3;
        dprint("BEACH PLAY FAIL serve-timeout\n");
        localcmd("quit\n");
    }
};
