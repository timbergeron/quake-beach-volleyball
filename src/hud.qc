// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
float bv_hud_ready, bv_capture_done, bv_play_hud_reported;
float bv_net_hud_reported;
float bv_play_reach_reported, bv_play_preview_reported;
float bv_play_timing_reported;
float bv_play_quality_reported;
float bv_match_hud_reported;
float bv_match_point_reported;
float bv_receive_hud_reported;

void(float x, float y, string text, vector color, float alpha) BV_Label =
{
    local vector position;
    position = '0 0 0';
    position_x = x;
    position_y = y;
    drawstring(position, text, '8 8 0', color, alpha, 0);
};

void(float x, float y, string text, vector color) BV_Text =
{
    BV_Label(x, y, text, color, 1);
};

void(float x, float y, float width, float height, vector color, float alpha) BV_Box =
{
    local vector position, size;
    position = '0 0 0';
    size = '0 0 0';
    position_x = x;
    position_y = y;
    size_x = width;
    size_y = height;
    drawfill(position, size, color, alpha, 0);
};

string(float side) BV_SideLabel =
{
    if (fabs(side) < 0.005) return "SIDE 0";
    if (side < 0) return strcat("SIDE L", ftos(BV_Round(-side * 100)));
    return strcat("SIDE R", ftos(BV_Round(side * 100)));
};

string(float top) BV_TopLabel =
{
    if (top < -0.005) return strcat("BACK ", ftos(BV_Round(-top * 100)));
    return strcat("TOP ", ftos(BV_Round(top * 100)));
};

string(float depth) BV_DepthLabel =
{
    if (fabs(depth) < 0.005) return "DEPTH MID";
    if (depth < 0) return strcat("DEPTH SHORT ", ftos(BV_Round(-depth * 100)));
    return strcat("DEPTH DEEP ", ftos(BV_Round(depth * 100)));
};

string(float result) BV_ResultLabel =
{
    if (result == BV_RESULT_TARGET) return "TARGET";
    if (result == BV_RESULT_IN) return "IN COURT";
    if (result == BV_RESULT_OUT) return "OUT";
    if (result == BV_RESULT_OWN) return "OWN COURT";
    if (result == BV_RESULT_UNDER) return "UNDER NET";
    if (result == BV_RESULT_NET) return "NET";
    if (result == BV_RESULT_ANTENNA) return "ANTENNA";
    return "MISS";
};

string(float reason) BV_PointLabel =
{
    if (reason == BV_RESULT_OUT) return "OUT";
    if (reason == BV_RESULT_UNDER) return "UNDER NET";
    if (reason == BV_RESULT_ANTENNA) return "ANTENNA";
    if (reason == BV_POINT_DOUBLE) return "DOUBLE CONTACT";
    if (reason == BV_POINT_FOUR) return "FOUR TOUCHES";
    return "BALL DOWN";
};

vector(float result) BV_ResultColor =
{
    if (result == BV_RESULT_TARGET || result == BV_RESULT_IN)
        return '0.4 1 0.75';
    return '1 0.55 0.4';
};

/* A fixed overhead court: white is you, gold is the ball, and the outlined
 * landing marker uses the same result classification as the live shot.
 */
void(float x, float y, float slot, vector color, float outline) BV_MapPoint =
{
    local float px, py;
    px = x + BV_Clamp(60 + getstatf(slot) * 96 / 512, 3, 115);
    py = y + BV_Clamp(38 + getstatf(slot + 1) * 48 / 256, 15, 68);
    BV_Box(px - 2, py - 2, 5, 5, color, 1);
    if (outline) BV_Box(px - 1, py - 1, 3, 3, '0.04 0.1 0.12', 1);
};

void(float x, float y) BV_MapTargets =
{
    local float column, row, center, px, py;
    column = 0;
    while (column < 4)
    {
        center = -208;
        if (column == 1) center = -80;
        if (column == 2) center = 80;
        if (column == 3) center = 208;
        px = x + 60 + center * 96 / 512;
        row = 0;
        while (row < 3)
        {
            py = y + 38 + (row - 1) * 92 * 48 / 256;
            BV_Box(px - 28 * 96 / 512, py - 26 * 48 / 256,
                56 * 96 / 512, 52 * 48 / 256, '0.17 0.53 0.57', 0.55);
            row = row + 1;
        }
        column = column + 1;
    }
};

void() BV_VisualCapture =
{
    if (!bv_hud_ready)
    {
        bv_hud_ready = TRUE;
        dprint("BEACH HUD READY\n");
        if (cvar("bv_visualtest") || cvar("bv_playtest") || cvar("bv_receivetest") || cvar("bv_handview"))
            localcmd("con_notifytime 0\ncon_notifylines 0\nscr_fade 0\nscr_conspeed 100000\n");
    }
    if (cvar("bv_visualtest") && time > 2 && !bv_capture_done)
    {
        bv_capture_done = 1;
        localcmd("screenshot tga\n");
        if (cvar("bv_visualtest") == 2) localcmd("set bv_help 0\n");
    }
    if (cvar("bv_visualtest") == 2 && time > 2.2 && bv_capture_done == 1)
    {
        bv_capture_done = 2;
        localcmd("screenshot tga\n");
    }
    if ((cvar("bv_visualtest") == 1 && time > 2.2 && bv_capture_done == 1) ||
        (cvar("bv_visualtest") == 2 && time > 2.4 && bv_capture_done == 2))
    {
        bv_capture_done = 3;
        localcmd("quit\n");
    }
};

void(vector virtual_size, float showscores) CSQC_DrawHud =
{
    local float x, y, width, charge, arc, side, mode, state, top, preview;
    local float result, age, alpha, reach, locked, compact, feed, serving, timing, note;
    local float match, phase, hint, assisted, overlays, receiving, style;
    local vector color;
    local string label, instruction;
    if ((cvar("bv_netview") > 0 && cvar("bv_netview") != 6) || cvar("bv_handview"))
    {
        BV_VisualCapture();
        return;
    }
    charge = BV_Clamp(getstatf(BV_STAT_CHARGE), 0, 1);
    arc = getstatf(BV_STAT_ARC);
    side = getstatf(BV_STAT_SIDE);
    state = getstatf(BV_STAT_STATE);
    mode = getstatf(BV_STAT_MODE);
    top = getstatf(BV_STAT_TOP);
    preview = getstatf(BV_STAT_PREVIEW_RESULT);
    reach = getstatf(BV_STAT_REACH);
    locked = getstatf(BV_STAT_AIM_LOCKED);
    feed = getstatf(BV_STAT_FEED_DELAY);
    serving = getstatf(BV_STAT_SERVING);
    timing = getstatf(BV_STAT_TIMING);
    match = getstatf(BV_STAT_MATCH);
    phase = getstatf(BV_STAT_PHASE);
    hint = getstatf(BV_STAT_HINT);
    assisted = getstatf(BV_STAT_ASSISTED);
    overlays = getstatf(BV_STAT_OVERLAYS);
    receiving = getstatf(BV_STAT_RECEIVING);
    style = getstatf(BV_STAT_SERVE_STYLE);
    if (receiving) charge = timing;
    width = BV_Clamp(virtual_size_x - 24, 0, 500);
    compact = width < 460;
    x = (virtual_size_x - width) * 0.5;
    y = virtual_size_y - 112;
    BV_Box(x, y, width, 100, '0.025 0.055 0.07', 0.9);
    color = '0.25 0.9 0.95';
    if (locked) color = '1 0.8 0.35';
    if (reach) color = '0.4 1 0.75';
    BV_Box(x, y, 2, 100, color, 1);
    label = "SERVE PRACTICE";
    if (mode == 1)
    {
        label = "RECEIVE / FLOAT";
        if (style == BV_TOPSPIN_SERVE) label = "RECEIVE / TOPSPIN";
    }
    if (mode == 2) label = "SETTING DRILL";
    if (mode == 3) label = "ATTACK DRILL";
    if (match) label = "BEACH DOUBLES / 2V2";
    if (!match && !mode)
    {
        label = "FLOAT SERVE / G SWITCH";
        if (style == BV_TOPSPIN_SERVE) label = "JUMP TOPSPIN / G SWITCH";
    }
    BV_Text(x + 12, y + 10, label, '0.95 1 1');
    BV_Text(x + width - 60, y + 10, "H HELP", '0.6 0.8 0.85');
    label = "POWER ";
    if (compact) label = "PWR ";
    if (receiving) label = "TIME ";
    BV_Text(x + 12, y + 26, strcat(label, ftos(BV_Round(charge * 100)), "%"), color);
    if (compact)
    {
        BV_Text(x + 84, y + 26, strcat("ARC ", ftos(BV_Round(arc * 100))), '0.9 0.97 1');
        BV_Text(x + 148, y + 26, BV_SideLabel(side), '0.9 0.97 1');
        label = "TOP";
        if (top < 0) label = "BACK";
        BV_Text(x + 224, y + 26, strcat(label, ftos(BV_Round(fabs(top) * 100))),
                '0.9 0.97 1');
    }
    else
    {
        BV_Text(x + 132, y + 26, strcat("ARC ", ftos(BV_Round(arc * 100))), '0.9 0.97 1');
        BV_Text(x + 236, y + 26, BV_SideLabel(side), '0.9 0.97 1');
        BV_Text(x + 356, y + 26, BV_TopLabel(top), '0.9 0.97 1');
    }
    label = strcat(BV_DepthLabel(getstatf(BV_STAT_DEPTH)), " / F,V,B");
    if (serving)
        label = strcat(BV_DepthLabel(getstatf(BV_STAT_DEPTH)), " / TIMING ",
            ftos(BV_Round(timing * 100)), "%");
    if (receiving)
        label = strcat("CUSHION ", ftos(BV_Round((getstatf(BV_STAT_DEPTH) + 1) * 50)),
            "% / F SOFT V FIRM");
    BV_Text(x + 12, y + 42, label, '0.9 0.97 1');
    BV_Box(x + 12, y + 56, width - 24, 4, '0.15 0.23 0.26', 1);
    if (locked) BV_Box(x + 12, y + 56, (width - 24) * charge, 4, color, 1);
    label = "R READY SERVE / T FEED";
    if (state == BV_HELD) label = "HOLD LMB TO TOSS / RELEASE TO HIT";
    if (state == BV_LIVE) label = "HOLD A SHOT / TRACK THE BALL";
    if (state == BV_DEAD) label = "R SERVE / T FEED / 1-4 DRILLS";
    if (locked) label = "AIM STORED / SHIFT + LOOK TO ADJUST";
    if (receiving && locked) label = "AIM PLATFORM / RELEASE AT HANDS";
    if (reach) label = "RELEASE / BALL IN REACH";
    if (reach && serving && timing >= 0.9) label = "RELEASE / SERVE SWEET SPOT";
    if (assisted && locked) label = "HOLD / MOVE HANDS INTO REACH";
    if (match)
    {
        label = "COVER YOUR PARTNER";
        if (hint == BV_HINT_RECEIVE) label = "RECEIVE / LMB TOWARD PARTNER";
        if (hint == BV_HINT_SET) label = "SET / RMB TOWARD PARTNER";
        if (hint == BV_HINT_ATTACK) label = "ATTACK / JUMP + LMB OR RMB";
        if (phase == BV_MATCH_SERVE)
        {
            label = "OPPONENT SERVING / GET READY";
            if (getstatf(BV_STAT_SERVE_TEAM) < 0) label = "YOUR SERVE / HOLD LMB TO TOSS";
        }
        if (phase == BV_MATCH_POINT)
            label = strcat(BV_PointLabel(getstatf(BV_STAT_POINT_REASON)), " / NEXT SERVE");
        if (phase == BV_MATCH_OVER) label = "MATCH OVER / 5 PLAY AGAIN";
    }
    BV_Text(x + 12, y + 70, label, color);
    label = "WHEEL ARC / Q,E SIDE / Z TOP";
    if (state == BV_HELD) label = "G FLOAT/TOPSPIN / SPACE JUMP";
    if (receiving) label = "WHEEL PLATFORM ARC / SHIFT REAIM";
    color = '0.65 0.8 0.85';
    if (feed > 0) label = strcat("NEXT FEED ", BV_Decimal(feed), "S / T FEED NOW");
    if (preview)
    {
        label = strcat(BV_ResultLabel(preview), " / ",
            BV_Decimal(getstatf(BV_STAT_PREVIEW_RANGE)), "M / APEX ",
            BV_Decimal(getstatf(BV_STAT_PREVIEW_HEIGHT)), "M");
        color = BV_ResultColor(preview);
    }
    if (match)
    {
        label = "C ASSIST OFF / J OVERLAYS";
        if (assisted) label = "C ASSIST ON / J OVERLAYS";
        if (bv_match_hud_reported == 0 && cvar("bv_matchtest"))
        {
            bv_match_hud_reported = TRUE;
            dprint("BEACH MATCH HUD score-and-guidance\n");
        }
        if (phase == BV_MATCH_POINT && getstatf(BV_STAT_POINT_REASON) > 0 &&
            !bv_match_point_reported && cvar("bv_matchtest"))
        {
            bv_match_point_reported = TRUE;
            dprint("BEACH MATCH HUD point-reason\n");
        }
    }
    BV_Text(x + 12, y + 86, label, color);

    BV_Box(12, 12, 200, 48, '0.025 0.055 0.07', 0.86);
    label = "BEACH / SOLO PRACTICE";
    instruction = strcat("TARGETS ", ftos(getstatf(BV_STAT_TARGETS)), " / ",
        ftos(getstatf(BV_STAT_ATTEMPTS)));
    if (match)
    {
        label = "YOU + BLUE / VS RED";
        instruction = strcat("SCORE ", ftos(getstatf(BV_STAT_HOME_SCORE)), " - ",
            ftos(getstatf(BV_STAT_AWAY_SCORE)));
        if (phase == BV_MATCH_RALLY && getstatf(BV_STAT_TOUCH_TEAM) < 0)
            instruction = strcat(instruction, " / TOUCH ", ftos(getstatf(BV_STAT_TOUCHES)), "/3");
    }
    BV_Text(24, 22, label, '0.95 1 1');
    BV_Text(24, 40, instruction, '0.4 1 0.75');
    result = getstatf(BV_STAT_RESULT);
    age = getstatf(BV_STAT_FEEDBACK_AGE);
    if (age < 3 && (result || getstatf(BV_STAT_KIND)))
    {
        alpha = BV_Clamp((3 - age) / 0.6, 0, 1);
        label = strcat("CLEAN ", BV_ShotName(getstatf(BV_STAT_KIND)));
        color = '0.4 1 0.75';
        instruction = strcat(BV_Decimal(getstatf(BV_STAT_SPEED)), " M/S");
        if (getstatf(BV_STAT_QUALITY) < 0.9)
        {
            label = strcat("REACH / ", BV_ShotName(getstatf(BV_STAT_KIND)));
            if (getstatf(BV_STAT_QUALITY) < 0.7)
                label = strcat("GLANCE / ", BV_ShotName(getstatf(BV_STAT_KIND)));
            color = '1 0.8 0.35';
            instruction = "PREPARE EARLY";
            note = getstatf(BV_STAT_CONTACT_NOTE);
            if (note == BV_NOTE_REACH) instruction = "MOVE YOUR HANDS UNDER THE BALL";
            if (note == BV_NOTE_FOOTING) instruction = "GET INTO POSITION / PLANT FEET";
            if (note == BV_NOTE_DIVE) instruction = "DIG SAVED / RECOVER YOUR FEET";
            if (note == BV_NOTE_TIMING) instruction = "STRIKE NEAR THE TOSS APEX";
            if (note == BV_NOTE_EARLY) instruction = "EARLY RELEASE / WAIT FOR HANDS";
            if (note == BV_NOTE_LATE) instruction = "LATE RELEASE / READ IT EARLIER";
            if (note == BV_NOTE_PLATFORM) instruction = "TURN PLATFORM INTO THE BALL";
            if (note == BV_NOTE_ASSIST) instruction = "RELEASE MANUALLY FOR CONTROL";
        }
        if (result)
        {
            label = BV_ResultLabel(result);
            color = BV_ResultColor(result);
            instruction = "KEEP IT INSIDE THE COURT";
            if (virtual_size_x >= 480 && overlays && !match)
                instruction = "AIM FOR THE HUD TARGET ZONES";
            if (result == BV_RESULT_TARGET) instruction = "GOOD PLACEMENT";
            if (result == BV_RESULT_OUT) instruction = "ADJUST POWER AND ARC";
            if (result == BV_RESULT_OWN) instruction = "SET AGAIN OR CLEAR THE NET";
            if (result == BV_RESULT_ANTENNA) instruction = "KEEP BALL INSIDE ANTENNAS";
            if (result == BV_RESULT_MISS) instruction = "RELEASE WHEN THE BALL IS CLOSE";
            if (result == BV_RESULT_NET || result == BV_RESULT_UNDER)
                instruction = "ADD ARC OR RAISE YOUR CONTACT";
        }
        width = BV_Clamp(virtual_size_x - 24, 0, 300);
        x = (virtual_size_x - width) * 0.5;
        BV_Box(x, 76, width, 48, '0.025 0.055 0.07', 0.86 * alpha);
        BV_Box(x, 76, 2, 48, color, alpha);
        BV_Label(x + 12, 87, label, color, alpha);
        BV_Label(x + 12, 104, instruction, '0.9 0.97 1', alpha);
    }
    if (virtual_size_x >= 480 && overlays)
    {
        x = virtual_size_x - 132;
        BV_Box(x, 12, 120, 88, '0.025 0.055 0.07', 0.86);
        BV_Box(x + 12, 26, 96, 48, '0.42 0.37 0.26', 1);
        if (!match) BV_MapTargets(x, 12);
        BV_Box(x + 12, 26, 96, 1, '0.35 0.8 0.9', 1);
        BV_Box(x + 12, 73, 96, 1, '0.35 0.8 0.9', 1);
        BV_Box(x + 12, 26, 1, 48, '0.35 0.8 0.9', 1);
        BV_Box(x + 107, 26, 1, 48, '0.35 0.8 0.9', 1);
        BV_Box(x + 59, 26, 2, 48, '0.95 1 1', 1);
        if (preview) BV_MapPoint(x, 12, BV_STAT_PREVIEW, BV_ResultColor(preview), TRUE);
        BV_MapPoint(x, 12, BV_STAT_PLAYER, '0.95 1 1', FALSE);
        BV_MapPoint(x, 12, BV_STAT_BALL, '1 0.8 0.35', FALSE);
        if (match)
        {
            BV_MapPoint(x, 12, BV_STAT_PARTNER, '0.3 0.7 1', FALSE);
            BV_MapPoint(x, 12, BV_STAT_OPPONENT1, '1 0.25 0.25', FALSE);
            BV_MapPoint(x, 12, BV_STAT_OPPONENT2, '1 0.25 0.25', FALSE);
        }
        BV_Text(x + 12, 84, "YOU", '0.95 1 1');
        BV_Text(x + 68, 84, "BALL", '1 0.8 0.35');
    }
    color = '0.95 1 1';
    if (locked) color = '1 0.8 0.35';
    if (reach) color = '0.4 1 0.75';
    x = virtual_size_x * 0.5;
    y = virtual_size_y * 0.5;
    BV_Box(x - 1, y - 1, 2, 2, color, 0.85);
    if (locked)
    {
        BV_Box(x - 6, y - 1, 2, 2, color, 0.85);
        BV_Box(x + 4, y - 1, 2, 2, color, 0.85);
        BV_Box(x - 1, y - 6, 2, 2, color, 0.85);
        BV_Box(x - 1, y + 4, 2, 2, color, 0.85);
    }
    if (showscores || cvar("bv_help"))
    {
        width = BV_Clamp(virtual_size_x - 24, 0, 344);
        x = (virtual_size_x - width) * 0.5;
        y = virtual_size_y * 0.5 - 110;
        BV_Box(x, y, width, 220, '0.025 0.055 0.07', 0.98);
        BV_Text(x + 12, y + 14, "BEACH / CONTROLS", '0.4 1 0.75');
        BV_Text(x + 12, y + 38, "LMB PASS/SPIKE / RMB SET/ROLL", '0.95 1 1');
        BV_Text(x + 12, y + 54, "HOLD TO CHARGE / RELEASE TO HIT", '0.95 1 1');
        BV_Text(x + 12, y + 70, "C ASSIST: HOLD FOR CLOSE CONTACT", '0.4 1 0.75');
        BV_Text(x + 12, y + 86, "SHIFT + LOOK: CHANGE STORED AIM", '0.95 1 1');
        BV_Text(x + 12, y + 102, "WHEEL ARC / Q,E SIDE / Z TOP", '0.95 1 1');
        BV_Text(x + 12, y + 118, "F/V DEPTH OR RECEIVE CUSHION", '0.95 1 1');
        BV_Text(x + 12, y + 134, "G SERVE TYPE / SPACE JUMP", '0.95 1 1');
        BV_Text(x + 12, y + 150, "CTRL DIVE / R SERVE / T FEED", '0.95 1 1');
        BV_Text(x + 12, y + 166, "1 SERVE 2 RECEIVE 3 SET 4 ATTACK", '0.95 1 1');
        BV_Text(x + 12, y + 182, "5 DOUBLES / J TRAINING OVERLAYS", '0.65 0.8 0.85');
        BV_Text(x + 12, y + 202, "H CLOSE / TAB HOLD FOR HELP", '0.65 0.8 0.85');
    }
    BV_VisualCapture();
    if (cvar("bv_netview") == 6 && getstatf(BV_STAT_RESULT) == BV_RESULT_ANTENNA && !bv_net_hud_reported)
    {
        bv_net_hud_reported = TRUE;
        dprint("BEACH NET HUD antenna-feedback\n");
    }
    if (cvar("bv_playtest") && getstatf(BV_STAT_KIND) == BV_SERVE && !bv_play_hud_reported)
    {
        bv_play_hud_reported = TRUE;
        dprint("BEACH PLAY HUD serve\n");
    }
    if (cvar("bv_playtest") && reach && !bv_play_reach_reported)
    {
        bv_play_reach_reported = TRUE;
        dprint("BEACH PLAY HUD reach\n");
    }
    if (cvar("bv_playtest") && preview && !bv_play_preview_reported)
    {
        bv_play_preview_reported = TRUE;
        dprint("BEACH PLAY HUD preview\n");
    }
    if (cvar("bv_playtest") && serving && timing > 0.9 && !bv_play_timing_reported)
    {
        bv_play_timing_reported = TRUE;
        dprint("BEACH PLAY HUD timing\n");
    }
    if (cvar("bv_playtest") && getstatf(BV_STAT_KIND) == BV_SERVE && age < 0.5 &&
        !bv_play_quality_reported)
    {
        if (cvar("bv_playtest") == 4)
        {
            if (getstatf(BV_STAT_QUALITY) < 0.8 &&
                getstatf(BV_STAT_CONTACT_NOTE) == BV_NOTE_TIMING)
            {
                bv_play_quality_reported = TRUE;
                dprint("BEACH PLAY HUD quality\n");
            }
        }
        else if (getstatf(BV_STAT_QUALITY) > 0.8)
        {
            bv_play_quality_reported = TRUE;
            dprint("BEACH PLAY HUD quality\n");
        }
    }
    if (cvar("bv_receivetest") && receiving && locked && !bv_receive_hud_reported)
    {
        bv_receive_hud_reported = TRUE;
        dprint("BEACH RECEIVE HUD timing-and-cushion\n");
    }
};

void(float api_level, string engine_name, float engine_version) CSQC_Init =
{
    if (checkbuiltin(loadfont)) drawfont = loadfont("beach", "gfx/bv_hud.tga", "8", 1);
    if (drawfont) dprint("BEACH HUD FONT custom\n");
    dprint("BEACH CSQC INIT\n");
};
