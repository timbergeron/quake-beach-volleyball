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

void(float page) BV_MenuPage =
{
    if (bv_menu_page < 4 && bv_menu_count > 0 && bv_menu_focus >= 4)
        bv_menu_page_focus[bv_menu_page] = bv_menu_focus;
    bv_menu_page = page;
    bv_menu_count = 0;
    bv_menu_focus = 4;
    if (page == 2) bv_menu_focus = 7;
    if (page < 4)
        if (bv_menu_page_focus[page] >= 0) bv_menu_focus = bv_menu_page_focus[page];
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

void(float x, float y, float width, float height, string title, string detail,
    float action, float value, float primary) BV_MenuButton =
{
    local float i, focused, inset, text_height, offset, arrow;
    local vector fill, text;
    i = BV_MenuWidget(x, y, width, height, action, value);
    focused = FALSE;
    if (bv_menu_focus == i && !bv_menu_pointer) focused = TRUE;
    fill = '0.085 0.13 0.16'; text = BV_UI_TEXT;
    if (bv_menu_pointer && bv_menu_focus == i) fill = '0.13 0.21 0.24';
    if (primary > 0) { fill = BV_UI_ACCENT; text = '0.025 0.08 0.09'; }
    if (primary < 0) { fill = '0.25 0.105 0.115'; text = '1 0.74 0.7'; }
    if (focused)
        BV_RoundBox(x - 1, y - 1, width + 2, height + 2, 9,
            BV_UI_TEXT, bv_menu_alpha);
    if (bv_menu_pressed == i) fill = fill * 0.8;
    BV_RoundBox(x, y, width, height, 8, fill, bv_menu_alpha);
    offset = bv_menu_pressed == i;
    arrow = FALSE;
    if (action == BV_MENU_PLAY || (action == BV_MENU_PAGE && height >= 40) || primary > 0) arrow = TRUE;
    if (arrow) BV_MenuText(x + width - 22, y + (height - 16) * 0.5 + offset, ">", 16, text, 14);
    inset = 14; if (bv_menu_compact) inset = 10;
    if (detail != "" && height >= 43)
    {
        text_height = 16; if (bv_menu_compact) text_height = 13;
        BV_MenuText(x + inset, y + height * 0.5 - text_height - 2 + offset,
            title, text_height, text, width - inset * 2 - arrow * 14);
        BV_MenuText(x + inset, y + height * 0.5 + 5 + offset, detail,
            10 - bv_menu_compact, text, width - inset * 2);
    }
    else
    {
        text_height = 12;
        if (primary > 0) text_height = 14 - bv_menu_compact;
        BV_MenuText(x + inset, y + (height - text_height) * 0.5 + offset,
            title, text_height, text, width - inset * 2 - arrow * 14);
    }
};

// Navigation and choices are quieter than the one primary court action.
void(float x, float y, float width, float height, string title,
    float action, float value, float selected) BV_MenuChoice =
{
    local float i;
    local vector fill, color;
    i = BV_MenuWidget(x, y, width, height, action, value);
    fill = '0.065 0.105 0.13'; color = BV_UI_MUTED;
    if (selected) { fill = '0.13 0.21 0.24'; color = BV_UI_ACCENT; }
    if (bv_menu_pointer && bv_menu_focus == i) { fill = '0.16 0.25 0.28'; color = BV_UI_TEXT; }
    if (bv_menu_focus == i && !bv_menu_pointer)
        BV_RoundBox(x - 1, y - 1, width + 2, height + 2, 6, BV_UI_TEXT, bv_menu_alpha);
    BV_RoundBox(x, y, width, height, 5, fill, bv_menu_alpha);
    BV_MenuText(x + (width - BV_TextWidth(title, 11)) * 0.5,
        y + (height - 11) * 0.5, title, 11, color, width - 8);
    if (selected && action == BV_MENU_PAGE)
        BV_RoundBox(x + 10, y + height - 2, width - 20, 2, 1, BV_UI_ACCENT, bv_menu_alpha);
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
        if (getstatf(BV_STAT_MATCH))
        {
            bv_menu_request = value;
            bv_menu_return = bv_menu_page;
            BV_MenuPage(4);
        }
        else BV_MenuLaunch(value);
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
};

void(float x, float y, float width, float height, string title, string detail, float setting) BV_MenuSetting =
{
    local float i, value, track, length, fraction, toggle, switch_h, thumb;
    local string label;
    i = BV_MenuWidget(x, y, width, height, BV_MENU_SETTING, setting);
    if (i == bv_menu_focus)
    {
        if (!bv_menu_pointer)
            BV_RoundBox(x - 1, y - 1, width + 2, height + 2, 6, BV_UI_TEXT, bv_menu_alpha);
        BV_RoundBox(x, y, width, height, 5, '0.14 0.22 0.25', bv_menu_alpha);
    }
    BV_MenuText(x + 10, y + height * 0.5 - 12, title, 12, BV_UI_TEXT, width * 0.53 - 16);
    BV_MenuText(x + 10, y + height * 0.5 + 4, detail, 9, BV_UI_MUTED, width * 0.53 - 16);
    value = BV_MenuSettingValue(setting);
    if (BV_MenuSettingToggle(setting))
    {
        label = "Off"; if (value) label = "On";
        BV_MenuText(x + width - 79, y + (height - 10) * 0.5, label, 10, BV_UI_MUTED, 28);
        toggle = x + width - 43;
        switch_h = 16;
        thumb = switch_h - 4;
        BV_RoundBox(toggle, y + (height - switch_h) * 0.5, 30, switch_h, switch_h * 0.5,
            '0.2 0.28 0.3', bv_menu_alpha);
        if (value) BV_RoundBox(toggle, y + (height - switch_h) * 0.5, 30, switch_h,
            switch_h * 0.5, BV_UI_ACCENT, bv_menu_alpha);
        BV_RoundBox(toggle + 2 + (26 - thumb) * (value != 0), y + (height - thumb) * 0.5,
            thumb, thumb, thumb * 0.5, BV_UI_TEXT, bv_menu_alpha);
    }
    else
    {
        track = x + width * 0.54; length = width * 0.46 - 58;
        bv_menu_track_x[i] = track; bv_menu_track_w[i] = length;
        fraction = value;
        label = strcat(ftos(BV_Round(value * 100)), "%");
        if (setting == 4) { fraction = (value - 0.5) / 9.5; label = BV_Decimal(value); }
        if (setting == 5) { fraction = (value - 80) / 40; label = ftos(BV_Round(value)); }
        fraction = BV_Clamp(fraction, 0, 1);
        BV_RoundBox(track, y + height * 0.5 - 2, length, 4, 2, '0.2 0.28 0.3', bv_menu_alpha);
        BV_RoundBox(track, y + height * 0.5 - 2, length * fraction, 4, 2, BV_UI_ACCENT, bv_menu_alpha);
        BV_RoundBox(track + length * fraction - 4, y + height * 0.5 - 4, 8, 8, 4,
            BV_UI_TEXT, bv_menu_alpha);
        BV_MenuText(x + width - 47, y + (height - 10) * 0.5, label, 10, BV_UI_TEXT, 40);
    }
};

string(float impulse) BV_MenuSessionName =
{
    if (impulse == 34) return "doubles";
    if (impulse == 31) return "receive";
    if (impulse == 32) return "set";
    if (impulse == 33) return "attack";
    return "serve";
};

string() BV_MenuScore =
{
    return strcat("Blue ", ftos(getstatf(BV_STAT_HOME_SCORE)), "  :  ",
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
    start = 92; if (bv_menu_compact) start = 78;
    segment = (width - start) / 3;
    if (bv_menu_in_session) BV_MenuText(x, y + 1, "Next match", 11, BV_UI_TEXT, start - 8);
    else BV_MenuText(x, y + 1, "Play to", 11, BV_UI_TEXT, start - 8);
    BV_MenuText(x, y + 16, "Win by two", 8, BV_UI_MUTED, start - 8);
    for (i = 0; i < 3; i = i + 1)
    {
        points = 7; if (i == 1) points = 11; if (i == 2) points = 21;
        BV_MenuChoice(x + start + segment * i, y, segment - 4, 29,
            ftos(points), BV_MENU_POINTS, points, cvar("bv_match_points") == points);
    }
};

void(float x, float y, float width, float height, string number, string title, string detail) BV_MenuStep =
{
    BV_RoundBox(x, y + (height - 23) * 0.5, 23, 23, 6, '0.13 0.21 0.24', bv_menu_alpha);
    BV_MenuText(x + 8, y + (height - 12) * 0.5, number, 12, BV_UI_ACCENT, 15);
    if (height >= 35)
    {
        BV_MenuText(x + 34, y + height * 0.5 - 13, title, 12, BV_UI_TEXT, width - 34);
        BV_MenuText(x + 34, y + height * 0.5 + 5, detail, 9, BV_UI_MUTED, width - 34);
    }
    else BV_MenuText(x + 34, y + (height - 12) * 0.5, title, 12, BV_UI_TEXT, width - 34);
};

float(vector viewport) BV_MenuDraw =
{
    local float x, y, width, height, pad, inner, column, gap, top, bottom, body, row, i, tab, card, footer, canvas_height;
    local vector logo_position, logo_size;
    local string title, subtitle, label, detail;
    if (bv_menu_welcome && getstatf(BV_STAT_STATE) > 0)
    {
        bv_menu_welcome = FALSE;
        BV_MenuSetOpen(TRUE);
    }
    if (!bv_menu_open) return FALSE;
    // Reserve a logo header above the tabs without shrinking the page body.
    // A minimum canvas keeps three settings rows and explanations readable.
    // Drawing and absolute pointer input share this exact transform.
    bv_menu_compact = viewport_y < 344 || viewport_x < 464;
    canvas_height = 456; if (bv_menu_compact) canvas_height = 416;
    bv_menu_scale = BV_Clamp(viewport_y / canvas_height, 0.1, 1);
    bv_menu_scale = BV_Clamp(viewport_x / 360, 0.1, bv_menu_scale);
    viewport = viewport / bv_menu_scale;
    bv_ui_scale = bv_menu_scale;
    bv_menu_viewport = viewport;
    width = BV_Clamp(viewport_x - 24, 0, 640);
    height = BV_Clamp(viewport_y - 24, 0, 432);
    pad = 22; gap = 10;
    if (bv_menu_compact) { pad = 16; gap = 8; }
    inner = width - pad * 2;
    column = (inner - gap) * 0.5;
    x = (viewport_x - width) * 0.5;
    y = (viewport_y - height) * 0.5;
    bv_menu_alpha = BV_Clamp((gettime() - bv_menu_started) * 10, 0, 1);
    bv_menu_count = 0;
    BV_Box(0, 0, viewport_x, viewport_y, '0.012 0.035 0.05', 0.62 * bv_menu_alpha);
    if (bv_menu_page >= 4)
    {
        BV_MenuConfirmation(viewport);
        bv_ui_scale = 1;
        return TRUE;
    }
    BV_Panel(x, y, width, height, bv_menu_alpha);
    logo_position = '0 0 0';
    logo_position_x = x + (width - 144) * 0.5;
    logo_position_y = y + 8;
    logo_size = '144 108 0';
    drawsubpic(logo_position * bv_menu_scale, logo_size * bv_menu_scale,
        "gfx/bv_logo.tga", '0 0 0', '1 1 0', '1 1 1', bv_menu_alpha, 0);
    BV_RoundBox(x + width - pad - 71, y + 15, 4, 4, 2, BV_UI_GOLD, bv_menu_alpha);
    BV_MenuText(x + width - pad - 61, y + 12, "COURT LIVE", 9, BV_UI_MUTED, 61);
    tab = inner / 4;
    for (i = 0; i < 4; i = i + 1)
    {
        label = "Play";
        if (i == 1) label = "Practice";
        if (i == 2) label = "Settings";
        if (i == 3) label = "Learn";
        BV_MenuChoice(x + pad + i * tab, y + 128, tab - 4, 26, label, BV_MENU_PAGE, i, bv_menu_page == i);
    }
    title = "Ready to play?";
    subtitle = "Play local doubles with three bots, or practice a stroke.";
    if (bv_menu_in_session)
    {
        title = BV_ModeLabel(getstatf(BV_STAT_MODE));
        subtitle = "Pick up where you left off, or try something new.";
        if (getstatf(BV_STAT_MATCH)) { title = "Doubles"; subtitle = BV_MenuScore(); }
    }
    if (bv_menu_page == 1) { title = "Practice"; subtitle = "Start with a serve. Build your way to a rally."; }
    if (bv_menu_page == 2) { title = "Settings"; subtitle = "Make it comfortable. Changes apply immediately."; }
    if (bv_menu_page == 3) { title = "Your first serve"; subtitle = "Three simple steps. Then try it on the court."; }
    top = y + 172;
    BV_MenuText(x + pad, top, title, 25 - bv_menu_compact * 5, BV_UI_TEXT, inner);
    if (!bv_menu_compact) BV_MenuText(x + pad, top + 34, subtitle, 11, BV_UI_MUTED, inner);
    else if (!bv_menu_page && getstatf(BV_STAT_MATCH))
        BV_MenuText(x + width - pad - 125, top + 4, subtitle, 11, BV_UI_TEXT, 125);
    top = y + 226; if (bv_menu_compact) top = y + 202;
    bottom = y + height - 60;
    body = bottom - top;
    if (bv_menu_page == 0)
    {
        if (bv_menu_in_session)
        {
            card = (body - gap * 2 - 29) * 0.5;
            label = "Resume practice";
            detail = "Return to your current drill";
            if (getstatf(BV_STAT_MATCH)) { label = "Resume match"; detail = "Keep the rally going"; }
            BV_MenuButton(x + pad, top, inner, card, label, detail, BV_MENU_CLOSE, 0, TRUE);
            label = "New doubles match"; if (bv_menu_compact) label = "New match";
            BV_MenuButton(x + pad, top + card + gap, column, card, label, "", BV_MENU_PLAY, 34, FALSE);
            BV_MenuButton(x + pad + column + gap, top + card + gap, column, card,
                "Change drill", "", BV_MENU_PAGE, 1, FALSE);
            BV_MenuPoints(x + pad, bottom - 29, inner);
        }
        else
        {
            card = body - gap * 2 - 29 - 27;
            BV_MenuButton(x + pad, top, column, card, "Play doubles", "1 player + 3 bots", BV_MENU_PLAY, 34, TRUE);
            BV_MenuButton(x + pad + column + gap, top, column, card, "Practice", "Learn one stroke at a time", BV_MENU_PAGE, 1, FALSE);
            BV_MenuPoints(x + pad, top + card + gap, inner);
            BV_MenuButton(x + pad, bottom - 27, inner, 27, "New here? Learn your first serve", "", BV_MENU_PAGE, 3, FALSE);
        }
    }
    if (bv_menu_page == 1)
    {
        card = (body - gap) * 0.5;
        BV_MenuButton(x + pad, top, column, card, "Serve", "Start here | Toss and timing", BV_MENU_PLAY, 30, TRUE);
        BV_MenuButton(x + pad + column + gap, top, column, card, "Receive", "Read and cushion the ball", BV_MENU_PLAY, 31, FALSE);
        BV_MenuButton(x + pad, top + card + gap, column, card, "Set", "Lift to your teammate", BV_MENU_PLAY, 32, FALSE);
        BV_MenuButton(x + pad + column + gap, top + card + gap, column, card, "Attack", "Jump and find a gap", BV_MENU_PLAY, 33, FALSE);
    }
    if (bv_menu_page == 2)
    {
        tab = (inner - gap * 2) / 3;
        BV_MenuChoice(x + pad, top, tab, 24, "Gameplay", BV_MENU_CATEGORY, 0, bv_menu_settings_page == 0);
        BV_MenuChoice(x + pad + tab + gap, top, tab, 24, "Sound & look", BV_MENU_CATEGORY, 1, bv_menu_settings_page == 1);
        BV_MenuChoice(x + pad + (tab + gap) * 2, top, tab, 24, "HUD", BV_MENU_CATEGORY, 2, bv_menu_settings_page == 2);
        top = top + 31;
        row = (bottom - top) / 3;
        if (!bv_menu_settings_page)
        {
            BV_MenuSetting(x + pad, top, inner, row - 4, "Contact assist", "Auto contact while holding a shot.", 0);
            BV_MenuSetting(x + pad, top + row, inner, row - 4, "Landing guide", "Preview where your shot will land.", 1);
            BV_MenuSetting(x + pad, top + row * 2, inner, row - 4, "Contact motion", "A small camera pulse on contact.", 2);
        }
        else if (bv_menu_settings_page == 1)
        {
            BV_MenuSetting(x + pad, top, inner, row - 4, "Sound volume", "Adjust the game's sound level.", 3);
            BV_MenuSetting(x + pad, top + row, inner, row - 4, "Mouse speed", "How quickly the camera turns.", 4);
            BV_MenuSetting(x + pad, top + row * 2, inner, row - 4, "Field of view", "Wider shows more of the court.", 5);
        }
        else
        {
            BV_MenuSetting(x + pad, top, inner, row - 4, "Court map", "Show player and ball positions.", 6);
            BV_MenuSetting(x + pad, top + row, inner, row - 4, "Coaching tips", "Show guidance during each rally.", 7);
            BV_MenuSetting(x + pad, top + row * 2, inner, row - 4, "Shot details", "Show spin, placement and shot stats.", 8);
        }
    }
    if (bv_menu_page == 3)
    {
        row = (body - 34 - gap) / 3;
        BV_MenuStep(x + pad, top, inner, row, "1", "Aim across the net", "Move with WASD. Look with the mouse.");
        BV_MenuStep(x + pad, top + row, inner, row, "2", "Hold left click to toss", "Settle your feet while preparing.");
        BV_MenuStep(x + pad, top + row * 2, inner, row, "3", "Release near the top", "Meet the ball with your hands.");
        BV_MenuButton(x + pad, bottom - 34, column, 34, "Try a serve", "", BV_MENU_PLAY, 30, TRUE);
        BV_MenuButton(x + pad + column + gap, bottom - 34, column, 34, "All controls", "", BV_MENU_HELP, 0, FALSE);
    }
    // The exit and advanced options stay put, with hints even in small windows.
    footer = y + height - 43;
    BV_Box(x + pad, footer - 7, inner, 0.5, '0.23 0.32 0.35', bv_menu_alpha * 0.6);
    column = (inner - gap * 2) / 3;
    label = "Back to court"; if (bv_menu_compact) label = "Resume";
    if (!bv_menu_in_session) label = "Explore court";
    BV_MenuButton(x + pad, footer, column, 26, label, "", BV_MENU_CLOSE, 0, FALSE);
    label = "Video & controls"; if (bv_menu_compact) label = "Video & keys";
    BV_MenuButton(x + pad + column + gap, footer, column, 26, label, "", BV_MENU_ENGINE, 0, FALSE);
    BV_MenuButton(x + pad + (column + gap) * 2, footer, column, 26, "Quit game", "", BV_MENU_QUIT, 0, FALSE);
    BV_MenuText(x + pad, y + height - 11, "Arrows Move   Enter Choose   Q/E Tabs   Esc Back", 8, BV_UI_MUTED, inner);
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
    if (event == IE_MOUSEABS)
    {
        key = key / bv_menu_scale;
        character = character / bv_menu_scale;
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
    bv_menu_pressed = -1; bv_menu_drag = -1;
    for (i = 0; i < 4; i = i + 1) bv_menu_page_focus[i] = -1;
    bv_menu_in_session = !autocvar_bv_menu_auto;
    // Fixture capture and review modes must retain an unobstructed court.
    if (autocvar_bv_menu_auto && !cvar("bv_selftest") && !cvar("bv_visualtest") &&
        !cvar("bv_playtest") && !cvar("bv_matchtest") && !cvar("bv_bottest") &&
        !cvar("bv_receivetest") && !cvar("bv_blocktest") &&
        !cvar("bv_netview") && !cvar("bv_handview")) bv_menu_welcome = TRUE;
};
