// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
// Exercise real CSQC entry points and server commands, not a second UI model.
float bv_menu_test_stage, bv_menu_test_at, bv_menu_test_pass, bv_menu_test_fail;
float bv_menu_test_captured_stage;

void(float ok, string name) BV_MenuAssert =
{
    if (ok) { bv_menu_test_pass = bv_menu_test_pass + 1; dprint("BEACH MENU PASS ", name, "\n"); }
    else { bv_menu_test_fail = bv_menu_test_fail + 1; dprint("BEACH MENU FAIL ", name, "\n"); }
};

void(float key) BV_MenuTestKey =
{
    CSQC_InputEvent(IE_KEYDOWN, key, 0, 0);
    CSQC_InputEvent(IE_KEYUP, key, 0, 0);
};

float(float action, float value) BV_MenuTestFind =
{
    local float i;
    for (i = 0; i < bv_menu_count; i = i + 1)
        if (bv_menu_action[i] == action && bv_menu_value[i] == value) return i;
    return -1;
};

void(float x, float y) BV_MenuTestMouse =
{
    CSQC_InputEvent(IE_MOUSEABS, x * bv_menu_scale, y * bv_menu_scale, 0);
};

void(float index) BV_MenuTestClick =
{
    if (index < 0) { BV_MenuAssert(FALSE, "click-target-exists"); return; }
    BV_MenuTestMouse(bv_menu_x[index] + bv_menu_w[index] * 0.5,
        bv_menu_y[index] + bv_menu_h[index] * 0.5);
    CSQC_InputEvent(IE_KEYDOWN, K_MOUSE1, 0, 0);
    CSQC_InputEvent(IE_KEYUP, K_MOUSE1, 0, 0);
};

void() BV_MenuTestBounds =
{
    local float i, j, valid;
    valid = bv_menu_count > 0;
    for (i = 0; i < bv_menu_count; i = i + 1)
    {
        if (bv_menu_x[i] < 0 || bv_menu_y[i] < 0 || bv_menu_w[i] <= 0 || bv_menu_h[i] <= 0 ||
            bv_menu_x[i] + bv_menu_w[i] > bv_menu_viewport_x ||
            bv_menu_y[i] + bv_menu_h[i] > bv_menu_viewport_y) valid = FALSE;
        for (j = i + 1; j < bv_menu_count; j = j + 1)
            if (bv_menu_x[i] < bv_menu_x[j] + bv_menu_w[j] &&
                bv_menu_x[i] + bv_menu_w[i] > bv_menu_x[j] &&
                bv_menu_y[i] < bv_menu_y[j] + bv_menu_h[j] - 0.01 &&
                bv_menu_y[i] + bv_menu_h[i] > bv_menu_y[j] + 0.01) valid = FALSE;
    }
    BV_MenuAssert(valid, "visible-widgets-fit-without-overlap");
};

void() BV_MenuTestFrame =
{
    local float stage, index, consumed;
    if (!cvar("bv_menutest") || time < 0.5 || !getstatf(BV_STAT_STATE)) return;
    // The first HUD draw opens the arrival screen after stats are available.
    if (bv_menu_test_stage == 0 && bv_menu_welcome) return;
    if (time < bv_menu_test_at) return;
    bv_menu_test_at = time + 0.2;
    stage = bv_menu_test_stage;
    // Keep the page unchanged until the engine has read back the frame.
    // A queued screenshot followed by a page change captures the next page.
    if ((stage == 1 || stage == 2 || stage == 4 || stage == 6 || stage == 9 || stage == 10 ||
         stage == 24 || stage == 25) &&
        bv_menu_test_captured_stage != stage)
    {
        bv_menu_test_captured_stage = stage;
        localcmd("screenshot tga\n");
        return;
    }
    bv_menu_test_stage = stage + 1;
    if (stage == 0)
    {
        if (cvar("bv_menu_auto"))
        {
            BV_MenuAssert(bv_menu_open && getcursormode(), "arrival-menu-opens-after-stats");
        }
        else BV_MenuTestKey(K_ESCAPE);
        BV_MenuAssert(bv_menu_open && getcursormode(), "escape-opens-and-releases-cursor");
    }
    if (stage == 1)
    {
        BV_MenuTestBounds();
        BV_MenuAssert(!bv_menu_in_session && bv_menu_focus == 4,
            "arrival-focuses-a-clear-first-action");
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_POINTS, 11));
        BV_MenuAssert(cvar("bv_match_points") == 11, "visible-match-length-choice-applies");
        BV_MenuTestKey(K_RIGHTARROW);
        BV_MenuAssert(cvar("bv_match_points") == 21 && bv_menu_value[bv_menu_focus] == 21,
            "arrows-select-adjacent-match-length");
        BV_MenuTestKey(K_LEFTARROW); BV_MenuTestKey(K_LEFTARROW);
        BV_MenuAssert(cvar("bv_match_points") == 7, "match-length-can-return-to-seven");
        bv_menu_focus = 0;
        CSQC_InputEvent(IE_KEYDOWN, K_SHIFT, 0, 0); BV_MenuTestKey(K_TAB); CSQC_InputEvent(IE_KEYUP, K_SHIFT, 0, 0);
        BV_MenuAssert(bv_menu_focus == bv_menu_count - 1, "keyboard-focus-wraps-backward");
        BV_MenuTestKey(K_TAB);
        BV_MenuAssert(bv_menu_focus == 0, "keyboard-focus-wraps-forward");
        CSQC_InputEvent(IE_KEYDOWN, K_SHIFT, 0, 0); BV_MenuTestKey(K_TAB); CSQC_InputEvent(IE_KEYUP, K_SHIFT, 0, 0);
        BV_MenuAssert(bv_menu_focus == bv_menu_count - 1, "shift-tab-navigates-backward");
        BV_MenuTestKey(101);
    }
    if (stage == 2)
    {
        BV_MenuAssert(bv_menu_page == 1, "tab-shortcut-opens-practice");
        BV_MenuTestBounds();
        bv_menu_focus = BV_MenuTestFind(BV_MENU_PLAY, 30);
        BV_MenuTestKey(K_RIGHTARROW);
        BV_MenuAssert(bv_menu_value[bv_menu_focus] == 31, "right-arrow-follows-practice-row");
        BV_MenuTestKey(K_DOWNARROW);
        BV_MenuAssert(bv_menu_value[bv_menu_focus] == 33, "down-arrow-follows-practice-column");
        BV_MenuTestKey(K_RIGHTARROW);
        BV_MenuAssert(bv_menu_value[bv_menu_focus] == 33, "horizontal-focus-stops-at-grid-edge");
        BV_MenuTestKey(K_LEFTARROW);
        BV_MenuAssert(bv_menu_value[bv_menu_focus] == 32, "left-arrow-follows-practice-row");
        BV_MenuTestKey(K_UPARROW);
        BV_MenuAssert(bv_menu_value[bv_menu_focus] == 30, "up-arrow-follows-practice-column");
        index = BV_MenuTestFind(BV_MENU_PLAY, 30);
        BV_MenuTestMouse(bv_menu_x[index] + 12, bv_menu_y[index] + 12);
        CSQC_InputEvent(IE_KEYDOWN, K_MOUSE1, 0, 0);
        BV_MenuTestMouse(0, 0); CSQC_InputEvent(IE_KEYUP, K_MOUSE1, 0, 0);
        BV_MenuAssert(bv_menu_open, "drag-off-cancels-button");
        bv_menu_focus = index;
        consumed = CSQC_InputEvent(IE_KEYDOWN, K_ENTER, 0, 0);
        BV_MenuAssert(consumed && !bv_menu_open && !getcursormode(), "enter-starts-serve-and-captures-mouse");
        BV_MenuAssert(CSQC_InputEvent(IE_KEYUP, K_ENTER, 0, 0), "closing-key-up-does-not-leak");
    }
    if (stage == 3)
    {
        BV_MenuAssert(!getstatf(BV_STAT_MATCH) && getstatf(BV_STAT_MODE) == 0 &&
            getstatf(BV_STAT_STATE) == BV_HELD, "serve-command-reaches-server");
        BV_MenuAssert(!getstatf(BV_STAT_AIM_LOCKED), "menu-click-does-not-charge-shot");
        BV_MenuTestKey(K_F1);
        BV_MenuAssert(bv_menu_in_session && bv_menu_focus == 4,
            "reopened-menu-prioritizes-resume");
        BV_MenuTestKey(101); BV_MenuTestKey(101);
    }
    if (stage == 4)
    {
        BV_MenuAssert(bv_menu_open && bv_menu_page == 2, "f1-opens-and-tabs-select-settings");
        BV_MenuTestBounds();
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_SETTING, 0));
        BV_MenuAssert(BV_MenuSettingValue(0), "toggle-feedback-is-immediate");
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_SETTING, 0));
        BV_MenuAssert(!BV_MenuSettingValue(0), "rapid-toggle-reversal-is-not-lost");
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_SETTING, 0));
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_SETTING, 1));
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_SETTING, 2));
        BV_MenuAssert(!cvar("bv_contact_kick"), "camera-pulse-toggle-applies");
        bv_menu_focus = BV_MenuTestFind(BV_MENU_SETTING, 2);
        BV_MenuTestKey(K_LEFTARROW);
        BV_MenuAssert(!cvar("bv_contact_kick"), "left-arrow-keeps-toggle-disabled");
        BV_MenuTestKey(K_RIGHTARROW); BV_MenuTestKey(K_RIGHTARROW);
        BV_MenuAssert(cvar("bv_contact_kick"), "right-arrow-keeps-toggle-enabled");
        BV_MenuTestKey(K_LEFTARROW);
        BV_MenuAssert(CSQC_InputEvent(IE_KEYDOWN, 119, 0, 0), "menu-consumes-movement");
        BV_MenuAssert(!CSQC_InputEvent(IE_KEYDOWN, K_F12, 0, 0), "console-remains-accessible");
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_CATEGORY, 1));
    }
    if (stage == 5)
    {
        BV_MenuAssert(getstatf(BV_STAT_ASSISTED) && !getstatf(BV_STAT_OVERLAYS),
            "simultaneous-options-reach-server");
        BV_MenuAssert(bv_menu_settings_page == 1, "sound-and-look-group-opens");
        BV_MenuTestBounds();
        index = BV_MenuTestFind(BV_MENU_SETTING, 3);
        consumed = cvar("volume");
        BV_MenuTestClick(index);
        BV_MenuAssert(cvar("volume") == consumed, "slider-label-focuses-without-changing-value");
        BV_MenuTestMouse(bv_menu_track_x[index], bv_menu_y[index] + bv_menu_h[index] * 0.5);
        CSQC_InputEvent(IE_KEYDOWN, K_MOUSE1, 0, 0);
        BV_MenuAssert(cvar("volume") == 0, "slider-click-reaches-minimum");
        BV_MenuTestMouse(bv_menu_track_x[index] + bv_menu_track_w[index] * 0.5,
            bv_menu_y[index] + bv_menu_h[index] * 2.5);
        BV_MenuAssert(bv_menu_focus == index && bv_menu_drag == index &&
            fabs(cvar("volume") - 0.5) < 0.001, "slider-keeps-focus-when-drag-crosses-rows");
        BV_MenuTestMouse(bv_menu_track_x[index] + bv_menu_track_w[index] + 100,
            bv_menu_y[index] + bv_menu_h[index] * 0.5);
        CSQC_InputEvent(IE_KEYUP, K_MOUSE1, 0, 0);
        BV_MenuAssert(cvar("volume") == 1 && bv_menu_drag < 0, "slider-captures-drag-and-clamps-maximum");
        bv_menu_focus = index; BV_MenuTestKey(K_LEFTARROW);
        BV_MenuAssert(fabs(cvar("volume") - 0.9) < 0.001, "keyboard-adjusts-slider");
        BV_MenuSettingSet(4, -100); BV_MenuSettingSet(5, 999);
        BV_MenuAssert(cvar("sensitivity") == 0.5 && cvar("fov") == 120, "look-settings-clamp-safely");
        bv_menu_focus = BV_MenuTestFind(BV_MENU_CATEGORY, 1);
        BV_MenuTestKey(K_LEFTARROW);
        BV_MenuAssert(!bv_menu_settings_page, "arrows-switch-settings-group-left");
        BV_MenuTestKey(K_RIGHTARROW);
        BV_MenuAssert(bv_menu_settings_page == 1, "arrows-switch-settings-group-right");
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_PAGE, 3));
    }
    if (stage == 6)
    {
        BV_MenuAssert(bv_menu_page == 3, "learn-page-opens");
        BV_MenuTestBounds();
        BV_MenuTestKey(K_ESCAPE);
        BV_MenuAssert(bv_menu_open && bv_menu_page == 0, "escape-returns-to-home");
    }
    if (stage == 7) BV_MenuTestClick(BV_MenuTestFind(BV_MENU_PLAY, 34));
    if (stage == 8)
    {
        BV_MenuAssert(!bv_menu_open && getstatf(BV_STAT_MATCH), "doubles-command-starts-real-match");
        BV_MenuAssert(getstatf(BV_STAT_ASSISTED) && !getstatf(BV_STAT_OVERLAYS),
            "new-match-preserves-player-options");
        BV_MenuTestKey(K_ESCAPE);
    }
    if (stage == 9)
    {
        BV_MenuAssert(bv_menu_action[bv_menu_focus] == BV_MENU_CLOSE,
            "live-match-default-is-resume");
        BV_MenuTestBounds();
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_PLAY, 34));
    }
    if (stage == 10)
    {
        BV_MenuAssert(bv_menu_page == 4 && getstatf(BV_STAT_MATCH), "restart-needs-session-confirmation");
        BV_MenuTestBounds();
        BV_MenuAssert(bv_menu_focus == 0 && bv_menu_count == 2, "confirmation-defaults-to-cancel");
        BV_MenuTestKey(101);
        BV_MenuAssert(bv_menu_page == 4, "confirmation-traps-page-shortcuts");
        BV_MenuTestMouse(0, 0);
        CSQC_InputEvent(IE_KEYDOWN, K_MOUSE1, 0, 0); CSQC_InputEvent(IE_KEYUP, K_MOUSE1, 0, 0);
        BV_MenuAssert(bv_menu_page == 4, "outside-click-keeps-confirmation");
        BV_MenuTestKey(K_ESCAPE);
        BV_MenuAssert(bv_menu_page == 0 && getstatf(BV_STAT_MATCH), "cancel-keeps-current-match");
        BV_MenuTestKey(101);
    }
    if (stage == 11) BV_MenuTestClick(BV_MenuTestFind(BV_MENU_PLAY, 31));
    if (stage == 12) BV_MenuTestClick(BV_MenuTestFind(BV_MENU_BACK, 0));
    if (stage == 13)
    {
        BV_MenuAssert(bv_menu_page == 1 && getstatf(BV_STAT_MATCH), "cancel-returns-to-originating-page");
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_PLAY, 31));
    }
    if (stage == 14) BV_MenuTestClick(BV_MenuTestFind(BV_MENU_ACCEPT, 0));
    if (stage == 15)
    {
        BV_MenuAssert(!bv_menu_open && !getstatf(BV_STAT_MATCH) && getstatf(BV_STAT_MODE) == 1,
            "confirmed-receive-replaces-match");
        BV_MenuTestKey(K_ESCAPE); BV_MenuTestKey(101);
    }
    if (stage == 16) BV_MenuTestClick(BV_MenuTestFind(BV_MENU_PLAY, 32));
    if (stage == 17)
    {
        BV_MenuAssert(!bv_menu_open && getstatf(BV_STAT_MODE) == 2, "setting-command-reaches-server");
        BV_MenuTestKey(K_ESCAPE); BV_MenuTestKey(101);
    }
    if (stage == 18) BV_MenuTestClick(BV_MenuTestFind(BV_MENU_PLAY, 33));
    if (stage == 19)
    {
        BV_MenuAssert(!bv_menu_open && getstatf(BV_STAT_MODE) == 3, "attack-command-reaches-server");
        BV_MenuTestKey(K_ESCAPE);
    }
    if (stage == 20) BV_MenuTestClick(BV_MenuTestFind(BV_MENU_QUIT, 0));
    if (stage == 21)
    {
        BV_MenuAssert(bv_menu_page == 5, "quit-needs-confirmation");
        BV_MenuTestKey(K_ESCAPE); BV_MenuTestKey(K_ESCAPE);
        BV_MenuAssert(!bv_menu_open && !getcursormode(), "back-stack-releases-cursor");
        CSQC_ConsoleCommand("beach_menu");
        BV_MenuAssert(bv_menu_open, "console-command-opens-menu");
        CSQC_ConsoleCommand("beach_menu");
        BV_MenuAssert(!bv_menu_open && !CSQC_ConsoleCommand("unhandled"), "console-command-closes-with-fallback");
        BV_MenuAssert(!CSQC_InputEvent(IE_KEYDOWN, 119, 0, 0), "court-input-restored");
        sendevent("BeachOption", "ff", 0, FALSE);
        localcmd("+attack\n");
    }
    if (stage == 22)
    {
        BV_MenuAssert(getstatf(BV_STAT_AIM_LOCKED) && getstatf(BV_STAT_CHARGE) > 0,
            "court-can-prepare-held-shot");
        BV_MenuTestKey(K_ESCAPE);
    }
    if (stage == 23)
    {
        BV_MenuAssert(!getstatf(BV_STAT_AIM_LOCKED) && getstatf(BV_STAT_CHARGE) == 0,
            "opening-menu-cancels-held-shot");
        BV_MenuTestKey(101); BV_MenuTestKey(101);
    }
    if (stage == 24)
    {
        BV_MenuAssert(bv_menu_page == 2 && bv_menu_settings_page == 1,
            "settings-remembers-selected-group");
        BV_MenuTestBounds();
        BV_MenuTestKey(101);
    }
    if (stage == 25)
    {
        BV_MenuAssert(bv_menu_page == 3 && BV_MenuTestFind(BV_MENU_PLAY, 30) >= 0,
            "first-serve-guide-offers-direct-practice");
        BV_MenuAssert(BV_MenuTestFind(BV_MENU_HELP, 0) >= 0, "first-serve-guide-offers-full-controls");
        BV_MenuTestClick(BV_MenuTestFind(BV_MENU_PLAY, 30));
    }
    if (stage == 26)
    {
        BV_MenuAssert(!bv_menu_open && getstatf(BV_STAT_MODE) == 0 && getstatf(BV_STAT_STATE) == BV_HELD,
            "guided-first-serve-starts-real-practice");
        BV_MenuTestKey(K_ESCAPE);
    }
    if (stage == 27) BV_MenuTestKey(K_ENTER);
    if (stage == 28)
    {
        BV_MenuAssert(!bv_menu_open && !getcursormode() && getstatf(BV_STAT_STATE) == BV_HELD,
            "default-enter-resumes-without-restarting");
        BV_MenuTestKey(K_F1);
        BV_MenuTestKey(113);
    }
    if (stage == 29) BV_MenuTestClick(BV_MenuTestFind(BV_MENU_HELP, 0));
    if (stage == 30)
    {
        BV_MenuAssert(!bv_menu_open && cvar("bv_help"), "full-controls-opens-court-help");
        dprint("BEACH MENU DONE pass=", ftos(bv_menu_test_pass), " fail=", ftos(bv_menu_test_fail), "\n");
        localcmd("quit\n");
    }
};
