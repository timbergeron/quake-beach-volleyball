// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
.float bv_match_test_started, bv_match_test_seen, bv_match_test_capture;
.float bv_match_test_predict_at, bv_match_test_intercept_at, bv_match_test_height;
.vector bv_match_test_point;
float bv_match_test_home_contacts, bv_match_test_away_contacts;
float bv_match_test_pass, bv_match_test_set, bv_match_test_attack;
float bv_match_test_bot_set, bv_match_test_bot_attack;
entity bv_match_test_last;
float bv_match_test_contact_at;

/* Drive normal human controls and movement through real server frames.
 * Bot movement, tosses, reach checks, gravity and ball collisions stay live.
 */
void() BV_MatchTestInput =
{
    local vector goal, delta, aim;
    local float height, action, distance;
    if (!self.bv_match_test_started)
    {
        self.bv_match_test_started = time;
        BV_StartMatch(self);
        if (cvar("bv_matchtest") == 2) bv_server.bv_shot_target = '-78 58 44';
        if (cvar("bv_matchtest") == 3) bv_server.bv_serve_style = BV_TOPSPIN_SERVE;
        localcmd("con_notifytime 0\ncon_notifylines 0\nscr_fade 0\n");
    }
    self.button0 = 0;
    self.button3 = 0;
    self.button2 = 0;
    self.button8 = 0;
    self.velocity_x = 0;
    self.velocity_y = 0;
    if (bv_match_phase == BV_MATCH_SERVE && bv_server == self)
    {
        self.button0 = 1;
        if (self.bv_preparing && BV_ServeTiming(self) > 0.99) self.button0 = 0;
        return;
    }
    if (bv_match_phase != BV_MATCH_RALLY || bv_home_receiver != self) return;
    /* After verifying the return, deliberately leave the next set so the
     * real floor/scoring path finishes this fixture in bounded time. */
    if (bv_match_test_away_contacts >= 3) return;
    if (cvar("bv_matchtest") == 2 && bv_match_test_bot_attack) return;
    if (bv_touch_actor == self && bv_touch_team < 0) return;
    height = 44;
    action = 1;
    self.bv_arc = 0.2;
    self.bv_depth = -1;
    if (bv_touch_team < 0 && bv_touches == 1)
    {
        height = 69;
        action = 2;
        self.bv_arc = 0.05;
    }
    if (bv_touch_team < 0 && bv_touches == 2)
    {
        height = 115;
        action = 2;
        self.bv_depth = 0;
        self.bv_arc = 0.12;
    }
    if (time >= self.bv_match_test_predict_at || self.bv_match_test_height != height)
    {
        BV_Forecast(height);
        self.bv_match_test_point = bv_intercept;
        self.bv_match_test_intercept_at = time + bv_intercept_time;
        self.bv_match_test_predict_at = time + 0.05;
        self.bv_match_test_height = height;
    }
    bv_intercept = self.bv_match_test_point;
    bv_intercept_time = self.bv_match_test_intercept_at - time;
    if (bv_intercept_x >= -10) return;
    aim = bv_partner.origin - self.origin;
    if (bv_touch_team < 0 && bv_touches == 2) aim = '1 0 0';
    self.v_angle_y = vectoyaw(aim);
    self.v_angle_x = -10;
    self.angles_y = self.v_angle_y;
    self.fixangle = TRUE;
    goal = bv_intercept - BV_Heading(self.v_angle_y) * 17;
    delta = goal - self.origin;
    delta_z = 0;
    distance = vlen(delta);
    if (distance > 3)
    {
        delta = normalize(delta) * BV_Clamp(distance * 6, 0, 170);
        self.velocity_x = delta_x;
        self.velocity_y = delta_y;
    }
    if (height == 115 && bv_intercept_time < 0.42 &&
        bv_intercept_time > 0.13 && distance < 45 && (self.flags & FL_ONGROUND))
        self.button2 = 1;
    if (action == 1) self.button0 = 1;
    else self.button3 = 1;
    if (self.bv_preparing && fabs(BV_ReceiveError(self)) < 0.025)
    {
        BV_ContactZone(self, bv_ball.origin);
        if (vlen(bv_ball.origin - bv_hand_position) < bv_hand_radius)
        {
            self.button0 = 0;
            self.button3 = 0;
        }
    }
    self.button8 = 1;
};

void() BV_MatchTestObserve =
{
    local float success;
    if (bv_touch_actor != world &&
        (bv_touch_actor != bv_match_test_last || bv_touch_actor.bv_last_contact != bv_match_test_contact_at))
    {
        bv_match_test_last = bv_touch_actor;
        bv_match_test_contact_at = bv_touch_actor.bv_last_contact;
        dprint("BEACH MATCH CONTACT team=", ftos(bv_touch_team),
            " touch=", ftos(bv_touches), " kind=", ftos(bv_touch_actor.bv_kind));
        dprint(" bot=", ftos(bv_touch_actor.bv_isbot), " quality=",
            ftos(bv_touch_actor.bv_quality), "\n");
        dprint("BEACH MATCH FLIGHT x=", ftos(bv_ball.origin_x),
            " z=", ftos(bv_ball.origin_z), "\n");
        dprint("BEACH MATCH SPEED x=", ftos(bv_ball.velocity_x), " y=", ftos(bv_ball.velocity_y),
            " z=", ftos(bv_ball.velocity_z), "\n");
        if (cvar("bv_matchtest") == 3 && bv_touch_actor.bv_kind == BV_SERVE)
        {
            if (bv_touch_actor.bv_isbot && !(bv_touch_actor.flags & FL_ONGROUND) &&
                bv_touch_actor.bv_last_speed > 17 && bv_ball_spin_y < -80 && bv_ball_float == 0)
                dprint("BEACH MATCH PASS opponent-jump-topspin\n");
            else dprint("BEACH MATCH FAIL opponent-jump-topspin\n");
        }
        if (bv_touch_team < 0) bv_match_test_home_contacts = bv_match_test_home_contacts + 1;
        else if (!bv_touch_actor.bv_serve_contact && bv_touches > 0)
            bv_match_test_away_contacts = bv_match_test_away_contacts + 1;
        if (bv_touch_actor == self)
        {
            if (self.bv_kind == BV_PASS) bv_match_test_pass = TRUE;
            if (self.bv_kind == BV_SET) bv_match_test_set = TRUE;
            if (self.bv_kind == BV_SPIKE || self.bv_kind == BV_ROLL) bv_match_test_attack = TRUE;
        }
        else
        {
            if (bv_touch_actor.bv_kind == BV_SET) bv_match_test_bot_set = TRUE;
            if (bv_touch_actor.bv_kind == BV_SPIKE || bv_touch_actor.bv_kind == BV_ROLL)
                bv_match_test_bot_attack = TRUE;
        }
    }
    if (self.bv_preparing && bv_match_phase == BV_MATCH_RALLY &&
        !self.bv_match_test_capture && time - self.bv_match_test_started > 1.7)
    {
        self.bv_match_test_capture = 1;
        localcmd("screenshot tga\n");
    }
    if (bv_match_phase >= BV_MATCH_POINT && !self.bv_match_test_seen)
    {
        self.bv_match_test_seen = time;
        success = FALSE;
        if (bv_match_test_pass && bv_match_test_attack && bv_match_test_bot_set &&
            bv_match_test_away_contacts >= 3 && bv_match_test_bot_attack)
            success = TRUE;
        if (cvar("bv_matchtest") == 2)
        {
            success = FALSE;
            if (bv_match_test_set && bv_match_test_bot_attack && bv_match_test_home_contacts >= 3)
                success = TRUE;
        }
        if (success) dprint("BEACH MATCH PASS live-receive-set-attack-return\n");
        else dprint("BEACH MATCH FAIL live-rally-sequence\n");
        if (bv_home_score + bv_away_score == 1) dprint("BEACH MATCH PASS point-scored-once\n");
        else dprint("BEACH MATCH FAIL point-score\n");
        localcmd("screenshot tga\n");
    }
    if (self.bv_match_test_seen && time > self.bv_match_test_seen + 0.3)
    {
        dprint("BEACH MATCH DONE\n");
        localcmd("quit\n");
    }
    if (time - self.bv_match_test_started > 18)
    {
        dprint("BEACH MATCH FAIL timeout\n");
        localcmd("quit\n");
    }
};
