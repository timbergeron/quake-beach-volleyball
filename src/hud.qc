// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
float bv_hud_ready, bv_capture_done, bv_play_hud_reported;
float bv_play_reach_reported, bv_play_preview_reported;
float bv_play_timing_reported, bv_play_quality_reported;
float bv_match_hud_reported, bv_match_point_reported;
float bv_ui_font, bv_ui_rounded;
var float bv_ui_scale = 1;
// Extra training information is opt-in and independent of the landing guide.
var float autocvar_bv_court_map = 0;
var float autocvar_bv_coaching = 0;
var float autocvar_bv_shot_details = 0;
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
    BV_HelpRow(x + 24 + column, y + row_y + gap * 6, "J", "Landing guide", column, compact);
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

// On-court surfaces stay small and quiet; the menu owns persistent controls.
void(float x, float y, float width, float height, float alpha) BV_HudSurface =
{
    BV_RoundBox(x, y, width, height, 7, '0.025 0.045 0.06', 0.82 * alpha);
};

void(vector viewport) BV_HudScore =
{
    local float width, team;
    local string label;
    if (getstatf(BV_STAT_MATCH))
    {
        BV_HudSurface(12, 12, 148, 30, 1);
        BV_Type(24, 22, "YOU", 9, '0.49 0.76 1', 1, 24);
        BV_Type(52, 17, ftos(getstatf(BV_STAT_HOME_SCORE)), 19, BV_UI_TEXT, 1, 30);
        BV_Type(84, 22, "-", 10, BV_UI_MUTED, 1, 8);
        BV_Type(96, 17, ftos(getstatf(BV_STAT_AWAY_SCORE)), 19, BV_UI_TEXT, 1, 30);
        BV_Type(128, 22, "RED", 9, BV_UI_OPPONENT, 1, 24);
        team = getstatf(BV_STAT_SERVE_TEAM);
        // The small team-coloured dot marks the side serving next.
        if (team < 0) BV_RoundBox(24, 36, 3, 3, 1.5, BV_UI_ACCENT, 1);
        else BV_RoundBox(128, 36, 3, 3, 1.5, BV_UI_OPPONENT, 1);
        return;
    }
    label = BV_ModeLabel(getstatf(BV_STAT_MODE));
    width = BV_TextWidth(label, 11) + 24;
    if (autocvar_bv_shot_details)
    {
        BV_HudSurface(12, 12, width, 43, 1);
        BV_Type(24, 20, label, 11, BV_UI_TEXT, 1, width - 24);
        label = strcat(ftos(getstatf(BV_STAT_TARGETS)), " / ",
            ftos(getstatf(BV_STAT_ATTEMPTS)), " targets");
        BV_Type(24, 36, label, 9, BV_UI_MUTED, 1, width - 24);
    }
    else
    {
        BV_HudSurface(12, 12, width, 27, 1);
        BV_Type(24, 20, label, 11, BV_UI_MUTED, 1, width - 24);
    }
};

void(vector viewport) BV_HudCue =
{
    local float match, phase, state, locked, receiving, reach, serving, assisted;
    local float age, result, kind, note, width, height, x, y, row, charge, alpha;
    local vector color;
    local string label, instruction, values, forecast;
    match = getstatf(BV_STAT_MATCH);
    phase = getstatf(BV_STAT_PHASE);
    state = getstatf(BV_STAT_STATE);
    locked = getstatf(BV_STAT_AIM_LOCKED);
    receiving = getstatf(BV_STAT_RECEIVING);
    reach = getstatf(BV_STAT_REACH);
    serving = getstatf(BV_STAT_SERVING);
    assisted = getstatf(BV_STAT_ASSISTED);
    age = getstatf(BV_STAT_FEEDBACK_AGE);
    result = getstatf(BV_STAT_RESULT);
    kind = getstatf(BV_STAT_KIND);
    color = BV_UI_TEXT;
    alpha = 1;
    label = instruction = values = forecast = "";
    // Ordinary rallies need no instruction card. Coaching is a separate opt-in.
    if (autocvar_bv_coaching)
    {
        label = "Prepare your shot";
        instruction = "Hold LMB to pass or RMB to set.";
        if (match)
        {
            label = "Cover your partner";
            instruction = "Move into space and watch the ball.";
            if (getstatf(BV_STAT_HINT) == BV_HINT_RECEIVE)
            { label = "Receive"; instruction = "Aim toward your blue partner."; }
            if (getstatf(BV_STAT_HINT) == BV_HINT_SET)
            { label = "Set your partner"; instruction = "Hold RMB. Lift toward your partner."; }
            if (getstatf(BV_STAT_HINT) == BV_HINT_ATTACK)
            { label = "Attack"; instruction = "Jump + LMB to spike. RMB to roll."; }
        }
    }
    if (state == BV_HELD)
    {
        label = "Your serve";
        instruction = "Hold LMB to toss. Release near the top.";
        if (getstatf(BV_STAT_SERVE_STYLE) == BV_TOPSPIN_SERVE) label = "Jump serve";
    }
    if (!match && state == BV_DEAD && getstatf(BV_STAT_FEED_DELAY) <= 0)
    { label = "Ready for another?"; instruction = "R to serve. T to feed a ball."; }
    if (locked)
    {
        label = "Track the ball";
        instruction = "Aim saved. Shift + look to adjust.";
        color = BV_UI_GOLD;
        if (receiving)
        { label = "Meet the ball"; instruction = "Release as it reaches your hands."; }
        if (assisted)
        { label = "Hold for contact"; instruction = "Move into the ball. Keep holding."; }
    }
    if (reach && locked)
    {
        label = "Release to hit";
        color = BV_UI_GOOD;
        if (assisted) label = "Hold for contact";
        if (serving && getstatf(BV_STAT_TIMING) >= 0.9) label = "Release now";
    }
    if (!autocvar_bv_coaching) instruction = "";
    // Practice feedback shares the same slot as the action cue. It never
    // creates a second card across the flight of the ball or the net.
    if (!match && !locked && state != BV_HELD && age < 2.4 && (result || kind))
    {
        alpha = BV_Clamp((2.4 - age) / 0.45, 0, 1);
        label = "Clean contact";
        color = BV_UI_GOOD;
        instruction = "";
        if (getstatf(BV_STAT_QUALITY) < 0.9)
        {
            label = "Reaching contact";
            color = BV_UI_GOLD;
            if (getstatf(BV_STAT_QUALITY) < 0.7) label = "Glancing contact";
            if (autocvar_bv_coaching)
            {
                instruction = "Prepare early and meet the ball.";
                note = getstatf(BV_STAT_CONTACT_NOTE);
                if (note == BV_NOTE_REACH) instruction = "Move your hands under the ball.";
                if (note == BV_NOTE_FOOTING) instruction = "Get into position. Plant your feet.";
                if (note == BV_NOTE_DIVE) instruction = "Dig saved. Recover your feet.";
                if (note == BV_NOTE_TIMING) instruction = "Strike near the top of the toss.";
                if (note == BV_NOTE_EARLY) instruction = "Early. Wait for it to reach your hands.";
                if (note == BV_NOTE_LATE) instruction = "Late. Read the ball earlier.";
                if (note == BV_NOTE_PLATFORM) instruction = "Turn your platform into the ball.";
                if (note == BV_NOTE_ASSIST) instruction = "Release manually for more control.";
            }
        }
        if (result)
        {
            label = BV_ResultLabel(result);
            color = BV_ResultColor(result);
            if (autocvar_bv_coaching)
            {
                instruction = "Keep it inside the court.";
                if (result == BV_RESULT_TARGET) instruction = "Good placement.";
                if (result == BV_RESULT_OUT) instruction = "Try less power or a shorter placement.";
                if (result == BV_RESULT_OWN) instruction = "Set again or clear the net.";
                if (result == BV_RESULT_ANTENNA) instruction = "Keep it inside the antennas.";
                if (result == BV_RESULT_MISS) instruction = "Release as it reaches your hands.";
                if (result == BV_RESULT_NET || result == BV_RESULT_UNDER) instruction = "Add arc or raise your contact.";
            }
        }
        if (autocvar_bv_shot_details && kind)
            values = strcat(BV_ShotName(kind), "   ", BV_Decimal(getstatf(BV_STAT_SPEED)), " m/s");
    }
    if (match && phase == BV_MATCH_POINT)
    {
        label = BV_PointLabel(getstatf(BV_STAT_POINT_REASON));
        instruction = "";
        color = BV_UI_TEXT;
    }
    if (match && phase == BV_MATCH_OVER)
    {
        label = "Match complete";
        if (getstatf(BV_STAT_HOME_SCORE) > getstatf(BV_STAT_AWAY_SCORE)) label = "You win!";
        instruction = "Esc  Match options";
        color = BV_UI_GOOD;
    }
    if (locked && autocvar_bv_shot_details)
    {
        values = strcat("Arc ", ftos(BV_Round(getstatf(BV_STAT_ARC) * 100)), "   ",
            BV_SideLabel(getstatf(BV_STAT_SIDE)), "   ", BV_TopLabel(getstatf(BV_STAT_TOP)), "   ",
            BV_DepthLabel(getstatf(BV_STAT_DEPTH)));
        if (receiving)
            values = strcat("Arc ", ftos(BV_Round(getstatf(BV_STAT_ARC) * 100)),
                "   Cushion ", ftos(BV_Round((getstatf(BV_STAT_DEPTH) + 1) * 50)), "%");
        if (getstatf(BV_STAT_OVERLAYS) && getstatf(BV_STAT_PREVIEW_RESULT))
            forecast = strcat(BV_ResultLabel(getstatf(BV_STAT_PREVIEW_RESULT)), "   ",
                BV_Decimal(getstatf(BV_STAT_PREVIEW_RANGE)), "m   Apex ",
                BV_Decimal(getstatf(BV_STAT_PREVIEW_HEIGHT)), "m");
    }
    if (label == "") return;
    width = BV_TextWidth(label, 14) + 24;
    if (instruction != "") width = BV_Clamp(BV_TextWidth(instruction, 10) + 24, width, 268);
    if (values != "") width = BV_Clamp(BV_TextWidth(values, 10) + 24, width, 268);
    if (forecast != "") width = BV_Clamp(BV_TextWidth(forecast, 10) + 24, width, 268);
    width = BV_Clamp(width, 124, viewport_x - 24);
    height = 28;
    if (instruction != "") height = height + 15;
    if (values != "") height = height + 15;
    if (forecast != "") height = height + 15;
    if (locked) height = height + 8;
    x = (viewport_x - width) * 0.5;
    y = viewport_y - height - 12;
    BV_HudSurface(x, y, width, height, alpha);
    BV_Type(x + 12, y + 7, label, 14, color, alpha, width - 24);
    row = y + 25;
    if (instruction != "")
    { BV_Type(x + 12, row, instruction, 10, BV_UI_MUTED, alpha, width - 24); row = row + 15; }
    if (values != "")
    { BV_Type(x + 12, row, values, 10, BV_UI_MUTED, alpha, width - 24); row = row + 15; }
    if (forecast != "") BV_Type(x + 12, row, forecast, 10, BV_UI_MUTED, alpha, width - 24);
    if (locked)
    {
        charge = BV_Clamp(getstatf(BV_STAT_CHARGE), 0, 1);
        if (receiving) charge = BV_Clamp(getstatf(BV_STAT_TIMING), 0, 1);
        BV_RoundBox(x + 12, y + height - 9, width - 24, 3, 1.5, '0.2 0.27 0.29', alpha);
        BV_RoundBox(x + 12, y + height - 9, (width - 24) * charge, 3, 1.5, color, alpha);
    }
};

void(vector viewport) BV_HudMap =
{
    local float x, match, preview;
    if (!autocvar_bv_court_map || viewport_x < 320 || viewport_y < 220) return;
    x = viewport_x - 132;
    match = getstatf(BV_STAT_MATCH);
    preview = getstatf(BV_STAT_PREVIEW_RESULT);
    BV_HudSurface(x, 12, 120, 82, 1);
    BV_Type(x + 12, 21, "COURT", 9, BV_UI_MUTED, 1, 96);
    BV_Box(x + 12, 38, 96, 48, '0.27 0.3 0.28', 1);
    if (!match) BV_MapTargets(x, 24);
    BV_Box(x + 12, 38, 96, 0.7, '0.5 0.64 0.65', 1);
    BV_Box(x + 12, 85.3, 96, 0.7, '0.5 0.64 0.65', 1);
    BV_Box(x + 12, 38, 0.7, 48, '0.5 0.64 0.65', 1);
    BV_Box(x + 107.3, 38, 0.7, 48, '0.5 0.64 0.65', 1);
    BV_Box(x + 59.5, 38, 1, 48, BV_UI_TEXT, 1);
    if (preview && getstatf(BV_STAT_OVERLAYS)) BV_MapPoint(x, 24, BV_STAT_PREVIEW, BV_ResultColor(preview), TRUE);
    BV_MapPoint(x, 24, BV_STAT_PLAYER, BV_UI_TEXT, FALSE);
    BV_MapPoint(x, 24, BV_STAT_BALL, BV_UI_GOLD, FALSE);
    if (match)
    {
        BV_MapPoint(x, 24, BV_STAT_PARTNER, '0.49 0.76 1', FALSE);
        BV_MapPoint(x, 24, BV_STAT_OPPONENT1, BV_UI_OPPONENT, FALSE);
        BV_MapPoint(x, 24, BV_STAT_OPPONENT2, BV_UI_OPPONENT, FALSE);
    }
};

void(vector virtual_size, float showscores) CSQC_DrawHud =
{
    local float x, y, preview, result, age, reach, locked, serving, timing;
    local float match, phase, receiving;
    local vector color;
    BV_MenuTestFrame();
    if (BV_MenuDraw(virtual_size)) return;
    if ((cvar("bv_netview") > 0 && cvar("bv_netview") != 6) || cvar("bv_handview"))
    {
        BV_VisualCapture();
        return;
    }
    // Cap the size on small windows and large engine HUD scales. The help
    // overlay shares the transform so it still fits when explicitly opened.
    bv_ui_scale = BV_Clamp(virtual_size_y / 240, 0.1, 1);
    bv_ui_scale = BV_Clamp(virtual_size_x / 360, 0.1, bv_ui_scale);
    virtual_size = virtual_size / bv_ui_scale;
    reach = getstatf(BV_STAT_REACH);
    locked = getstatf(BV_STAT_AIM_LOCKED);
    serving = getstatf(BV_STAT_SERVING);
    timing = getstatf(BV_STAT_TIMING);
    match = getstatf(BV_STAT_MATCH);
    phase = getstatf(BV_STAT_PHASE);
    receiving = getstatf(BV_STAT_RECEIVING);
    preview = getstatf(BV_STAT_PREVIEW_RESULT);
    result = getstatf(BV_STAT_RESULT);
    age = getstatf(BV_STAT_FEEDBACK_AGE);
    BV_HudScore(virtual_size);
    BV_HudMap(virtual_size);
    BV_HudCue(virtual_size);
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
    bv_ui_scale = 1;
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
