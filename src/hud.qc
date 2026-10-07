// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
float bv_hud_ready, bv_capture_done, bv_play_hud_reported;
float bv_play_reach_reported, bv_play_preview_reported;
float bv_play_timing_reported, bv_play_quality_reported;
float bv_match_hud_reported, bv_match_point_reported;
float bv_ui_font, bv_ui_rounded;
var float bv_ui_scale = 1;
float bv_net_hud_reported, bv_receive_hud_reported;
float(vector viewport) BV_MenuDraw;
void() BV_MenuInit;
void() BV_MenuTestFrame;

const vector BV_UI_TEXT = '0.94 0.97 0.98';
const vector BV_UI_MUTED = '0.61 0.7 0.74';
const vector BV_UI_ACCENT = '0.38 0.85 0.83';
const vector BV_UI_GOOD = '0.52 0.94 0.72';
const vector BV_UI_GOLD = '1 0.79 0.43';
const vector BV_UI_WARN = '1 0.61 0.45';
const vector BV_UI_OPPONENT = '1 0.35 0.35';

float(string text, float height) BV_TextWidth =
{
    local float i, width;
    width = 0;
    if (!bv_ui_font) return strlen(text) * height * 0.6;
    for (i = 0; i < strlen(text); i = i + 1)
        width = width + BV_GlyphAdvance(str2chr(text, i)) * height;
    return width;
};

// All text is measured in the same proportional metrics used to draw it.
// Ellipsis is a final guard for unusual viewport sizes and large score values.
void(float x, float y, string text, float height, vector color, float alpha, float width) BV_Type =
{
    local vector position, size, source;
    local float i, character, length;
    if (width <= 0 || alpha <= 0) return;
    length = strlen(text);
    if (BV_TextWidth(text, height) > width)
    {
        while (length > 0 && BV_TextWidth(strcat(substring(text, 0, length), "..."), height) > width)
            length = length - 1;
        text = strcat(substring(text, 0, length), "...");
    }
    position = '0 0 0';
    position_x = x;
    position_y = y;
    size = '1 1 0' * height;
    position = position * bv_ui_scale;
    size = size * bv_ui_scale;
    if (!bv_ui_font)
    {
        size_x = height * 0.6 * bv_ui_scale;
        drawstring(position, text, size, color, alpha, 0);
        return;
    }
    for (i = 0; i < strlen(text); i = i + 1)
    {
        character = str2chr(text, i);
        if (character < 32 || character > 126) character = 63;
        source = '0 0 0';
        source_x = (character - floor(character / 16) * 16) / 16;
        source_y = floor(character / 16) / 16;
        if (character != 32)
            drawsubpic(position, size, "gfx/bv_ui.tga", source, '0.0625 0.0625 0', color, alpha, 0);
        position_x = position_x + BV_GlyphAdvance(character) * height * bv_ui_scale;
    }
};

void(float x, float y, float width, float height, vector color, float alpha) BV_Box =
{
    local vector position, size;
    if (width <= 0 || height <= 0 || alpha <= 0) return;
    position = '0 0 0';
    size = '0 0 0';
    position_x = x;
    position_y = y;
    size_x = width;
    size_y = height;
    drawfill(position * bv_ui_scale, size * bv_ui_scale, color, alpha, 0);
};

void(float x, float y, float width, float height, float radius, vector color, float alpha) BV_RoundBox =
{
    local vector position, size;
    if (width <= 0 || height <= 0 || alpha <= 0) return;
    if (!bv_ui_rounded)
    {
        BV_Box(x, y, width, height, color, alpha);
        return;
    }
    position = '0 0 0';
    size = '0 0 0';
    position_x = x;
    position_y = y;
    size_x = width;
    size_y = height;
    drawroundedrect(position * bv_ui_scale, size * bv_ui_scale, color, alpha, radius * bv_ui_scale);
};

void(float x, float y, float width, float height, float alpha) BV_Panel =
{
    BV_RoundBox(x, y + 3, width, height, 10, '0 0 0', 0.16 * alpha);
    BV_RoundBox(x, y, width, height, 10, '0.55 0.67 0.7', 0.22 * alpha);
    BV_RoundBox(x + 0.7, y + 0.7, width - 1.4, height - 1.4, 9.3,
        '0.035 0.055 0.07', 0.94 * alpha);
};

void(float x, float y, string key, float width, float height) BV_Key =
{
    BV_RoundBox(x, y, width, height, 4, '0.14 0.19 0.22', 1);
    BV_Type(x + (width - BV_TextWidth(key, 10)) * 0.5, y + (height - 10) * 0.5,
        key, 10, BV_UI_TEXT, 1, width);
};

string(float mode) BV_ModeLabel =
{
    if (mode == 1) return "Receive drill";
    if (mode == 2) return "Setting drill";
    if (mode == 3) return "Attack drill";
    return "Serve practice";
};

string(float side) BV_SideLabel =
{
    if (fabs(side) < 0.005) return "Side 0";
    if (side < 0) return strcat("Left ", ftos(BV_Round(-side * 100)));
    return strcat("Right ", ftos(BV_Round(side * 100)));
};

string(float top) BV_TopLabel =
{
    if (top < -0.005) return strcat("Back ", ftos(BV_Round(-top * 100)));
    return strcat("Top ", ftos(BV_Round(top * 100)));
};

string(float depth) BV_DepthLabel =
{
    if (fabs(depth) < 0.005) return "Mid depth";
    if (depth < 0) return strcat("Short ", ftos(BV_Round(-depth * 100)), "%");
    return strcat("Deep ", ftos(BV_Round(depth * 100)), "%");
};

string(float result) BV_ResultLabel =
{
    if (result == BV_RESULT_TARGET) return "On target";
    if (result == BV_RESULT_IN) return "In court";
    if (result == BV_RESULT_OUT) return "Out";
    if (result == BV_RESULT_OWN) return "Own court";
    if (result == BV_RESULT_UNDER) return "Under net";
    if (result == BV_RESULT_NET) return "Net";
    if (result == BV_RESULT_ANTENNA) return "Antenna";
    return "Missed contact";
};

string(float reason) BV_PointLabel =
{
    if (reason == BV_RESULT_OUT) return "Out";
    if (reason == BV_RESULT_UNDER) return "Under net";
    if (reason == BV_RESULT_ANTENNA) return "Antenna";
    if (reason == BV_POINT_DOUBLE) return "Double contact";
    if (reason == BV_POINT_FOUR) return "Four touches";
    return "Ball down";
};

vector(float result) BV_ResultColor =
{
    if (result == BV_RESULT_TARGET || result == BV_RESULT_IN) return BV_UI_GOOD;
    return BV_UI_WARN;
};

void(float x, float y, float slot, vector color, float outline) BV_MapPoint =
{
    local float px, py;
    px = x + BV_Clamp(60 + getstatf(slot) * 96 / 512, 3, 115);
    py = y + BV_Clamp(38 + getstatf(slot + 1) * 48 / 256, 15, 68);
    BV_RoundBox(px - 2.5, py - 2.5, 5, 5, 2.5, color, 1);
    if (outline) BV_RoundBox(px - 1.3, py - 1.3, 2.6, 2.6, 1.3, '0.06 0.1 0.12', 1);
};

void(float x, float y, string key, string action, float width, float compact) BV_HelpRow =
{
    local float keywidth, keyheight;
    keywidth = 54;
    keyheight = 14;
    if (compact) { keywidth = 45; keyheight = 13; }
    BV_Key(x, y, key, keywidth, keyheight);
    BV_Type(x + keywidth + 7, y + 1, action, 11, BV_UI_TEXT, 1, width - keywidth - 7);
};

void(vector viewport) BV_Help =
{
    local float x, y, width, height, column, gap, compact, header_y, row_y;
    compact = viewport_x < 480 || viewport_y < 300;
    width = BV_Clamp(viewport_x - 24, 0, 480);
    height = 252;
    gap = 17;
    header_y = 61;
    row_y = 77;
    if (compact) { height = 228; gap = 14; header_y = 55; row_y = 71; }
    x = (viewport_x - width) * 0.5;
    y = (viewport_y - height) * 0.5;
    column = (width - 40) * 0.5;
    BV_Box(0, 0, viewport_x, viewport_y, '0.01 0.025 0.035', 0.6);
    BV_Panel(x, y, width, height, 1);
    BV_Type(x + 16, y + 12, "Play the beach.", 22, BV_UI_TEXT, 1, width - 32);
    BV_Type(x + 16, y + 38, "Aim. Prepare. Meet the ball.", 12, BV_UI_MUTED, 1, width - 32);
    BV_Type(x + 16, y + header_y, "MOVE & PLAY", 10, BV_UI_ACCENT, 1, column);
    BV_Type(x + 24 + column, y + header_y, "SHAPE YOUR SHOT", 10, BV_UI_ACCENT, 1, column);
    BV_HelpRow(x + 16, y + row_y, "WASD", "Move", column, compact);
    BV_HelpRow(x + 16, y + row_y + gap, "Mouse", "Look", column, compact);
    BV_HelpRow(x + 16, y + row_y + gap * 2, "LMB", "Pass / spike", column, compact);
    BV_HelpRow(x + 16, y + row_y + gap * 3, "RMB", "Set / roll", column, compact);
    BV_HelpRow(x + 16, y + row_y + gap * 4, "Space", "Jump", column, compact);
    BV_HelpRow(x + 16, y + row_y + gap * 5, "Ctrl", "Dive", column, compact);
    BV_HelpRow(x + 16, y + row_y + gap * 6, "Shift", "+ look to aim", column, compact);
    BV_HelpRow(x + 24 + column, y + row_y, "Wheel", "Arc", column, compact);
    BV_HelpRow(x + 24 + column, y + row_y + gap, "Q / E", "Side spin", column, compact);
    BV_HelpRow(x + 24 + column, y + row_y + gap * 2, "Z / MMB", "Spin / reset", column, compact);
    BV_HelpRow(x + 24 + column, y + row_y + gap * 3, "F / V", "Depth/cushion", column, compact);
    BV_HelpRow(x + 24 + column, y + row_y + gap * 4, "B", "Reset depth", column, compact);
    BV_HelpRow(x + 24 + column, y + row_y + gap * 5, "C", "Auto contact", column, compact);
    BV_HelpRow(x + 24 + column, y + row_y + gap * 6, "J", "Court overlay", column, compact);
    BV_HelpRow(x + 24 + column, y + row_y + gap * 7, "G", "Serve type", column, compact);
    BV_Box(x + 16, y + height - 41, width - 32, 0.5, '0.3 0.4 0.43', 0.5);
    BV_Type(x + 16, y + height - 34, "1-4 Drills    5 Doubles    R Serve    T Feed", 11, BV_UI_TEXT, 1, width - 32);
    BV_Type(x + 16, y + height - 17, "Hold a shot to prepare. Release to hit.", 10, BV_UI_MUTED, 1, width - 104);
    BV_Type(x + width - 77, y + height - 17, "H / Tab Help", 10, BV_UI_MUTED, 1, 65);
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
    local float match, phase, hint, assisted, overlays, column, hud_y, receiving, style;
    local vector color;
    local string label, instruction, footer;
    BV_MenuTestFrame();
    if (BV_MenuDraw(virtual_size)) return;
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
    result = getstatf(BV_STAT_RESULT);
    age = getstatf(BV_STAT_FEEDBACK_AGE);
    width = BV_Clamp(virtual_size_x - 24, 0, 396);
    compact = width < 360;
    x = (virtual_size_x - width) * 0.5;
    y = virtual_size_y - 130;
    hud_y = y;
    BV_Panel(x, y, width, 118, 1);
    label = BV_ModeLabel(mode);
    if (!mode)
    {
        label = "Float serve / G";
        if (style == BV_TOPSPIN_SERVE) label = "Jump topspin / G";
    }
    if (mode == 1)
    {
        label = "Receive / float";
        if (style == BV_TOPSPIN_SERVE) label = "Receive / topspin";
    }
    if (match) label = "Beach doubles";
    BV_Type(x + 14, y + 10, label, 11, BV_UI_MUTED, 1, width - 89);
    BV_Key(x + width - 61, y + 8, "H", 18, 16);
    BV_Type(x + width - 37, y + 10, "Help", 11, BV_UI_MUTED, 1, 28);

    // Strategy is useful between contacts; hand reach always gets priority
    // during preparation, including in doubles.
    label = "Prepare your shot";
    instruction = "Hold LMB to pass or RMB to set.";
    color = BV_UI_TEXT;
    if (state == BV_HELD)
    {
        label = "Hold LMB to toss";
        instruction = "Aim first. Release near the top of the toss.";
    }
    if (state == BV_DEAD)
    {
        label = "Ready for another?";
        instruction = "R to serve. T to feed a ball.";
    }
    if (match)
    {
        label = "Cover your partner";
        instruction = "Move into space and watch the ball.";
        if (hint == BV_HINT_RECEIVE)
        {
            label = "Receive the ball";
            instruction = "Hold LMB. Aim toward your blue partner.";
        }
        if (hint == BV_HINT_SET)
        {
            label = "Set your partner";
            instruction = "Hold RMB. Aim toward your blue partner.";
        }
        if (hint == BV_HINT_ATTACK)
        {
            label = "Go for the attack";
            instruction = "Jump + LMB to spike. RMB for a roll shot.";
        }
        if (phase == BV_MATCH_SERVE)
        {
            label = "Get ready to receive";
            instruction = "Red is serving. Watch the toss.";
            if (getstatf(BV_STAT_SERVE_TEAM) < 0)
            {
                label = "Your serve";
                instruction = "Hold LMB to toss. Release near the top.";
            }
        }
    }
    if (locked)
    {
        label = "Track the ball";
        instruction = "Aim saved. Shift + look to adjust.";
        if (receiving) instruction = "Aim platform. Release at your hands.";
        color = BV_UI_GOLD;
        if (assisted)
        {
            label = "Move into the ball";
            instruction = "Keep holding. Contact is automatic in reach.";
        }
    }
    if (reach)
    {
        label = "Release to hit";
        instruction = "Ball in reach. Meet it with your hands.";
        color = BV_UI_GOOD;
        if (assisted && locked)
        {
            label = "Hold for contact";
            instruction = "Keep the ball centred in your hands.";
        }
        if (serving && timing >= 0.9)
        {
            label = "Release now";
            instruction = "Sweet spot. Strike at the top of the toss.";
        }
    }
    if (match && phase == BV_MATCH_POINT)
    {
        label = BV_PointLabel(getstatf(BV_STAT_POINT_REASON));
        instruction = "Take your position for the next serve.";
        color = BV_UI_TEXT;
    }
    if (match && phase == BV_MATCH_OVER)
    {
        label = "Match complete";
        if (getstatf(BV_STAT_HOME_SCORE) > getstatf(BV_STAT_AWAY_SCORE)) label = "You win!";
        instruction = "Press 5 to play again. 1-4 for practice.";
        color = BV_UI_GOOD;
    }
    BV_RoundBox(x + 14, y + 31, 4, 17, 2, color, 1);
    BV_Type(x + 26, y + 27, label, 22, color, 1, width - 40);
    BV_Type(x + 14, y + 53, instruction, 12, BV_UI_MUTED, 1, width - 28);
    label = "Power ";
    if (receiving) label = "Timing ";
    BV_Type(x + 14, y + 72, strcat(label, ftos(BV_Round(charge * 100)), "%"),
        11, BV_UI_TEXT, 1, 75);
    BV_RoundBox(x + 94, y + 76, width - 108, 4, 2, '0.17 0.23 0.26', 1);
    if (locked)
        BV_RoundBox(x + 94, y + 76, (width - 108) * charge, 4, 2, color, 1);
    column = (width - 28) / 4;
    BV_Type(x + 14, y + 88, strcat("Arc ", ftos(BV_Round(arc * 100))), 11,
        BV_UI_MUTED, 1, column - 3);
    BV_Type(x + 14 + column, y + 88, BV_SideLabel(side), 11, BV_UI_MUTED, 1, column - 3);
    BV_Type(x + 14 + column * 2, y + 88, BV_TopLabel(top), 11, BV_UI_MUTED, 1, column - 3);
    label = BV_DepthLabel(getstatf(BV_STAT_DEPTH));
    if (receiving)
        label = strcat("Cushion ", ftos(BV_Round((getstatf(BV_STAT_DEPTH) + 1) * 50)), "%");
    BV_Type(x + 14 + column * 3, y + 88, label, 11, BV_UI_MUTED, 1, column);
    footer = "Wheel Arc    Q / E Side spin    Z Top spin";
    if (state == BV_HELD) footer = "G Serve type    Space Jump";
    if (receiving) footer = "Wheel Platform arc    F Soft    V Firm";
    color = BV_UI_MUTED;
    if (feed > 0) footer = strcat("Next ball in ", BV_Decimal(feed), "s. T to feed now.");
    if (preview && overlays)
    {
        footer = strcat("Prediction: ", BV_ResultLabel(preview), "   ",
            BV_Decimal(getstatf(BV_STAT_PREVIEW_RANGE)), "m   Apex ",
            BV_Decimal(getstatf(BV_STAT_PREVIEW_HEIGHT)), "m");
        color = BV_ResultColor(preview);
    }
    if (match && !preview)
    {
        footer = "C Auto contact off    J Court overlay";
        if (assisted) footer = "C Auto contact on    J Court overlay";
    }
    // Short viewports reuse this line for feedback instead of stacking a
    // toast over the scoreboard or the action card.
    if (virtual_size_y < 300 && age < 3 && result && !locked)
    {
        footer = BV_ResultLabel(result);
        color = BV_ResultColor(result);
    }
    BV_Type(x + 14, y + 103, footer, 11, color, 1, width - 28);

    width = 164;
    if (compact) width = 148;
    BV_Panel(12, 12, width, 70, 1);
    if (!match)
    {
        BV_Type(26, 22, "SOLO PRACTICE", 10, BV_UI_MUTED, 1, width - 28);
        label = strcat(ftos(getstatf(BV_STAT_TARGETS)), " / ", ftos(getstatf(BV_STAT_ATTEMPTS)));
        BV_Type(26, 40, label, 28, BV_UI_TEXT, 1, width - 66);
        BV_Type(12 + width - 54, 54, "targets", 11, BV_UI_ACCENT, 1, 45);
    }
    else
    {
        BV_Type(26, 21, "BEACH DOUBLES", 10, BV_UI_MUTED, 1, width - 28);
        BV_Type(26, 36, "You + blue", 10, '0.49 0.76 1', 1, 68);
        BV_Type(12 + width - 60, 36, "Red", 10, BV_UI_OPPONENT, 1, 48);
        BV_Type(26, 49, ftos(getstatf(BV_STAT_HOME_SCORE)), 26, BV_UI_TEXT, 1, 49);
        BV_Type(12 + width - 60, 49, ftos(getstatf(BV_STAT_AWAY_SCORE)), 26, BV_UI_TEXT, 1, 49);
        BV_Type(12 + width * 0.5 - 6, 54, "-", 15, BV_UI_MUTED, 1, 12);
        if (phase == BV_MATCH_RALLY && getstatf(BV_STAT_TOUCH_TEAM) < 0)
        {
            BV_RoundBox(26, 74, 5, 2, 1, BV_UI_ACCENT, 1);
            if (getstatf(BV_STAT_TOUCHES) >= 2) BV_RoundBox(34, 74, 5, 2, 1, BV_UI_ACCENT, 1);
            if (getstatf(BV_STAT_TOUCHES) >= 3) BV_RoundBox(42, 74, 5, 2, 1, BV_UI_ACCENT, 1);
        }
    }
    if (virtual_size_x >= 480 && overlays)
    {
        x = virtual_size_x - 132;
        BV_Panel(x, 12, 120, 96, 1);
        BV_Type(x + 12, 21, "COURT", 10, BV_UI_MUTED, 1, 68);
        BV_Type(x + 99, 21, "J", 10, BV_UI_MUTED, 1, 10);
        BV_Box(x + 12, 38, 96, 48, '0.27 0.3 0.28', 1);
        if (!match) BV_MapTargets(x, 24);
        BV_Box(x + 12, 38, 96, 0.7, '0.5 0.64 0.65', 1);
        BV_Box(x + 12, 85.3, 96, 0.7, '0.5 0.64 0.65', 1);
        BV_Box(x + 12, 38, 0.7, 48, '0.5 0.64 0.65', 1);
        BV_Box(x + 107.3, 38, 0.7, 48, '0.5 0.64 0.65', 1);
        BV_Box(x + 59.5, 38, 1, 48, BV_UI_TEXT, 1);
        if (preview) BV_MapPoint(x, 24, BV_STAT_PREVIEW, BV_ResultColor(preview), TRUE);
        BV_MapPoint(x, 24, BV_STAT_PLAYER, BV_UI_TEXT, FALSE);
        BV_MapPoint(x, 24, BV_STAT_BALL, BV_UI_GOLD, FALSE);
        if (match)
        {
            BV_MapPoint(x, 24, BV_STAT_PARTNER, '0.49 0.76 1', FALSE);
            BV_MapPoint(x, 24, BV_STAT_OPPONENT1, BV_UI_OPPONENT, FALSE);
            BV_MapPoint(x, 24, BV_STAT_OPPONENT2, BV_UI_OPPONENT, FALSE);
        }
        BV_RoundBox(x + 12, 96, 3, 3, 1.5, BV_UI_TEXT, 1);
        BV_Type(x + 20, 92, "You", 10, BV_UI_MUTED, 1, 28);
        BV_RoundBox(x + 66, 96, 3, 3, 1.5, BV_UI_GOLD, 1);
        BV_Type(x + 74, 92, "Ball", 10, BV_UI_MUTED, 1, 30);
    }

    if (virtual_size_y >= 300 && age < 3 && (result || getstatf(BV_STAT_KIND)))
    {
        alpha = BV_Clamp((3 - age) / 0.6, 0, 1);
        label = "Clean contact";
        color = BV_UI_GOOD;
        instruction = strcat(BV_ShotName(getstatf(BV_STAT_KIND)), "   ",
            BV_Decimal(getstatf(BV_STAT_SPEED)), " m/s");
        if (getstatf(BV_STAT_QUALITY) < 0.9)
        {
            label = "Reaching contact";
            if (getstatf(BV_STAT_QUALITY) < 0.7) label = "Glancing contact";
            color = BV_UI_GOLD;
            instruction = "Prepare early and meet the ball.";
            note = getstatf(BV_STAT_CONTACT_NOTE);
            if (note == BV_NOTE_REACH) instruction = "Move your hands under the ball.";
            if (note == BV_NOTE_FOOTING) instruction = "Get into position. Plant your feet.";
            if (note == BV_NOTE_DIVE) instruction = "Dig saved. Recover your feet.";
            if (note == BV_NOTE_TIMING) instruction = "Strike near the top of the toss.";
            if (note == BV_NOTE_EARLY) instruction = "Early release. Wait for your hands.";
            if (note == BV_NOTE_LATE) instruction = "Late release. Read the ball earlier.";
            if (note == BV_NOTE_PLATFORM) instruction = "Turn your platform into the ball.";
            if (note == BV_NOTE_ASSIST) instruction = "Release manually for control.";
        }
        if (result)
        {
            label = BV_ResultLabel(result);
            color = BV_ResultColor(result);
            instruction = "Keep it inside the court.";
            if (virtual_size_x >= 480 && overlays && !match)
                instruction = "Aim for the HUD target zones.";
            if (result == BV_RESULT_TARGET) instruction = "Good placement.";
            if (result == BV_RESULT_OUT) instruction = "Try less power or a shorter placement.";
            if (result == BV_RESULT_OWN) instruction = "Set again or clear the net.";
            if (result == BV_RESULT_ANTENNA) instruction = "Keep the ball inside the antennas.";
            if (result == BV_RESULT_MISS) instruction = "Release when the ball reaches your hands.";
            if (result == BV_RESULT_NET || result == BV_RESULT_UNDER)
                instruction = "Add arc or raise your contact.";
        }
        width = BV_Clamp(virtual_size_x - 24, 0, 284);
        x = (virtual_size_x - width) * 0.5;
        y = 94;
        if (y + 56 < hud_y - 8)
        {
            BV_Panel(x, y, width, 56, alpha);
            BV_RoundBox(x + 14, y + 15, 4, 14, 2, color, alpha);
            BV_Type(x + 26, y + 10, label, 19, color, alpha, width - 40);
            BV_Type(x + 14, y + 35, instruction, 12, BV_UI_TEXT, alpha, width - 28);
        }
    }
    color = BV_UI_TEXT;
    if (locked) color = BV_UI_GOLD;
    if (reach) color = BV_UI_GOOD;
    x = virtual_size_x * 0.5;
    y = virtual_size_y * 0.5;
    BV_RoundBox(x - 1.2, y - 1.2, 2.4, 2.4, 1.2, color, 0.9);
    if (locked)
    {
        BV_RoundBox(x - 7, y - 1, 3, 2, 1, color, 0.75);
        BV_RoundBox(x + 4, y - 1, 3, 2, 1, color, 0.75);
        BV_RoundBox(x - 1, y - 7, 2, 3, 1, color, 0.75);
        BV_RoundBox(x - 1, y + 4, 2, 3, 1, color, 0.75);
    }
    if (showscores || cvar("bv_help")) BV_Help(virtual_size);
    if (match)
    {
        if (!bv_match_hud_reported && cvar("bv_matchtest"))
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
    bv_ui_rounded = checkbuiltin(drawroundedrect);
    if (checkbuiltin(loadfont))
    {
        drawfont = loadfont("beach", "gfx/bv_hud.tga", "8", 1);
        if (checkbuiltin(drawsubpic))
            bv_ui_font = loadfont("beach-ui", "gfx/bv_ui.tga", "32", 2);
    }
    if (bv_ui_font) precache_pic("gfx/bv_ui.tga", 512);
    if (drawfont) dprint("BEACH HUD FONT custom\n");
    if (bv_ui_rounded) dprint("BEACH HUD ROUNDED native\n");
    dprint("BEACH CSQC INIT\n");
    BV_MenuInit();
};
