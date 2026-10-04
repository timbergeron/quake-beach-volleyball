// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
float bv_hud_ready, bv_capture_done, bv_play_hud_reported;
float bv_play_reach_reported, bv_play_preview_reported;

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

string(float result) BV_ResultLabel =
{
    if (result == BV_RESULT_TARGET) return "TARGET";
    if (result == BV_RESULT_IN) return "IN COURT";
    if (result == BV_RESULT_OUT) return "OUT";
    if (result == BV_RESULT_OWN) return "OWN COURT";
    if (result == BV_RESULT_UNDER) return "UNDER NET";
    if (result == BV_RESULT_NET) return "NET";
    return "MISS";
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

void(vector virtual_size, float showscores) CSQC_DrawHud =
{
    local float x, y, width, charge, arc, side, mode, state, top, preview;
    local float result, age, alpha, reach, locked, compact, feed;
    local vector color;
    local string label, instruction;
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
    width = BV_Clamp(virtual_size_x - 24, 0, 500);
    compact = width < 460;
    x = (virtual_size_x - width) * 0.5;
    y = virtual_size_y - 96;
    BV_Box(x, y, width, 84, '0.025 0.055 0.07', 0.9);
    color = '0.25 0.9 0.95';
    if (locked) color = '1 0.8 0.35';
    if (reach) color = '0.4 1 0.75';
    BV_Box(x, y, 2, 84, color, 1);
    label = "SERVE PRACTICE";
    if (mode == 1) label = "RECEIVE DRILL";
    if (mode == 2) label = "SETTING DRILL";
    if (mode == 3) label = "ATTACK DRILL";
    BV_Text(x + 12, y + 10, label, '0.95 1 1');
    BV_Text(x + width - 60, y + 10, "H HELP", '0.6 0.8 0.85');
    label = "POWER ";
    if (compact) label = "PWR ";
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
    BV_Box(x + 12, y + 40, width - 24, 4, '0.15 0.23 0.26', 1);
    if (locked) BV_Box(x + 12, y + 40, (width - 24) * charge, 4, color, 1);
    label = "R READY SERVE / T FEED";
    if (state == BV_HELD) label = "HOLD LMB TO TOSS / RELEASE TO HIT";
    if (state == BV_LIVE) label = "HOLD A SHOT / TRACK THE BALL";
    if (state == BV_DEAD) label = "R SERVE / T FEED / 1-4 DRILLS";
    if (locked) label = "AIM STORED / SHIFT + LOOK TO ADJUST";
    if (reach) label = "RELEASE / BALL IN REACH";
    BV_Text(x + 12, y + 54, label, color);
    label = "WHEEL ARC / Q,E SIDE / Z TOP";
    color = '0.65 0.8 0.85';
    if (feed > 0) label = strcat("NEXT FEED ", BV_Decimal(feed), "S / T FEED NOW");
    if (preview)
    {
        label = strcat(BV_ResultLabel(preview), " / ",
            BV_Decimal(getstatf(BV_STAT_PREVIEW_RANGE)), "M / APEX ",
            BV_Decimal(getstatf(BV_STAT_PREVIEW_HEIGHT)), "M");
        color = BV_ResultColor(preview);
    }
    BV_Text(x + 12, y + 70, label, color);

    BV_Box(12, 12, 200, 48, '0.025 0.055 0.07', 0.86);
    BV_Text(24, 22, "BEACH / SOLO PRACTICE", '0.95 1 1');
    BV_Text(24, 40, strcat("TARGETS ", ftos(getstatf(BV_STAT_TARGETS)), " / ",
        ftos(getstatf(BV_STAT_ATTEMPTS))), '0.4 1 0.75');
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
            label = strcat("OFF BALANCE / ", BV_ShotName(getstatf(BV_STAT_KIND)));
            color = '1 0.8 0.35';
            instruction = "PREPARE EARLY / SET FROM STILL";
        }
        if (result)
        {
            label = BV_ResultLabel(result);
            color = BV_ResultColor(result);
            instruction = "AIM FOR THE PAINTED TARGETS";
            if (result == BV_RESULT_TARGET) instruction = "GOOD PLACEMENT";
            if (result == BV_RESULT_OUT) instruction = "ADJUST POWER AND ARC";
            if (result == BV_RESULT_OWN) instruction = "SET AGAIN OR CLEAR THE NET";
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
    if (virtual_size_x >= 480)
    {
        x = virtual_size_x - 132;
        BV_Box(x, 12, 120, 88, '0.025 0.055 0.07', 0.86);
        BV_Box(x + 12, 26, 96, 48, '0.42 0.37 0.26', 1);
        BV_Box(x + 12, 26, 96, 1, '0.35 0.8 0.9', 1);
        BV_Box(x + 12, 73, 96, 1, '0.35 0.8 0.9', 1);
        BV_Box(x + 12, 26, 1, 48, '0.35 0.8 0.9', 1);
        BV_Box(x + 107, 26, 1, 48, '0.35 0.8 0.9', 1);
        BV_Box(x + 59, 26, 2, 48, '0.95 1 1', 1);
        if (preview) BV_MapPoint(x, 12, BV_STAT_PREVIEW, BV_ResultColor(preview), TRUE);
        BV_MapPoint(x, 12, BV_STAT_PLAYER, '0.95 1 1', FALSE);
        BV_MapPoint(x, 12, BV_STAT_BALL, '1 0.8 0.35', FALSE);
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
        y = virtual_size_y * 0.5 - 102;
        BV_Box(x, y, width, 204, '0.025 0.055 0.07', 0.98);
        BV_Text(x + 12, y + 14, "BEACH / PRACTICE CONTROLS", '0.4 1 0.75');
        BV_Text(x + 12, y + 38, "LMB PASS/SPIKE / RMB SET/ROLL", '0.95 1 1');
        BV_Text(x + 12, y + 54, "HOLD TO CHARGE / RELEASE TO HIT", '0.95 1 1');
        BV_Text(x + 12, y + 70, "GREEN CUE: BALL WITHIN REACH", '0.4 1 0.75');
        BV_Text(x + 12, y + 86, "SHIFT + LOOK: CHANGE STORED AIM", '0.95 1 1');
        BV_Text(x + 12, y + 102, "WHEEL ARC / Q,E SIDE / Z TOP", '0.95 1 1');
        BV_Text(x + 12, y + 118, "MMB RESET SPIN / SPACE JUMP", '0.95 1 1');
        BV_Text(x + 12, y + 134, "CTRL DIVE / R SERVE / T FEED", '0.95 1 1');
        BV_Text(x + 12, y + 150, "1 SERVE 2 RECEIVE 3 SET 4 ATTACK", '0.95 1 1');
        BV_Text(x + 12, y + 166, "OUTLINED MAP DOT: LANDING PREVIEW", '0.65 0.8 0.85');
        BV_Text(x + 12, y + 186, "H CLOSE / TAB HOLD FOR HELP", '0.65 0.8 0.85');
    }
    if (!bv_hud_ready)
    {
        bv_hud_ready = TRUE;
        dprint("BEACH HUD READY\n");
        if (cvar("bv_visualtest") || cvar("bv_playtest"))
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
};

void(float api_level, string engine_name, float engine_version) CSQC_Init =
{
    if (checkbuiltin(loadfont)) drawfont = loadfont("beach", "gfx/bv_hud.tga", "8", 1);
    if (drawfont) dprint("BEACH HUD FONT custom\n");
    dprint("BEACH CSQC INIT\n");
};
