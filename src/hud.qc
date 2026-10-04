// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
float bv_hud_ready, bv_capture_done, bv_play_hud_reported;

void(float x, float y, string text, vector color) BV_Text =
{
    local vector position;
    position = '0 0 0';
    position_x = x;
    position_y = y;
    drawstring(position, text, '8 8 0', color, 1, 0);
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

void(vector virtual_size, float showscores) CSQC_DrawHud =
{
    local float x, y, width, charge, arc, side, mode, state, top;
    local string label;
    charge = getstatf(34);
    arc = getstatf(32);
    side = getstatf(33);
    state = getstatf(36);
    mode = getstatf(41);
    top = getstatf(42);
    width = BV_Clamp(virtual_size_x - 24, 280, 620);
    x = (virtual_size_x - width) * 0.5;
    y = virtual_size_y - 92;
    BV_Box(x, y, width, 80, '0.035 0.08 0.10', 0.9);
    BV_Box(x, y, 3, 80, '0.1 0.8 0.85', 1);
    label = "SERVING";
    if (mode == 1) label = "RECEIVE DRILL";
    if (mode == 2) label = "SETTING DRILL";
    if (mode == 3) label = "ATTACK DRILL";
    BV_Text(x + 12, y + 10, strcat("BEACH / ", label), '0.45 0.92 0.92');
    BV_Text(x + 12, y + 25, strcat("POWER ", ftos(floor(charge * 100)), "%"),
            '1 0.85 0.4');
    BV_Box(x + 12, y + 38, width - 24, 4, '0.18 0.24 0.25', 1);
    BV_Box(x + 12, y + 38, (width - 24) * charge, 4, '1 0.7 0.25', 1);
    BV_Text(x + 122, y + 25, strcat("ARC ", ftos(floor(arc * 100))), '0.9 0.95 1');
    BV_Text(x + 202, y + 25, strcat("SIDE ", ftos(floor(side * 100))), '0.9 0.95 1');
    if (width >= 420)
        BV_Text(x + 302, y + 25, strcat("TOP ", ftos(floor(top * 100))), '0.9 0.95 1');
    label = "R: READY SERVE";
    if (state == BV_HELD) label = "HOLD LMB TO TOSS; RELEASE TO STRIKE";
    if (state == BV_LIVE) label = "TRACK THE BALL; RELEASE WITHIN REACH";
    if (state == BV_DEAD) label = "BALL DOWN / R SERVE / T FEED";
    if (getstatf(43)) label = "AIM STORED / SHIFT + LOOK TO ADJUST";
    BV_Text(x + 12, y + 50, label, '0.8 0.86 0.88');
    BV_Text(x + 12, y + 65, "WHEEL ARC / Q,E SIDE / Z TOP / H HELP", '0.6 0.7 0.75');
    BV_Box(12, 12, 216, 39, '0.035 0.08 0.10', 0.85);
    BV_Text(22, 22, strcat("TARGETS ", ftos(getstatf(39)), " / ", ftos(getstatf(40))),
            '0.45 0.92 0.92');
    if (getstatf(35))
        BV_Text(22, 37, strcat(BV_ShotName(getstatf(35)), "  ",
                ftos(floor(getstatf(37) * 10) / 10), " m/s"), '1 0.85 0.4');
    label = "";
    if (getstatf(45) == 1) label = "TARGET HIT";
    if (getstatf(45) == 2) label = "IN / TRY A TARGET";
    if (getstatf(45) == 3) label = "OUT / ADJUST POWER AND ARC";
    if (getstatf(45) == 4) label = "OWN COURT / CHECK NET CLEARANCE";
    if (getstatf(45) == 5) label = "MISS / RELEASE WITHIN REACH";
    if (getstatf(45) == 6) label = "UNDER NET";
    BV_Text(16, 62, label, '1 0.9 0.7');
    if (virtual_size_x >= 480)
    {
        x = virtual_size_x - 108;
        BV_Box(x, 12, 96, 56, '0.035 0.08 0.10', 0.85);
        BV_Box(x + 8, 20, 80, 40, '0.35 0.30 0.20', 1);
        BV_Box(x + 47, 20, 2, 40, '0.9 0.92 0.9', 1);
        BV_Box(x + BV_Clamp(48 + getstatf(48) * 80 / 512, 8, 85),
               BV_Clamp(40 + getstatf(49) * 40 / 256, 20, 57),
               3, 3, '1 0.8 0.2', 1);
    }
    BV_Box(virtual_size_x * 0.5 - 1, virtual_size_y * 0.5 - 1,
           2, 2, '1 1 1', 0.8);
    if (showscores || cvar("bv_help"))
    {
        width = BV_Clamp(virtual_size_x - 24, 280, 360);
        x = (virtual_size_x - width) * 0.5;
        y = virtual_size_y * 0.5 - 95;
        BV_Box(x, y, width, 174, '0.025 0.06 0.08', 0.97);
        BV_Text(x + 16, y + 16, "BEACH VOLLEYBALL / PRACTICE", '0.45 0.92 0.92');
        BV_Text(x + 16, y + 38, "LMB PASS/ATTACK / RMB SET/ROLL", '1 1 1');
        BV_Text(x + 16, y + 54, "HOLD TO PREPARE; RELEASE TO HIT", '1 1 1');
        BV_Text(x + 16, y + 70, "AIM STORED WHEN PREPARING", '1 1 1');
        BV_Text(x + 16, y + 86, "SHIFT + LOOK ADJUSTS DIRECTION", '1 1 1');
        BV_Text(x + 16, y + 102, "SPACE: JUMP    CTRL: DIVE", '1 1 1');
        BV_Text(x + 16, y + 118, "R SERVE / T FEED / MMB RESET SPIN", '1 1 1');
        BV_Text(x + 16, y + 134, "1 SERVE 2 RECEIVE 3 SET 4 ATTACK", '1 1 1');
        BV_Text(x + 16, y + 150, "H: CLOSE HELP    TAB: SHOW HELP", '0.6 0.7 0.75');
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
    }
    if (cvar("bv_visualtest") && time > 2.2 && bv_capture_done == 1)
    {
        bv_capture_done = 2;
        localcmd("quit\n");
    }
    if (cvar("bv_playtest") && getstatf(35) == BV_SERVE && !bv_play_hud_reported)
    {
        bv_play_hud_reported = TRUE;
        dprint("BEACH PLAY HUD serve\n");
    }
};

void(float api_level, string engine_name, float engine_version) CSQC_Init =
{
    dprint("BEACH CSQC INIT\n");
};
