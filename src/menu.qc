// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
// A root owns pages, keyboard focus, pointer capture, and the cursor lifetime.
// Input conventions follow FTE/menusys; the widgets and artwork are original.
float bv_menu_open, bv_menu_page, bv_menu_focus, bv_menu_count;
float bv_menu_pointer, bv_menu_pressed, bv_menu_drag, bv_menu_release;
float bv_menu_shift, bv_menu_started, bv_menu_alpha, bv_menu_request;
float bv_menu_return, bv_menu_compact;
float bv_menu_welcome;
float bv_menu_in_session, bv_menu_settings_page;
float bv_menu_gamepad, bv_menu_visits_recorded;
float bv_menu_mouse_valid;
vector bv_menu_stick;
float bv_menu_stick_key, bv_menu_stick_repeat;
void(float key) BV_MenuMoveFocus;
var float autocvar_bv_menu_visits = 0;
var float autocvar_bv_matches_started = 0;
float bv_menu_page_focus[4];
float bv_menu_option_pending[2], bv_menu_option_value[2], bv_menu_option_until[2];
var float bv_menu_scale = 1;
var float autocvar_bv_menu_auto = 1;
vector bv_menu_mouse, bv_menu_viewport;
float bv_menu_x[24], bv_menu_y[24], bv_menu_w[24], bv_menu_h[24];
float bv_menu_action[24], bv_menu_value[24];
float bv_menu_track_x[24], bv_menu_track_w[24];

const float BV_MENU_PAGE = 1;
const float BV_MENU_PLAY = 2;
const float BV_MENU_CLOSE = 3;
const float BV_MENU_ENGINE = 4;
const float BV_MENU_QUIT = 5;
const float BV_MENU_ACCEPT = 6;
const float BV_MENU_BACK = 7;
const float BV_MENU_POINTS = 8;
const float BV_MENU_SETTING = 9;
const float BV_MENU_CATEGORY = 10;
const float BV_MENU_HELP = 11;
const float BV_MENU_HUD = 12;
const float BV_MENU_START_NEW = 13;
const float BV_MENU_NEW_SETUP = 14;

void(float page) BV_MenuPage =
{
    if (bv_menu_page < 4 && bv_menu_count > 0 && bv_menu_focus >= 4)
        bv_menu_page_focus[bv_menu_page] = bv_menu_focus;
    bv_menu_page = page;
    bv_menu_count = 0;
    bv_menu_focus = 4;
    if (page == 3) bv_menu_focus = 7;
    if (page < 4)
        if (bv_menu_page_focus[page] >= 0) bv_menu_focus = bv_menu_page_focus[page];
    if (page == 0) bv_menu_focus = 4;
    if (page >= 4) bv_menu_focus = 0;
    // A stationary pointer must not steal the new page's keyboard focus.
    bv_menu_pointer = FALSE;
    bv_menu_pressed = -1;
    bv_menu_drag = -1;
};

void(float enabled) BV_MenuSetOpen =
{
    if (bv_menu_open == enabled) return;
    bv_menu_open = enabled;
    setcursormode(enabled);
    sendevent("BeachMenu", "f", enabled);
    bv_menu_pressed = -1;
    bv_menu_drag = -1;
    if (enabled)
    {
        bv_menu_started = gettime();
        bv_menu_pointer = FALSE;
        bv_menu_mouse_valid = FALSE;
        bv_menu_stick = '0 0 0'; bv_menu_stick_key = 0;
        bv_menu_shift = FALSE;
        BV_MenuPage(0);
        bv_menu_focus = 4;
        cvar_set("bv_help", "0");
        // Release commands that were held before opening; consumed key-ups
        // must never leave a player running, charging, or spinning a shot.
        localcmd("-forward\n-back\n-moveleft\n-moveright\n-attack\n-button3\n-button4\n-button5\n-button7\n-button8\n-jump\n-showscores\n");
    }
    else bv_menu_in_session = TRUE;
};

float(float x, float y, float width, float height) BV_MenuContains =
{
    return bv_menu_mouse_x >= x && bv_menu_mouse_x < x + width &&
           bv_menu_mouse_y >= y && bv_menu_mouse_y < y + height;
};

float() BV_MenuHit =
{
    local float i;
    for (i = 0; i < bv_menu_count; i = i + 1)
        if (BV_MenuContains(bv_menu_x[i], bv_menu_y[i], bv_menu_w[i], bv_menu_h[i])) return i;
    return -1;
};

float(float x, float y, float width, float height, float action, float value) BV_MenuWidget =
{
    local float i;
    i = bv_menu_count;
    if (i >= 24) return 23;
    bv_menu_x[i] = x; bv_menu_y[i] = y;
    bv_menu_w[i] = width; bv_menu_h[i] = height;
    bv_menu_action[i] = action; bv_menu_value[i] = value;
    bv_menu_track_x[i] = 0; bv_menu_track_w[i] = 0;
    bv_menu_count = i + 1;
    return i;
};

void(float x, float y, string text, float height, vector color, float width) BV_MenuText =
{
    BV_Type(x, y, text, height, color, bv_menu_alpha, width);
};

void(float x, float y, string text, float height, vector color, float width) BV_MenuHeading =
{
    bv_ui_bold = TRUE;
    BV_MenuText(x, y, text, height, color, width);
    bv_ui_bold = FALSE;
};

// Artwork is a small original line-icon atlas, shared by cards and footer.
void(float x, float y, float size, float icon, vector color, float alpha) BV_MenuIcon =
{
    local vector position, extent, source;
    position = '0 0 0'; position_x = x; position_y = y;
    extent = '1 1 0' * size;
    source = '0 0 0';
    source_x = (icon - floor(icon / 4) * 4) / 4;
    source_y = floor(icon / 4) / 2;
    drawsubpic(position * bv_menu_scale, extent * bv_menu_scale, "gfx/bv_menu_icons.tga",
        source, '0.25 0.5 0', color, alpha * bv_menu_alpha, 0);
};

void(float x, float y, float width, float height, string title, string detail,
    float action, float value, float primary) BV_MenuButton =
{
    local float i, focused, inset, text_height;
    local vector fill, text;
    i = BV_MenuWidget(x, y, width, height, action, value);
    focused = (bv_menu_focus == i);
    fill = '0.11 0.15 0.17'; text = BV_UI_TEXT;
    if (focused) fill = '0.15 0.22 0.24';
    if (primary > 0) { fill = BV_UI_ACCENT; text = '0.025 0.08 0.09'; }
    if (primary < 0) { fill = '0.25 0.105 0.115'; text = '1 0.74 0.7'; }
    if (focused && !bv_menu_pointer)
        BV_RoundBox(x - 1, y - 1, width + 2, height + 2, 9, BV_UI_ACCENT, bv_menu_alpha * 0.65);
    if (bv_menu_pressed == i) fill = fill * 0.8;
    BV_RoundBox(x, y, width, height, 8, fill, bv_menu_alpha * 0.85);
    inset = 16;
    text_height = 16;
    if (detail != "" && height >= 55)
    {
        BV_MenuText(x + inset, y + height * 0.5 - 19, title, 20, text, width - inset * 2 - 20);
        BV_MenuText(x + inset, y + height * 0.5 + 11, detail, 12, BV_UI_MUTED, width - inset * 2);
    }
    else BV_MenuText(x + inset, y + (height - text_height) * 0.5,
        title, text_height, text, width - inset * 2 - 20);
    BV_MenuIcon(x + width - 34, y + (height - 18) * 0.5, 18, 1, text, 1);
};

// Text navigation has no permanent boxes. Focus softly lights its hit region.
void(float x, float y, float width, float height, string title,
    float action, float value, float selected) BV_MenuChoice =
{
    local float i, text_height;
    local vector color;
    i = BV_MenuWidget(x, y, width, height, action, value);
    color = BV_UI_MUTED; text_height = 15;
    if (selected) color = BV_UI_ACCENT;
    if (i == bv_menu_focus)
    {
        if (!selected) color = BV_UI_TEXT;
        BV_RoundBox(x, y, width, height, height * 0.5, '0.35 0.58 0.61', bv_menu_alpha * 0.10);
    }
    if (selected && action != BV_MENU_PAGE)
    {
        BV_RoundBox(x, y, width, height, height * 0.5, BV_UI_ACCENT, bv_menu_alpha * 0.85);
        BV_RoundBox(x + 1, y + 1, width - 2, height - 2, height * 0.5 - 1,
            '0.12 0.32 0.34', bv_menu_alpha * 0.9);
    }
    BV_MenuText(x + (width - BV_TextWidth(title, text_height)) * 0.5,
        y + (height - text_height) * 0.5, title, text_height, color, width - 8);
    if (selected && action == BV_MENU_PAGE)
        BV_RoundBox(x + width * 0.2, y + height - 2, width * 0.6, 2, 1, BV_UI_ACCENT, bv_menu_alpha);
};

void(float x, float y, float width, float height, string title, float icon,
    float action, float value) BV_MenuLink =
{
    local float i, text_width, left;
    local vector color;
    i = BV_MenuWidget(x, y, width, height, action, value);
    color = BV_UI_TEXT;
    if (bv_menu_focus == i)
    {
        color = BV_UI_ACCENT;
        BV_RoundBox(x, y, width, height, 7, '0.32 0.5 0.54', bv_menu_alpha * 0.12);
    }
    text_width = BV_TextWidth(title, 14);
    left = x + (width - text_width - 35) * 0.5;
    BV_MenuIcon(left, y + (height - 23) * 0.5, 23, icon, color, 1);
    BV_MenuText(left + 35, y + (height - 14) * 0.5, title, 14, color, width - 42);
};

float(float setting) BV_MenuSettingToggle =
{
    return setting <= 2 || setting >= 6;
};

float(float setting) BV_MenuSettingValue =
{
    local float actual;
    if (setting <= 1)
    {
        actual = getstatf(BV_STAT_ASSISTED);
        if (setting == 1) actual = getstatf(BV_STAT_OVERLAYS);
        if (bv_menu_option_pending[setting])
        {
            if (actual == bv_menu_option_value[setting] || gettime() > bv_menu_option_until[setting])
                bv_menu_option_pending[setting] = FALSE;
            else return bv_menu_option_value[setting];
        }
        return actual;
    }
    if (setting == 2) return cvar("bv_contact_kick") > 0;
    if (setting == 3) return cvar("volume");
    if (setting == 4) return cvar("sensitivity");
    if (setting == 6) return autocvar_bv_court_map != 0;
    if (setting == 7) return autocvar_bv_coaching != 0;
    if (setting == 8) return autocvar_bv_shot_details != 0;
    return cvar("fov");
};

void(float setting, float value) BV_MenuSettingSet =
{
    local string name;
    if (setting == 0 || setting == 1)
    {
        value = value != 0;
        bv_menu_option_value[setting] = value;
        bv_menu_option_pending[setting] = TRUE;
        bv_menu_option_until[setting] = gettime() + 2;
        sendevent("BeachOption", "ff", setting, value);
    }
    if (setting == 2)
    {
        cvar_set("bv_contact_kick", ftos(value));
        localcmd(strcat("seta bv_contact_kick ", ftos(value), "\n"));
    }
    if (setting == 3) cvar_set("volume", ftos(BV_Clamp(value, 0, 1)));
    if (setting == 4) cvar_set("sensitivity", ftos(BV_Clamp(value, 0.5, 10)));
    if (setting == 5) cvar_set("fov", ftos(BV_Clamp(value, 80, 120)));
    name = "";
    if (setting == 6) name = "bv_court_map";
    if (setting == 7) name = "bv_coaching";
    if (setting == 8) name = "bv_shot_details";
    if (name != "")
    {
        value = value != 0;
        cvar_set(name, ftos(value));
        localcmd(strcat("seta ", name, " ", ftos(value), "\n"));
    }
};

void(float setting, float direction) BV_MenuAdjust =
{
    local float value;
    value = BV_MenuSettingValue(setting);
    if (BV_MenuSettingToggle(setting)) value = !value;
    if (setting == 3) value = value + direction * 0.1;
    if (setting == 4) value = value + direction * 0.5;
    if (setting == 5) value = value + direction * 5;
    BV_MenuSettingSet(setting, value);
};

void(float index) BV_MenuSlide =
{
    local float value, setting;
    if (index < 0 || index >= bv_menu_count) return;
    if (bv_menu_track_w[index] <= 0) return;
    setting = bv_menu_value[index];
    value = BV_Clamp((bv_menu_mouse_x - bv_menu_track_x[index]) / bv_menu_track_w[index], 0, 1);
    if (setting == 3) value = BV_Round(value * 10) / 10;
    if (setting == 4) value = BV_Round((0.5 + value * 9.5) * 2) / 2;
    if (setting == 5) value = BV_Round((80 + value * 40) / 5) * 5;
    BV_MenuSettingSet(setting, value);
};

void(float impulse) BV_MenuLaunch =
{
    if (impulse == 34)
    {
        cvar_set("bv_matches_started", ftos(autocvar_bv_matches_started + 1));
        localcmd(strcat("seta bv_matches_started ", ftos(autocvar_bv_matches_started), "\n"));
    }
    BV_MenuSetOpen(FALSE);
    localcmd(strcat("impulse ", ftos(impulse), "\n"));
};

void(float index, float direction) BV_MenuActivate =
{
    local float action, value;
    if (index < 0 || index >= bv_menu_count) return;
    action = bv_menu_action[index]; value = bv_menu_value[index];
    if (action == BV_MENU_PAGE) BV_MenuPage(value);
    if (action == BV_MENU_PLAY)
    {
        if (getstatf(BV_STAT_MATCH) && getstatf(BV_STAT_PHASE) != BV_MATCH_OVER)
        {
            bv_menu_request = value;
            bv_menu_return = bv_menu_page;
            BV_MenuPage(4);
        }
        else BV_MenuLaunch(value);
    }
    if (action == BV_MENU_NEW_SETUP)
    {
        // The active match keeps its own rules; length belongs to a new match.
        bv_menu_request = 34;
        bv_menu_return = 0;
        BV_MenuPage(6);
    }
    if (action == BV_MENU_START_NEW)
    {
        bv_menu_request = 34;
        if (getstatf(BV_STAT_MATCH) && getstatf(BV_STAT_PHASE) != BV_MATCH_OVER)
            BV_MenuPage(4);
        else BV_MenuLaunch(34);
    }
    if (action == BV_MENU_CLOSE) BV_MenuSetOpen(FALSE);
    if (action == BV_MENU_HELP)
    {
        BV_MenuSetOpen(FALSE);
        cvar_set("bv_help", "1");
    }
    if (action == BV_MENU_ENGINE)
    {
        BV_MenuSetOpen(FALSE);
        localcmd("menu_options\n");
    }
    if (action == BV_MENU_QUIT) { bv_menu_return = bv_menu_page; BV_MenuPage(5); }
    if (action == BV_MENU_ACCEPT)
    {
        if (bv_menu_page == 4) BV_MenuLaunch(bv_menu_request);
        else { BV_MenuSetOpen(FALSE); localcmd("quit\n"); }
    }
    if (action == BV_MENU_BACK) BV_MenuPage(bv_menu_return);
    if (action == BV_MENU_POINTS)
    {
        cvar_set("bv_match_points", ftos(value));
        localcmd(strcat("seta bv_match_points ", ftos(value), "\n"));
    }
    if (action == BV_MENU_SETTING) BV_MenuAdjust(value, direction);
    if (action == BV_MENU_CATEGORY)
    {
        bv_menu_settings_page = value;
        bv_menu_pressed = -1; bv_menu_drag = -1;
    }
    if (action == BV_MENU_HUD)
    {
        cvar_set("bv_hud_style", ftos(value));
        localcmd(strcat("seta bv_hud_style ", ftos(value), "\n"));
    }
};

void(float x, float y, float width, float height, string title, string detail, float setting) BV_MenuSetting =
{
    local float i, value, track, length, fraction, toggle, switch_h, thumb;
    local string label;
    i = BV_MenuWidget(x, y, width, height, BV_MENU_SETTING, setting);
    if (i == bv_menu_focus)
        BV_RoundBox(x, y, width, height, 7, '0.24 0.4 0.43', bv_menu_alpha * 0.18);
    BV_MenuText(x + 4, y + height * 0.5 - 17, title, 15, BV_UI_TEXT, width * 0.60 - 12);
    BV_MenuText(x + 4, y + height * 0.5 + 6, detail, 11, BV_UI_MUTED, width * 0.60 - 12);
    BV_Box(x + 4, y + height - 1, width - 8, 0.6, '0.55 0.65 0.69', bv_menu_alpha * 0.15);
    value = BV_MenuSettingValue(setting);
    if (BV_MenuSettingToggle(setting))
    {
        toggle = x + width - 47; switch_h = 22; thumb = 16;
        BV_RoundBox(toggle, y + (height - switch_h) * 0.5, 40, switch_h, 11,
            '0.32 0.37 0.40', bv_menu_alpha);
        if (value) BV_RoundBox(toggle, y + (height - switch_h) * 0.5, 40, switch_h, 11,
            BV_UI_ACCENT, bv_menu_alpha);
        BV_RoundBox(toggle + 3 + 18 * (value != 0), y + (height - thumb) * 0.5,
            thumb, thumb, 8, BV_UI_TEXT, bv_menu_alpha);
    }
    else
    {
        track = x + width * 0.63; length = width * 0.37 - 54;
        bv_menu_track_x[i] = track; bv_menu_track_w[i] = length;
        fraction = value;
        label = strcat(ftos(BV_Round(value * 100)), "%");
        if (setting == 4) { fraction = (value - 0.5) / 9.5; label = BV_Decimal(value); }
        if (setting == 5) { fraction = (value - 80) / 40; label = ftos(BV_Round(value)); }
        fraction = BV_Clamp(fraction, 0, 1);
        BV_RoundBox(track, y + height * 0.5 - 2, length, 4, 2, '0.2 0.28 0.3', bv_menu_alpha);
        BV_RoundBox(track, y + height * 0.5 - 2, length * fraction, 4, 2, BV_UI_ACCENT, bv_menu_alpha);
        BV_RoundBox(track + length * fraction - 5, y + height * 0.5 - 5, 10, 10, 5,
            BV_UI_TEXT, bv_menu_alpha);
        BV_MenuText(x + width - 43, y + (height - 12) * 0.5, label, 12, BV_UI_TEXT, 40);
    }
};

string(float impulse) BV_MenuSessionName =
{
    if (impulse == 34) return "doubles";
    if (impulse == 31) return "receive";
    if (impulse == 32) return "set";
    if (impulse == 33) return "attack";
    if (impulse == 35) return "free play";
    return "serve";
};

string() BV_MenuScore =
{
    return strcat("Blue ", ftos(getstatf(BV_STAT_HOME_SCORE)), "  -  ",
        ftos(getstatf(BV_STAT_AWAY_SCORE)), " Red");
};

void(vector viewport) BV_MenuConfirmation =
{
    local float x, y, width, pad, column;
    local string title, detail, action, session;
    width = BV_Clamp(viewport_x - 32, 0, 440);
    pad = 22; column = (width - pad * 2 - 10) * 0.5;
    x = (viewport_x - width) * 0.5;
    y = (viewport_y - 214) * 0.5;
    title = "Restart doubles?"; action = "Restart match";
    if (bv_menu_request != 34)
    {
        title = strcat("Start ", BV_MenuSessionName(bv_menu_request), " practice?");
        action = strcat("Start ", BV_MenuSessionName(bv_menu_request));
    }
    detail = "Your current doubles match will end.";
    if (bv_menu_page == 5) { title = "Quit game?"; action = "Quit game"; detail = "Your current session will end."; }
    session = BV_ModeLabel(getstatf(BV_STAT_MODE));
    if (getstatf(BV_STAT_MATCH)) session = BV_MenuScore();
    BV_Panel(x, y, width, 214, bv_menu_alpha);
    BV_MenuText(x + pad, y + 23, title, 22 - bv_menu_compact * 2, BV_UI_TEXT, width - pad * 2);
    BV_MenuText(x + pad, y + 55, detail, 11, BV_UI_MUTED, width - pad * 2);
    BV_RoundBox(x + pad, y + 84, width - pad * 2, 40, 6, '0.085 0.13 0.16', bv_menu_alpha);
    BV_MenuText(x + pad + 12, y + 90, "CURRENT SESSION", 8, BV_UI_MUTED, width - pad * 2 - 24);
    BV_MenuText(x + pad + 12, y + 103, session, 12, BV_UI_TEXT, width - pad * 2 - 24);
    // Only these two actions exist in a confirmation. No tabs or footer can
    // replace its destination or evade the decision it is asking about.
    BV_MenuButton(x + pad, y + 145, column, 34, "Cancel", "", BV_MENU_BACK, 0, FALSE);
    BV_MenuButton(x + pad + column + 10, y + 145, column, 34, action, "", BV_MENU_ACCEPT, 0, -1);
    BV_MenuText(x + pad, y + 192, "Esc  Cancel", 9, BV_UI_MUTED, width - pad * 2);
};

void(float x, float y, float width) BV_MenuPoints =
{
    local float start, segment, i, points;
    start = 126; segment = (width - start) / 3;
    if (segment > 90) segment = 90;
    BV_MenuText(x, y + 11, "Match length", 14, BV_UI_TEXT, start - 8);
    BV_RoundBox(x + start, y, segment * 3, 36, 18, '0.55 0.65 0.69', bv_menu_alpha * 0.24);
    BV_RoundBox(x + start + 0.8, y + 0.8, segment * 3 - 1.6, 34.4, 17.2,
        '0.09 0.12 0.14', bv_menu_alpha * 0.78);
    for (i = 0; i < 3; i = i + 1)
    {
        points = 7; if (i == 1) points = 11; if (i == 2) points = 21;
        if (i) BV_Box(x + start + segment * i, y + 6, 0.5, 24, BV_UI_MUTED, bv_menu_alpha * 0.2);
        BV_MenuChoice(x + start + segment * i, y, segment, 36,
            ftos(points), BV_MENU_POINTS, points, cvar("bv_match_points") == points);
    }
};

void(vector viewport) BV_MenuNewMatch =
{
    local float x, y, width;
    width = 520;
    x = (viewport_x - width) * 0.5; y = (viewport_y - 260) * 0.5;
    BV_Panel(x, y, width, 260, bv_menu_alpha);
    BV_MenuText(x + 28, y + 26, "A fresh match", 28, BV_UI_TEXT, width - 56);
    BV_MenuText(x + 28, y + 70, "You + 3 bots. First to your target. Win by 2.", 14, BV_UI_MUTED, width - 56);
    // Keep Cancel first in the reading order; the length choices follow.
    BV_MenuButton(x + 28, y + 178, 186, 42, "Cancel", "", BV_MENU_BACK, 0, 0);
    BV_MenuButton(x + 226, y + 178, width - 254, 42, "Start match", "", BV_MENU_START_NEW, 0, 1);
    BV_MenuPoints(x + 28, y + 112, width - 56);
};

void(float x, float y, float width, float height, string number, string title, string detail) BV_MenuStep =
{
    BV_RoundBox(x, y + (height - 29) * 0.5, 29, 29, 14.5, '0.13 0.21 0.24', bv_menu_alpha);
    BV_MenuText(x + 10, y + (height - 15) * 0.5, number, 15, BV_UI_ACCENT, 19);
    BV_MenuText(x + 44, y + height * 0.5 - 19, title, 18, BV_UI_TEXT, width - 44);
    BV_MenuText(x + 44, y + height * 0.5 + 9, detail, 12, BV_UI_MUTED, width - 44);
};

void(float x, float y, float width, float resume, float finished) BV_MenuHero =
{
    local float i, cta_x, cta_w, text_x, goal;
    local string title, detail, rules, action;
    local vector border, position, size;
    i = BV_MenuWidget(x, y, width, 112, BV_MENU_PLAY, 34);
    if (resume) bv_menu_action[i] = BV_MENU_CLOSE;
    border = '0.32 0.64 0.66';
    if (bv_menu_focus == i) border = BV_UI_ACCENT;
    BV_RoundBox(x, y, width, 112, 10, border, bv_menu_alpha * 0.85);
    BV_RoundBox(x + 1, y + 1, width - 2, 110, 9, '0.07 0.16 0.19', bv_menu_alpha * 0.9);
    // Barely visible court geometry gives the glass depth without more content.
    position = '0 0 0'; position_x = x + width - 221; position_y = y + 3;
    size = '218 106 0';
    drawsubpic(position * bv_menu_scale, size * bv_menu_scale, "gfx/bv_menu_card.tga",
        '0 0 0', '1 1 0', '0.55 0.8 0.8', bv_menu_alpha * 0.07, 0);
    BV_MenuIcon(x + 23, y + 34, 45, 0, '0.6 0.94 0.94', 1);
    BV_Box(x + 88, y + 20, 0.8, 72, '0.64 0.76 0.79', bv_menu_alpha * 0.45);
    text_x = x + 111; cta_w = 178; cta_x = x + width - cta_w - 21;
    title = "Beach doubles"; detail = "You + 3 bots"; action = "Start match";
    goal = cvar("bv_match_points");
    if (goal != 11 && goal != 21) goal = 7;
    if (resume)
    {
        title = "Resume practice"; detail = BV_ModeLabel(getstatf(BV_STAT_MODE)); action = "Resume";
        if (getstatf(BV_STAT_MATCH))
        {
            title = "Resume match"; detail = BV_MenuScore();
            goal = getstatf(BV_STAT_GOAL);
        }
    }
    if (finished) { title = "Play again"; detail = BV_MenuScore(); action = "New match"; }
    rules = strcat("First to ", ftos(goal), "  -  Win by 2");
    if (resume && !getstatf(BV_STAT_MATCH)) rules = "Your court is ready";
    BV_MenuHeading(text_x, y + 19, title, 23, BV_UI_TEXT, cta_x - text_x - 10);
    BV_MenuText(text_x, y + 54, detail, 14, '0.77 0.83 0.85', cta_x - text_x - 10);
    BV_MenuText(text_x, y + 77, rules, 13, BV_UI_MUTED, cta_x - text_x - 10);
    if (bv_menu_focus == i && !bv_menu_pointer)
        BV_RoundBox(cta_x - 3, y + 32, cta_w + 6, 48, 24, BV_UI_ACCENT, bv_menu_alpha * 0.12);
    border = BV_UI_ACCENT;
    if (bv_menu_pressed == i) border = border * 0.8;
    BV_RoundBox(cta_x, y + 35, cta_w, 42, 21, border, bv_menu_alpha);
    BV_MenuText(cta_x + 23, y + 48, action, 16, '0.025 0.08 0.09', cta_w - 62);
    BV_MenuIcon(cta_x + cta_w - 36, y + 46, 19, 1, '0.025 0.08 0.09', 1);
};

void(float x, float y, float width) BV_MenuHudGallery =
{
    local float i, index, column, selected, old_scale;
    local vector position, size;
    local string label;
    column = (width - 24) / 3;
    BV_MenuText(x, y, "HUD style", 13, BV_UI_TEXT, width);
    for (i = 0; i < 3; i = i + 1)
    {
        position = '0 0 0'; position_x = x + i * (column + 12); position_y = y + 24;
        index = BV_MenuWidget(position_x, position_y, column, 72, BV_MENU_HUD, i);
        selected = (autocvar_bv_hud_style == i);
        BV_RoundBox(position_x, position_y, column, 56, 6,
            BV_UI_MUTED, bv_menu_alpha * 0.3);
        if (selected || index == bv_menu_focus)
            BV_RoundBox(position_x, position_y, column, 56, 6,
                BV_UI_ACCENT, bv_menu_alpha * (0.4 + selected * 0.6));
        size = '0 0 0'; size_x = column - 4; size_y = 52;
        position_x = position_x + 2; position_y = position_y + 2;
        drawsubpic(position * bv_menu_scale, size * bv_menu_scale, "gfx/bv_menu_court.tga",
            '0.14 0.17 0', '0.72 0.6 0', '0.8 0.85 0.87', bv_menu_alpha, 0);
        // The thumbnails use the same scoreboard renderer as live gameplay.
        old_scale = bv_ui_scale;
        bv_ui_scale = old_scale * 0.55;
        BV_HudMatchScore((position_x + 8) / 0.55, (position_y + 6) / 0.55, i, 7, 7, -1, bv_menu_alpha);
        bv_ui_scale = old_scale;
        label = "Minimal"; if (i == 1) label = "Classic"; if (i == 2) label = "Competitive";
        BV_MenuText(position_x + (column - BV_TextWidth(label, 12)) * 0.5,
            position_y + 54, label, 12, BV_UI_TEXT, column - 4);
    }
};

void() BV_MenuStickFrame =
{
    local float key, direction;
    key = 0;
    // Hysteresis keeps a resting stick from taking focus. A held direction
    // repeats on the real clock, independently of frame rate or simulation.
    if (fabs(bv_menu_stick_x) > fabs(bv_menu_stick_y))
    {
        direction = bv_menu_stick_x;
        if (direction > 0.55) key = K_RIGHTARROW;
        if (direction < -0.55) key = K_LEFTARROW;
    }
    else
    {
        direction = bv_menu_stick_y;
        if (direction > 0.55) key = K_DOWNARROW;
        if (direction < -0.55) key = K_UPARROW;
    }
    if (!key)
    {
        if (fabs(direction) < 0.3) bv_menu_stick_key = 0;
        return;
    }
    if (bv_menu_stick_key != key)
    {
        bv_menu_stick_key = key;
        bv_menu_stick_repeat = gettime() + 0.4;
        BV_MenuMoveFocus(key);
    }
    else if (gettime() >= bv_menu_stick_repeat)
    {
        bv_menu_stick_repeat = gettime() + 0.14;
        BV_MenuMoveFocus(key);
    }
};

float(vector viewport) BV_MenuDraw =
{
    local float x, y, width, height, pad, inner, column, gap, top, i, tab, footer, resume, finished;
    local vector logo_position, logo_size, physical;
    local string title, subtitle, label;
    if (bv_menu_welcome && getstatf(BV_STAT_STATE) > 0)
    {
        bv_menu_welcome = FALSE;
        BV_MenuSetOpen(TRUE);
    }
    if (!bv_menu_open) return FALSE;
    // Independent of the engine's on-court HUD scale. All pointer coordinates
    // use this same transform, including controller-sized and compact windows.
    physical = viewport;
    if (checkbuiltin(getproperty)) physical = getproperty(205);
    if (physical_x <= 0 || physical_y <= 0) physical = viewport;
    bv_menu_scale = BV_Clamp(physical_y / 588, 0.1, 1);
    bv_menu_scale = BV_Clamp(physical_x / 808, 0.1, bv_menu_scale) * viewport_y / physical_y;
    viewport = viewport / bv_menu_scale;
    bv_ui_scale = bv_menu_scale;
    bv_menu_viewport = viewport;
    bv_menu_compact = physical_x < 800 || physical_y < 560;
    width = 760; height = 548; pad = 46; gap = 12;
    inner = width - pad * 2; column = (inner - gap) * 0.5;
    x = (viewport_x - width) * 0.5; y = (viewport_y - height) * 0.5;
    bv_menu_alpha = BV_Clamp((gettime() - bv_menu_started) * 10, 0, 1);
    bv_menu_count = 0;
    BV_Box(0, 0, viewport_x, viewport_y, '0.012 0.025 0.035', 0.18 * bv_menu_alpha);
    if (bv_menu_page >= 4)
    {
        if (bv_menu_page == 6) BV_MenuNewMatch(viewport);
        else BV_MenuConfirmation(viewport);
        BV_MenuStickFrame();
        bv_ui_scale = 1;
        return TRUE;
    }
    // Dark glass leaves the real court visible through the panel.
    BV_RoundBox(x, y + 5, width, height, 17, '0 0 0', 0.14 * bv_menu_alpha);
    BV_RoundBox(x, y, width, height, 16, '0.52 0.65 0.7', 0.32 * bv_menu_alpha);
    BV_RoundBox(x + 0.8, y + 0.8, width - 1.6, height - 1.6, 15.2,
        '0.027 0.046 0.058', 0.78 * bv_menu_alpha);
    logo_position = '0 0 0'; logo_position_x = x + (width - 112) * 0.5; logo_position_y = y + 6;
    logo_size = '112 84 0';
    drawsubpic(logo_position * bv_menu_scale, logo_size * bv_menu_scale,
        "gfx/bv_logo.tga", '0 0 0', '1 1 0', '1 1 1', bv_menu_alpha, 0);
    BV_RoundBox(x + width - pad - 80, y + 23, 5, 5, 2.5, BV_UI_ACCENT, bv_menu_alpha);
    BV_MenuText(x + width - pad - 67, y + 21, "COURT LIVE", 10, BV_UI_MUTED, 69);
    tab = 122;
    for (i = 0; i < 4; i = i + 1)
    {
        label = "Play"; if (i == 1) label = "Practice"; if (i == 2) label = "Learn"; if (i == 3) label = "Settings";
        BV_MenuChoice(x + (width - tab * 4) * 0.5 + i * tab, y + 98, tab, 34,
            label, BV_MENU_PAGE, i, bv_menu_page == i);
        if (i < 3) BV_Box(x + (width - tab * 4) * 0.5 + (i + 1) * tab, y + 108,
            0.6, 14, BV_UI_MUTED, bv_menu_alpha * 0.3);
    }
    resume = (bv_menu_in_session || getstatf(BV_STAT_MATCH));
    finished = FALSE;
    if (getstatf(BV_STAT_MATCH))
        if (getstatf(BV_STAT_PHASE) == BV_MATCH_OVER) finished = TRUE;
    if (finished) resume = FALSE;
    title = "Ready to play?"; subtitle = "Beach volleyball. You and three bots.";
    if (resume) { title = "Welcome back"; subtitle = "Your court is ready to continue."; }
    if (resume && getstatf(BV_STAT_MATCH)) subtitle = "Your match is ready to continue.";
    if (finished) { title = "Good game."; subtitle = "Same beach. A fresh score."; }
    if (bv_menu_page == 1) { title = "What do you want to work on?"; subtitle = "A little practice. A better next rally."; }
    if (bv_menu_page == 2) { title = "Your first serve"; subtitle = "Three simple steps. Then make it yours."; }
    if (bv_menu_page == 3) { title = "Settings"; subtitle = "Make yourself comfortable."; }
    BV_MenuHeading(x + pad, y + 157, title, 32, BV_UI_TEXT, inner);
    BV_MenuText(x + pad, y + 202, subtitle, 15, BV_UI_MUTED, inner);
    top = y + 239;
    if (bv_menu_page == 0)
    {
        BV_MenuHero(x + pad, top, inner, resume, finished);
        if (resume)
        {
            BV_MenuLink(x + pad, top + 128, column, 40, "New match", 6, BV_MENU_NEW_SETUP, 0);
            BV_MenuLink(x + pad + column + gap, top + 128, column, 40, "Practice", 7, BV_MENU_PAGE, 1);
        }
        else BV_MenuPoints(x + pad, top + 133, inner);
        if (!resume && !finished && autocvar_bv_matches_started < 3)
        {
            BV_Box(x + pad, y + 428, inner, 0.6, BV_UI_MUTED, bv_menu_alpha * 0.3);
            BV_MenuLink(x + pad, y + 433, inner, 38, "New to the game? Learn the basics", 5, BV_MENU_PAGE, 2);
        }
    }
    if (bv_menu_page == 1)
    {
        BV_MenuButton(x + pad, top, column, 88, "Serving", "Placement, power and consistency", BV_MENU_PLAY, 30, 0);
        BV_MenuButton(x + pad + column + gap, top, column, 88, "Passing", "Receive controlled serves", BV_MENU_PLAY, 31, 0);
        BV_MenuButton(x + pad, top + 100, column, 88, "Setting", "Put the ball where it belongs", BV_MENU_PLAY, 32, 0);
        BV_MenuButton(x + pad + column + gap, top + 100, column, 88, "Attacking", "Timing and shot selection", BV_MENU_PLAY, 33, 0);
        BV_MenuLink(x + pad, y + 438, inner, 32, "Free play - just you and the court", 2, BV_MENU_PLAY, 35);
    }
    if (bv_menu_page == 2)
    {
        BV_MenuStep(x + pad, top - 8, inner, 59, "1", "Aim across the net", "Move with WASD. Look with the mouse.");
        BV_MenuStep(x + pad, top + 51, inner, 59, "2", "Hold left click to toss", "Settle your feet while preparing.");
        BV_MenuStep(x + pad, top + 110, inner, 59, "3", "Release near the top", "Meet the ball with your hands.");
        BV_MenuButton(x + pad, y + 428, column, 40, "Try a serve", "", BV_MENU_PLAY, 30, 1);
        BV_MenuLink(x + pad + column + gap, y + 428, column, 40, "All controls", 3, BV_MENU_HELP, 0);
    }
    if (bv_menu_page == 3)
    {
        top = y + 232; tab = inner / 3;
        BV_RoundBox(x + pad, top, inner, 30, 15, '0.28 0.34 0.36', bv_menu_alpha * 0.45);
        BV_MenuChoice(x + pad, top, tab, 30, "Gameplay", BV_MENU_CATEGORY, 0, bv_menu_settings_page == 0);
        BV_MenuChoice(x + pad + tab, top, tab, 30, "Audio & Video", BV_MENU_CATEGORY, 1, bv_menu_settings_page == 1);
        BV_MenuChoice(x + pad + tab * 2, top, tab, 30, "HUD", BV_MENU_CATEGORY, 2, bv_menu_settings_page == 2);
        top = top + 37;
        if (!bv_menu_settings_page)
        {
            BV_MenuSetting(x + pad, top, inner, 62, "Contact assist", "Auto contact while holding a shot", 0);
            BV_MenuSetting(x + pad, top + 62, inner, 62, "Landing guide", "See where your shot will land", 1);
            BV_MenuSetting(x + pad, top + 124, inner, 62, "Contact motion", "A gentle camera pulse on contact", 2);
        }
        else if (bv_menu_settings_page == 1)
        {
            BV_MenuSetting(x + pad, top, inner, 50, "Sound volume", "Set the mood on court", 3);
            BV_MenuSetting(x + pad, top + 50, inner, 50, "Mouse speed", "How quickly your view turns", 4);
            BV_MenuSetting(x + pad, top + 100, inner, 50, "Field of view", "See more of the court", 5);
            BV_MenuLink(x + pad, top + 157, inner, 32, "Advanced video & input", 3, BV_MENU_ENGINE, 0);
        }
        else
        {
            BV_MenuSetting(x + pad, top, inner, 35, "Court map", "Show player positions", 6);
            BV_MenuSetting(x + pad, top + 35, inner, 35, "Coaching tips", "Guidance during court play", 7);
            BV_MenuSetting(x + pad, top + 70, inner, 35, "Shot details", "Serve speed and hit stats", 8);
            BV_MenuHudGallery(x + pad, top + 115, inner);
            // Preview the chosen live score on the unobscured court as well.
            if (viewport_x > width + 240)
                BV_HudMatchScore(20, 20, autocvar_bv_hud_style, getstatf(BV_STAT_HOME_SCORE),
                    getstatf(BV_STAT_AWAY_SCORE), getstatf(BV_STAT_SERVE_TEAM), bv_menu_alpha);
        }
    }
    footer = y + 490; column = inner / 3;
    BV_Box(x + pad, footer - 11, inner, 0.6, BV_UI_MUTED, bv_menu_alpha * 0.3);
    BV_MenuLink(x + pad, footer, column, 32, "Explore", 2, BV_MENU_CLOSE, 0);
    BV_MenuLink(x + pad + column, footer, column, 32, "Controls", 3, BV_MENU_HELP, 0);
    BV_MenuLink(x + pad + column * 2, footer, column, 32, "Quit", 4, BV_MENU_QUIT, 0);
    BV_Box(x + pad + column, footer + 7, 0.6, 18, BV_UI_MUTED, bv_menu_alpha * 0.3);
    BV_Box(x + pad + column * 2, footer + 7, 0.6, 18, BV_UI_MUTED, bv_menu_alpha * 0.3);
    if (autocvar_bv_menu_visits < 5)
    {
        label = "Arrows  Navigate     Enter  Select     Esc  Back";
        if (bv_menu_gamepad) label = "Stick / D-pad  Navigate     A  Select     B  Back";
        BV_MenuText(x + 18, y + height - 12, label, 9, BV_UI_MUTED, inner);
    }
    if (bv_menu_focus >= bv_menu_count) bv_menu_focus = 4;
    BV_MenuStickFrame();
    if (bv_menu_focus >= 4) bv_menu_page_focus[bv_menu_page] = bv_menu_focus;
    bv_ui_scale = 1;
    return TRUE;
};

// Arrows follow visible geometry; Tab retains a predictable reading order.
// Strongly prefer items whose perpendicular spans overlap (same row/column).
void(float key) BV_MenuMoveFocus =
{
    local float i, old, best, vertical, forward, across, score, nearest, center, other;
    if (!bv_menu_count) return;
    old = BV_Clamp(bv_menu_focus, 0, bv_menu_count - 1);
    best = old; nearest = 1000000;
    vertical = FALSE;
    if (key == K_UPARROW || key == K_DOWNARROW) vertical = TRUE;
    for (i = 0; i < bv_menu_count; i = i + 1)
    {
        if (i == old) continue;
        if (vertical)
        {
            forward = bv_menu_y[i] + bv_menu_h[i] * 0.5 - bv_menu_y[old] - bv_menu_h[old] * 0.5;
            center = bv_menu_x[old] + bv_menu_w[old] * 0.5;
            across = 0;
            if (center < bv_menu_x[i]) across = bv_menu_x[i] - center;
            if (center > bv_menu_x[i] + bv_menu_w[i]) across = center - bv_menu_x[i] - bv_menu_w[i];
            other = fabs(bv_menu_x[i] + bv_menu_w[i] * 0.5 - center);
        }
        else
        {
            forward = bv_menu_x[i] + bv_menu_w[i] * 0.5 - bv_menu_x[old] - bv_menu_w[old] * 0.5;
            center = bv_menu_y[old] + bv_menu_h[old] * 0.5;
            across = 0;
            if (center < bv_menu_y[i]) across = bv_menu_y[i] - center;
            if (center > bv_menu_y[i] + bv_menu_h[i]) across = center - bv_menu_y[i] - bv_menu_h[i];
            other = fabs(bv_menu_y[i] + bv_menu_h[i] * 0.5 - center);
        }
        if ((key == K_LEFTARROW) || (key == K_UPARROW)) forward = -forward;
        if (!vertical && across > 0) continue;
        if (forward <= 0.1) continue;
        score = forward + across * 8 + other * 0.01;
        if (score < nearest) { best = i; nearest = score; }
    }
    bv_menu_focus = best;
    if (!vertical && bv_menu_action[old] == BV_MENU_POINTS && bv_menu_action[best] == BV_MENU_POINTS)
        BV_MenuActivate(best, 1);
    if (!vertical && bv_menu_action[old] == BV_MENU_CATEGORY && bv_menu_action[best] == BV_MENU_CATEGORY)
        BV_MenuActivate(best, 1);
    if (!vertical && bv_menu_action[old] == BV_MENU_HUD && bv_menu_action[best] == BV_MENU_HUD)
        BV_MenuActivate(best, 1);
    if (!vertical && old < 4 && best < 4 && bv_menu_page < 4)
    {
        BV_MenuPage(bv_menu_value[best]);
        bv_menu_focus = best;
    }
    bv_menu_pointer = FALSE;
};

float(float event, float key, float character, float device) CSQC_InputEvent =
{
    local float hit, old;
    if (event == IE_KEYDOWN || event == IE_KEYUP)
    {
        if (key >= K_PAD_UP && key <= K_PAD_RIGHT)
        {
            bv_menu_gamepad = TRUE;
            if (key == K_PAD_UP) key = K_UPARROW;
            else if (key == K_PAD_DOWN) key = K_DOWNARROW;
            else if (key == K_PAD_LEFT) key = K_LEFTARROW;
            else key = K_RIGHTARROW;
        }
        if (key == K_PAD_A) { bv_menu_gamepad = TRUE; key = K_ENTER; }
        if (key == K_PAD_B) { bv_menu_gamepad = TRUE; key = K_ESCAPE; }
    }
    if (event == IE_MOUSEABS) bv_menu_gamepad = FALSE;
    if (event == IE_KEYUP && key == bv_menu_release && bv_menu_release)
    {
        bv_menu_release = 0;
        return TRUE;
    }
    if (event == IE_KEYDOWN && key == K_ESCAPE)
    {
        bv_menu_release = key;
        if (!bv_menu_open) BV_MenuSetOpen(TRUE);
        else if (bv_menu_page >= 4) BV_MenuPage(bv_menu_return);
        else if (bv_menu_page) BV_MenuPage(0);
        else BV_MenuSetOpen(FALSE);
        return TRUE;
    }
    if (event == IE_KEYDOWN && key == K_F1)
    {
        bv_menu_release = key;
        BV_MenuSetOpen(!bv_menu_open);
        return TRUE;
    }
    // The console is always reachable, including from a malformed page.
    if (key == K_F12 && (event == IE_KEYDOWN || event == IE_KEYUP)) return FALSE;
    if (!bv_menu_open) return FALSE;
    if (event == IE_JOYAXIS)
    {
        bv_menu_gamepad = TRUE;
        if (key == 0) bv_menu_stick_x = character;
        if (key == 1) bv_menu_stick_y = character;
        return TRUE;
    }
    if (event == IE_MOUSEABS)
    {
        key = key / bv_menu_scale;
        character = character / bv_menu_scale;
        // Cursor capture can warp its position. Establish that baseline before
        // treating subsequent movement as an intentional switch to the mouse.
        if (!bv_menu_mouse_valid)
        {
            bv_menu_mouse_valid = TRUE;
            bv_menu_mouse_x = key; bv_menu_mouse_y = character;
            return TRUE;
        }
        if (bv_menu_mouse_x != key || bv_menu_mouse_y != character) bv_menu_pointer = TRUE;
        bv_menu_mouse_x = key; bv_menu_mouse_y = character;
        hit = BV_MenuHit();
        if (bv_menu_drag >= 0)
        {
            bv_menu_focus = bv_menu_drag;
            BV_MenuSlide(bv_menu_drag);
        }
        else if (hit >= 0 && bv_menu_pointer) bv_menu_focus = hit;
        return TRUE;
    }
    if (event != IE_KEYDOWN && event != IE_KEYUP) return TRUE;
    if (key == K_SHIFT) bv_menu_shift = event == IE_KEYDOWN;
    if (event == IE_KEYUP)
    {
        if (key == K_MOUSE1)
        {
            old = bv_menu_pressed;
            bv_menu_pressed = -1;
            if (bv_menu_drag >= 0) { bv_menu_drag = -1; return TRUE; }
            hit = BV_MenuHit();
            if (hit == old)
            {
                if (old < 0) return TRUE;
                // Clicking a slider label focuses it; only its track changes
                // the value. Toggles still activate anywhere on their row.
                if (bv_menu_action[old] == BV_MENU_SETTING && bv_menu_track_w[old] > 0) return TRUE;
                BV_MenuActivate(hit, 1);
            }
        }
        return TRUE;
    }
    if (key == K_MOUSE1)
    {
        hit = BV_MenuHit(); bv_menu_pressed = hit;
        if (hit >= 0) bv_menu_focus = hit;
        // QuakeC evaluates both sides of &&; guard array indices first.
        if (hit < 0) return TRUE;
        if (bv_menu_action[hit] == BV_MENU_SETTING &&
            bv_menu_track_w[hit] > 0 && bv_menu_mouse_x >= bv_menu_track_x[hit] - 6)
        {
            bv_menu_drag = hit;
            BV_MenuSlide(hit);
        }
        return TRUE;
    }
    if (key == K_MOUSE2)
    {
        bv_menu_release = key;
        if (bv_menu_page >= 4) BV_MenuPage(bv_menu_return);
        else if (bv_menu_page) BV_MenuPage(0);
        else BV_MenuSetOpen(FALSE);
        return TRUE;
    }
    if (key == K_TAB)
    {
        if (bv_menu_count)
        {
            hit = 1;
            if (bv_menu_shift) hit = -1;
            bv_menu_focus = bv_menu_focus + hit;
            if (bv_menu_focus >= bv_menu_count) bv_menu_focus = 0;
            if (bv_menu_focus < 0) bv_menu_focus = bv_menu_count - 1;
        }
        bv_menu_pointer = FALSE;
        return TRUE;
    }
    if ((key == 113 || key == 101) && bv_menu_page < 4)
    {
        hit = 1; if (key == 113) hit = -1;
        BV_MenuPage((bv_menu_page + hit + 4) - floor((bv_menu_page + hit + 4) / 4) * 4);
        return TRUE;
    }
    if (key == K_LEFTARROW || key == K_RIGHTARROW || key == K_UPARROW || key == K_DOWNARROW)
    {
        hit = 1; if (key == K_LEFTARROW) hit = -1;
        if (bv_menu_count && bv_menu_action[bv_menu_focus] == BV_MENU_SETTING &&
            (key == K_LEFTARROW || key == K_RIGHTARROW))
        {
            if (BV_MenuSettingToggle(bv_menu_value[bv_menu_focus])) BV_MenuSettingSet(bv_menu_value[bv_menu_focus], hit > 0);
            else BV_MenuActivate(bv_menu_focus, hit);
        }
        else BV_MenuMoveFocus(key);
        bv_menu_pointer = FALSE;
        return TRUE;
    }
    if (key == K_ENTER || key == K_SPACE || key == K_KP_ENTER)
    {
        bv_menu_release = key;
        BV_MenuActivate(bv_menu_focus, 1);
        return TRUE;
    }
    return TRUE;
};

float(string command) CSQC_ConsoleCommand =
{
    tokenize(command);
    if (argv(0) != "beach_menu") return FALSE;
    BV_MenuSetOpen(!bv_menu_open);
    return TRUE;
};

void() CSQC_Shutdown =
{
    if (bv_menu_open)
    {
        setcursormode(FALSE);
        sendevent("BeachMenu", "f", FALSE);
    }
    bv_menu_open = FALSE;
};

void() BV_MenuInit =
{
    local float i;
    registercommand("beach_menu");
    precache_pic("gfx/bv_logo.tga", 0);
    precache_pic("gfx/bv_menu_icons.tga", 0);
    precache_pic("gfx/bv_menu_court.tga", 0);
    precache_pic("gfx/bv_menu_card.tga", 0);
    if (!bv_menu_visits_recorded)
    {
        bv_menu_visits_recorded = TRUE;
        localcmd(strcat("seta bv_menu_visits ", ftos(autocvar_bv_menu_visits + 1), "\n"));
    }
    bv_menu_pressed = -1; bv_menu_drag = -1;
    for (i = 0; i < 4; i = i + 1) bv_menu_page_focus[i] = -1;
    bv_menu_in_session = !autocvar_bv_menu_auto;
    // Fixture capture and review modes must retain an unobstructed court.
    if (autocvar_bv_menu_auto && !cvar("bv_selftest") && !cvar("bv_visualtest") &&
        !cvar("bv_playtest") && !cvar("bv_matchtest") && !cvar("bv_bottest") &&
        !cvar("bv_receivetest") && !cvar("bv_blocktest") &&
        !cvar("bv_netview") && !cvar("bv_handview")) bv_menu_welcome = TRUE;
};
