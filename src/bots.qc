// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
var float autocvar_bv_bot_speed = 155;
vector bv_intercept;
float bv_intercept_time;
entity bv_home_receiver, bv_away_receiver;
float bv_bot_plan_at;

/* Forecast a descending contact using the same drag, wind, spin and net
 * response as live play. This guides feet; it never changes the live ball.
 */
void(float height) BV_Forecast =
{
    local vector position, flight_velocity, spin, old;
    local float age, fraction;
    position = bv_ball.origin;
    flight_velocity = bv_ball.velocity;
    spin = bv_ball_spin;
    age = 0;
    while (age < 4)
    {
        old = position;
        BV_Integrate(position, flight_velocity, spin, BV_STEP * 2);
        position = bv_step_position;
        flight_velocity = bv_step_velocity;
        spin = bv_step_spin;
        age = age + BV_STEP * 2;
        if (BV_NetSweep(old, position))
        {
            position = bv_net_position + bv_net_normal * 0.01;
            flight_velocity = BV_Reflect(flight_velocity, bv_net_normal, 0.22, 0.65);
            spin = spin * 0.4;
        }
        if (flight_velocity_z < 0 && position_z <= height)
        {
            fraction = 1;
            if (old_z > height && old_z != position_z)
                fraction = BV_Clamp((old_z - height) / (old_z - position_z), 0, 1);
            bv_intercept = old + (position - old) * fraction;
            bv_intercept_time = age - BV_STEP * 2 * (1 - fraction);
            return;
        }
    }
    bv_intercept = position;
    bv_intercept_time = age;
};

/* Correct the ordinary ballistic estimate for drag. The result is still a
 * launch flight_velocity: every later frame is integrated and can hit the net.
 */
vector(vector contact, vector target, float apex) BV_AimArc =
{
    local vector launch, position, flight_velocity, correction;
    local float iteration, age;
    launch = BV_BallisticVelocity(contact, target, apex);
    iteration = 0;
    while (iteration < 2)
    {
        position = contact;
        flight_velocity = launch;
        age = 0;
        while (age < 3)
        {
            BV_Integrate(position, flight_velocity, '0 0 0', BV_STEP * 2);
            position = bv_step_position;
            flight_velocity = bv_step_velocity;
            age = age + BV_STEP * 2;
            if (flight_velocity_z < 0 && position_z <= target_z) break;
        }
        correction = (target - position) * (1 / BV_Clamp(age, 0.1, 3));
        correction_z = 0;
        launch = launch + correction;
        iteration = iteration + 1;
    }
    return launch;
};

void(entity player, vector contact) BV_BotBuildShot =
{
    local vector travel;
    local float duration;
    bv_shot_kind = player.bv_plan_kind;
    if (player.bv_serve_contact) bv_shot_kind = BV_SERVE;
    if (bv_shot_kind == BV_SPIKE)
    {
        travel = player.bv_shot_target - contact;
        travel_z = 0;
        duration = BV_Clamp(vlen(travel) / 500, 0.42, 1.2);
        bv_shot_velocity = (player.bv_shot_target - contact) * (1 / duration);
        bv_shot_velocity_z = bv_shot_velocity_z +
            BV_Clamp(autocvar_bv_gravity, 100, 800) * duration * 0.5;
    }
    else bv_shot_velocity = BV_AimArc(contact, player.bv_shot_target, player.bv_shot_apex);
    if (vlen(bv_shot_velocity) > 600)
        bv_shot_velocity = normalize(bv_shot_velocity) * 600;
    bv_shot_spin = '0 0 0';
};

entity(vector position, float side) BV_SpawnBot =
{
    local entity actor;
    actor = spawn();
    actor.classname = "player";
    actor.bv_isplayer = TRUE;
    actor.bv_isbot = TRUE;
    actor.bv_assisted = TRUE;
    actor.bv_footing = 1;
    actor.health = 100;
    actor.movetype = MOVETYPE_STEP;
    actor.solid = SOLID_BBOX;
    actor.flags = FL_ONGROUND;
    actor.gravity = BV_Clamp(autocvar_bv_gravity, 100, 800) /
        BV_Clamp(cvar("sv_gravity"), 1, 2000);
    actor.bv_last_contact = -1;
    actor.bv_goal = position;
    actor.v_angle_y = 0;
    if (side > 0)
    {
        actor.v_angle_y = 180;
        actor.skin = 1;
    }
    actor.angles_y = actor.v_angle_y;
    setmodel(actor, "progs/bv_athlete.mdl");
    setsize(actor, '-14 -14 -24', '14 14 32');
    setorigin(actor, position);
    return actor;
};

entity(float side, vector point) BV_SelectReceiver =
{
    local entity first, second;
    local vector delta1, delta2;
    first = bv_match_owner;
    second = bv_partner;
    if (side > 0)
    {
        first = bv_opponent1;
        second = bv_opponent2;
    }
    if (bv_touch_team == side && bv_touches > 0)
    {
        if (bv_touches >= 3) return world;
        if (bv_touch_actor == first) return second;
        return first;
    }
    delta1 = first.origin - point;
    delta2 = second.origin - point;
    delta1_z = 0;
    delta2_z = 0;
    if (vlen(delta1) <= vlen(delta2) + 15) return first;
    return second;
};

void(entity actor, float side, float forecast) BV_PlanBot =
{
    local entity receiver, partner;
    local vector point, heading, target;
    local float kind, height, attack_y;
    kind = BV_PASS;
    height = 44;
    if (bv_touch_team == side && bv_touches == 1)
    {
        kind = BV_SET;
        height = 69;
    }
    if (bv_touch_team == side && bv_touches == 2)
    {
        kind = BV_SPIKE;
        height = 115;
    }
    if (forecast) BV_Forecast(height);
    point = bv_intercept;
    receiver = BV_SelectReceiver(side, point);
    if (side < 0)
    {
        bv_home_receiver = receiver;
        if (point_x * side < 10) bv_home_receiver = world;
    }
    else
    {
        bv_away_receiver = receiver;
        if (point_x * side < 10) bv_away_receiver = world;
    }
    if (point_x * side < 10 || receiver != actor)
    {
        actor.bv_preparing = 0;
        actor.bv_armed_until = 0;
        actor.bv_goal = '0 0 24';
        actor.bv_goal_x = side * 78;
        if (actor == bv_opponent2) actor.bv_goal_x = side * 185;
        actor.bv_goal_y = 58;
        if (actor == bv_opponent1) actor.bv_goal_y = -58;
        return;
    }
    partner = bv_match_owner;
    if (side > 0)
    {
        partner = bv_opponent1;
        if (actor == partner) partner = bv_opponent2;
    }
    heading = normalize(bv_ball.origin - actor.origin);
    heading_z = 0;
    if (vlen(heading) < 0.5) heading = BV_Heading(actor.v_angle_y);
    actor.v_angle_y = vectoyaw(heading);
    actor.angles_y = actor.v_angle_y;
    actor.bv_goal = point - BV_Heading(actor.v_angle_y) * 17;
    actor.bv_goal_x = side * BV_Clamp(fabs(actor.bv_goal_x), 28, 248);
    actor.bv_goal_y = BV_Clamp(actor.bv_goal_y, -112, 112);
    actor.bv_goal_z = 24;
    actor.bv_plan_kind = kind;
    target = partner.origin;
    target_z = 69;
    actor.bv_shot_apex = 145;
    if (kind == BV_SET)
    {
        target_x = side * 65;
        target_y = BV_Clamp(partner.origin_y, -80, 80);
        target_z = 115;
        actor.bv_shot_apex = 195;
    }
    if (kind == BV_SPIKE)
    {
        attack_y = -75;
        if (side > 0 && bv_match_owner.origin_y < 0) attack_y = 75;
        if (side < 0 && bv_opponent2.origin_y < 0) attack_y = 75;
        target = '0 0 3.4';
        target_x = -side * 190;
        target_y = attack_y;
        actor.bv_shot_apex = BV_Clamp(bv_ball.origin_z + 15, 125, 180);
    }
    actor.bv_shot_target = target;
    if (!actor.bv_preparing && time >= actor.bv_recover_until)
    {
        BV_BeginPreparation(actor, 1);
    }
    actor.bv_action = 1;
    if (kind == BV_SET) actor.bv_action = 2;
    actor.bv_aim = normalize(target - actor.origin);
    actor.bv_aim_z = 0;
    if (kind == BV_SPIKE && bv_intercept_time < 0.42 &&
        bv_intercept_time > 0.12 && (actor.flags & FL_ONGROUND) &&
        time >= actor.bv_jump_ready && vlen(actor.bv_goal - actor.origin) < 45)
    {
        actor.velocity_z = 202;
        actor.flags = actor.flags - (actor.flags & FL_ONGROUND);
        actor.bv_jump_ready = time + 1;
    }
};

void(entity actor) BV_MoveBot =
{
    local entity saved;
    local vector delta, before;
    local float distance, speed;
    delta = actor.bv_goal - actor.origin;
    delta_z = 0;
    distance = vlen(delta);
    speed = BV_Clamp(autocvar_bv_bot_speed, 80, 220);
    if (actor.bv_recover_until > time) speed = speed * 0.65;
    before = actor.origin;
    actor.gravity = BV_Clamp(autocvar_bv_gravity, 100, 800) /
        BV_Clamp(cvar("sv_gravity"), 1, 2000);
    if (actor.flags & FL_ONGROUND)
    {
        if (distance > 2)
        {
            saved = self;
            self = actor;
            walkmove(vectoyaw(delta), BV_Clamp(distance, 0, speed * frametime));
            self = saved;
        }
        actor.velocity = (actor.origin - before) * (1 / BV_Clamp(frametime, 0.001, 0.25));
    }
    else
    {
        delta = normalize(delta) * BV_Clamp(distance * 4, 0, speed);
        actor.velocity_x = delta_x;
        actor.velocity_y = delta_y;
    }
    BV_UpdateFooting(actor);
    actor.bv_charge = BV_Charge(actor);
    BV_Animate(actor);
};

void() BV_UpdateBots =
{
    if (bv_match_phase >= BV_MATCH_POINT)
    {
        bv_partner.bv_preparing = 0;
        bv_opponent1.bv_preparing = 0;
        bv_opponent2.bv_preparing = 0;
        BV_Animate(bv_partner);
        BV_Animate(bv_opponent1);
        BV_Animate(bv_opponent2);
        return;
    }
    if (bv_match_phase == BV_MATCH_SERVE)
    {
        if (bv_server.bv_isbot && bv_ball_state == BV_HELD && time >= bv_server.bv_plan_next)
            BV_BeginPreparation(bv_server, 1);
        BV_Animate(bv_server);
        return;
    }
    if (time >= bv_bot_plan_at)
    {
        bv_bot_plan_at = time + 0.08;
        BV_PlanBot(bv_partner, -1, TRUE);
        BV_PlanBot(bv_opponent1, 1, TRUE);
        BV_PlanBot(bv_opponent2, 1, FALSE);
    }
    bv_match_owner.bv_match_hint = BV_HINT_COVER;
    if (bv_home_receiver == bv_match_owner)
    {
        bv_match_owner.bv_match_hint = BV_HINT_RECEIVE;
        if (bv_touch_team < 0 && bv_touches == 1) bv_match_owner.bv_match_hint = BV_HINT_SET;
        if (bv_touch_team < 0 && bv_touches == 2) bv_match_owner.bv_match_hint = BV_HINT_ATTACK;
    }
    BV_MoveBot(bv_partner);
    BV_MoveBot(bv_opponent1);
    BV_MoveBot(bv_opponent2);
};
