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
    local float age, fraction, floating, phase;
    position = bv_ball.origin;
    flight_velocity = bv_ball.velocity;
    spin = bv_ball_spin;
    floating = bv_ball_float;
    phase = bv_ball_phase;
    age = 0;
    while (age < 4)
    {
        old = position;
        BV_IntegrateFlight(position, flight_velocity, spin, BV_STEP * 2, floating, phase);
        position = bv_step_position;
        flight_velocity = bv_step_velocity;
        spin = bv_step_spin;
        phase = bv_step_phase;
        age = age + BV_STEP * 2;
        if (BV_NetSweep(old, position))
        {
            position = bv_net_position + bv_net_normal * 0.01;
            flight_velocity = BV_Reflect(flight_velocity, bv_net_normal, 0.22, 0.65);
            spin = spin * 0.4;
            floating = floating * 0.4;
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

/* Time to move into hand reach, including slower recovery movement and the
 * point at which another contact is allowed. No actor is moved by this query.
 */
float(entity actor, vector point, float reach) BV_ArrivalTime =
{
    local vector delta;
    local float distance, speed, recovery, duration;
    if (actor == world) return 4;
    delta = point - actor.origin;
    delta_z = 0;
    distance = BV_Clamp(vlen(delta) - reach, 0, 2048);
    speed = 185;
    if (actor.bv_isbot) speed = BV_Clamp(autocvar_bv_bot_speed, 80, 220);
    recovery = BV_Clamp(actor.bv_recover_until - time, 0, 4);
    duration = distance / speed;
    if (recovery > 0)
    {
        if (distance <= speed * 0.65 * recovery) duration = distance / (speed * 0.65);
        else duration = recovery + (distance - speed * 0.65 * recovery) / speed;
        if (duration < recovery) duration = recovery;
    }
    return duration;
};

void(entity player, vector contact, vector target, float kind) BV_BotTargetShot =
{
    local vector travel;
    local float duration;
    bv_shot_kind = kind;
    if (bv_shot_kind == BV_SPIKE)
    {
        travel = target - contact;
        travel_z = 0;
        duration = BV_Clamp(vlen(travel) / 500, 0.42, 1.2);
        bv_shot_velocity = (target - contact) * (1 / duration);
        bv_shot_velocity_z = bv_shot_velocity_z +
            BV_Clamp(autocvar_bv_gravity, 100, 800) * duration * 0.5;
    }
    else if (bv_shot_kind == BV_ROLL)
        bv_shot_velocity = BV_AimArc(contact, target,
            BV_Clamp(contact_z + 25, BV_NET_HEIGHT + 35, 230));
    else bv_shot_velocity = BV_AimArc(contact, target, player.bv_shot_apex);
    if (vlen(bv_shot_velocity) > 600)
        bv_shot_velocity = normalize(bv_shot_velocity) * 600;
    bv_shot_spin = '0 0 0';
};

/* Validate the actual graded flight, then score the earliest interception
 * available to either defender throughout its descending receive window.
 * A positive margin means the ball arrives before their estimated reach.
 * Simulation is bounded and occurs once at an attack contact, not every frame.
 */
float(vector contact, vector launch, vector spin, float side) BV_AttackScore =
{
    local entity first, second;
    local vector position, flight_velocity;
    local float age, margin, candidate;
    BV_Predict(contact, launch, spin);
    if (bv_predict_net || bv_predict_under_net || bv_predict_antenna || bv_flight_time >= 4 ||
        bv_landing_x * side >= -BV_RADIUS ||
        fabs(bv_landing_x) > BV_HALF_LENGTH - 8 ||
        fabs(bv_landing_y) > BV_HALF_WIDTH - 8) return -10000;
    first = bv_match_owner;
    second = bv_partner;
    if (side < 0)
    {
        first = bv_opponent1;
        second = bv_opponent2;
    }
    position = contact;
    flight_velocity = launch;
    age = 0;
    margin = 4;
    while (age < bv_flight_time)
    {
        BV_Integrate(position, flight_velocity, spin, BV_STEP * 2);
        position = bv_step_position;
        flight_velocity = bv_step_velocity;
        spin = bv_step_spin;
        age = age + BV_STEP * 2;
        if (position_x * side < 0 && flight_velocity_z < 0 && position_z <= 72)
        {
            candidate = BV_ArrivalTime(first, position, 30) + 0.12 - age;
            if (candidate < margin) margin = candidate;
            candidate = BV_ArrivalTime(second, position, 30) + 0.12 - age;
            if (candidate < margin) margin = candidate;
        }
    }
    return margin;
};

void(entity player, vector contact) BV_ChooseAttack =
{
    local vector target, best_target, best_launch, best_spin, best_aim, original_aim;
    local float side, i, kind, score, best_score, best_kind;
    side = BV_Team(player);
    original_aim = player.bv_aim;
    best_score = -10001;
    best_kind = BV_ROLL;
    best_target = player.bv_shot_target;
    best_launch = '0 0 0';
    best_spin = '0 0 0';
    best_aim = original_aim;
    BV_GradeContact(player, contact);
    i = 0;
    while (i < 9)
    {
        target = '0 0 3.4';
        target_x = -side * 80;
        if (i >= 3 && i < 6) target_x = -side * 220;
        target_y = -92 + (i - floor(i / 3) * 3) * 92;
        kind = BV_SPIKE;
        if (i >= 6)
        {
            kind = BV_ROLL;
            target_x = -side * 65;
        }
        player.bv_aim = normalize(target - contact);
        player.bv_aim_z = 0;
        player.bv_aim = normalize(player.bv_aim);
        BV_BotTargetShot(player, contact, target, kind);
        BV_ApplyContact(player, contact);
        score = BV_AttackScore(contact, bv_contact_velocity, bv_contact_spin, side);
        if (score > best_score)
        {
            best_score = score;
            best_kind = kind;
            best_target = target;
            best_launch = bv_shot_velocity;
            best_spin = bv_shot_spin;
            best_aim = player.bv_aim;
        }
        i = i + 1;
    }
    /* If poor reach or wind leaves every attack unsafe, give the ball a high
     * central roll. It still follows the same quality loss and live physics.
     */
    if (best_score == -10000)
    {
        best_target = '0 0 3.4';
        best_target_x = -side * 145;
        best_kind = BV_ROLL;
        player.bv_aim = normalize(best_target - contact);
        player.bv_aim_z = 0;
        player.bv_aim = normalize(player.bv_aim);
        BV_BotTargetShot(player, contact, best_target, best_kind);
        best_launch = bv_shot_velocity;
        best_spin = bv_shot_spin;
        best_aim = player.bv_aim;
    }
    player.bv_shot_target = best_target;
    player.bv_aim = best_aim;
    bv_shot_kind = best_kind;
    bv_shot_velocity = best_launch;
    bv_shot_spin = best_spin;
};

void(entity player, vector contact) BV_BotBuildShot =
{
    local float kind;
    kind = player.bv_plan_kind;
    if (player.bv_serve_contact) kind = BV_SERVE;
    if (kind == BV_SPIKE) BV_ChooseAttack(player, contact);
    else BV_BotTargetShot(player, contact, player.bv_shot_target, kind);
};

entity(vector position, float side) BV_SpawnBot =
{
    local entity actor;
    actor = spawn();
    actor.classname = "player";
    actor.bv_isplayer = TRUE;
    actor.bv_isbot = TRUE;
    actor.bv_assisted = TRUE;
    actor.bv_arc = 0.35;
    actor.bv_serve_style = BV_FLOAT_SERVE;
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
    }
    actor.angles_y = actor.v_angle_y;
    BV_ResetAnimation(actor);
    setmodel(actor, "progs/bv_athlete.md3");
    if (side > 0) setmodel(actor, "progs/bv_athlete_away.md3");
    setsize(actor, '-14 -14 -24', '14 14 32');
    setorigin(actor, position);
    return actor;
};

entity(float side, vector point) BV_SelectReceiver =
{
    local entity first, second;
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
    if (first.bv_dive_until > time) return first;
    if (second.bv_dive_until > time) return second;
    if (BV_ArrivalTime(first, point, 30) <= BV_ArrivalTime(second, point, 30) + 0.08)
        return first;
    return second;
};

void(entity actor) BV_FinishBotDive =
{
    if (actor.bv_dive_until > 0 && actor.bv_dive_until <= time)
    {
        actor.bv_dive_until = 0;
        actor.bv_preparing = 0;
        actor.bv_armed_until = 0;
        /* Missing the ball carries the same commitment as making the dig. */
        if (actor.bv_recover_until < actor.bv_dive_ready)
        {
            actor.bv_recover_until = actor.bv_dive_ready;
            actor.bv_recovery = 0.67;
        }
    }
};

float(entity actor, float side) BV_TryBotDive =
{
    local vector normal_point, point, delta, heading;
    local float normal_time, duration, distance;
    if (!(actor.flags & FL_ONGROUND) || time < actor.bv_dive_ready ||
        time < actor.bv_recover_until || actor.bv_dive_until > time ||
        !BV_MatchEligible(actor, bv_intercept)) return FALSE;
    if (BV_ArrivalTime(actor, bv_intercept, 30) <= bv_intercept_time + 0.04) return FALSE;
    normal_point = bv_intercept;
    normal_time = bv_intercept_time;
    BV_Forecast(26);
    point = bv_intercept;
    duration = bv_intercept_time;
    bv_intercept = normal_point;
    bv_intercept_time = normal_time;
    if (duration < 0.1 || duration > 0.48 || point_x * side < 28 ||
        point_x * side > 248 || fabs(point_y) > 112) return FALSE;
    delta = point - actor.origin;
    delta_z = 0;
    heading = normalize(delta);
    distance = vlen(delta) - 17;
    if (distance <= BV_Clamp(autocvar_bv_bot_speed, 80, 220) * duration + 14 ||
        distance > 250 * duration + 14) return FALSE;
    actor.bv_goal = point - heading * 17;
    actor.bv_goal_z = 24;
    actor.bv_dive_direction = heading;
    actor.v_angle_y = vectoyaw(heading);
    actor.angles_y = actor.v_angle_y;
    actor.velocity = heading * 250 + '0 0 55';
    actor.flags = actor.flags - (actor.flags & FL_ONGROUND);
    actor.bv_dive_until = time + 0.48;
    actor.bv_dive_ready = time + 1.15;
    actor.bv_footing = 0;
    return TRUE;
};

void(entity actor, float side, float forecast) BV_PlanBot =
{
    local entity receiver, partner;
    local vector point, heading, target;
    local float kind, height;
    BV_FinishBotDive(actor);
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
    if (actor.bv_dive_until > time) return;
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
        target = '0 0 3.4';
        target_x = -side * 190;
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
    if (kind == BV_PASS && BV_TryBotDive(actor, side)) return;
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
    BV_FinishBotDive(actor);
    delta = actor.bv_goal - actor.origin;
    delta_z = 0;
    distance = vlen(delta);
    speed = BV_Clamp(autocvar_bv_bot_speed, 80, 220);
    if (actor.bv_recover_until > time) speed = speed * 0.65;
    if (actor.bv_dive_until > time)
    {
        /* Commit to the chosen direction, braking at the original goal.
         * Airborne movement still uses the engine's ordinary collision hull.
         */
        delta = actor.bv_dive_direction;
        distance = BV_Clamp((actor.bv_goal - actor.origin) * delta, 0, 256);
        speed = BV_Clamp(distance / BV_Clamp(frametime, 0.001, 0.25), 0, 250);
        delta = delta * speed;
    }
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
        if (actor.bv_dive_until <= time)
            delta = normalize(delta) * BV_Clamp(distance * 4, 0, speed);
        actor.velocity_x = delta_x;
        actor.velocity_y = delta_y;
    }
    BV_UpdateFooting(actor);
    actor.bv_charge = BV_Charge(actor);
    BV_Animate(actor);
};

void(entity actor) BV_PauseBot =
{
    actor.bv_preparing = 0;
    actor.bv_armed_until = 0;
    actor.velocity_x = 0;
    actor.velocity_y = 0;
    BV_Animate(actor);
};

void() BV_UpdateBots =
{
    if (bv_match_phase >= BV_MATCH_POINT)
    {
        BV_PauseBot(bv_partner);
        BV_PauseBot(bv_opponent1);
        BV_PauseBot(bv_opponent2);
        return;
    }
    if (bv_match_phase == BV_MATCH_SERVE)
    {
        if (bv_server.bv_isbot && bv_ball_state == BV_HELD && time >= bv_server.bv_plan_next)
        {
            BV_BeginPreparation(bv_server, 1);
            if (bv_server.bv_serve_style == BV_TOPSPIN_SERVE)
            {
                bv_server.velocity_z = 202;
                bv_server.flags = bv_server.flags - (bv_server.flags & FL_ONGROUND);
            }
        }
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
