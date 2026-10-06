// SPDX-License-Identifier: GPL-2.0-or-later
/* Optional renderer fixture, enabled only with bv_handview. It freezes exact
 * exported hand poses in the playing camera; gameplay tests cover selection.
 */
.float bv_handview_capture;

void(entity player) BV_HandVisualSetup =
{
    player.movetype = MOVETYPE_NONE;
    player.solid = SOLID_NOT;
    player.velocity = '0 0 0';
    player.bv_assisted = FALSE;
    player.bv_overlays = FALSE;
    bv_holder = world;
    bv_ball_state = BV_IDLE;
    bv_ball.modelindex = 0;
    setorigin(player, '-285 0 24');
    player.v_angle = '0 0 0';
    player.angles = player.v_angle;
    player.fixangle = TRUE;
};

void() BV_HandVisualObserve =
{
    local float view, frame;
    view = cvar("bv_handview");
    frame = BV_ANIM_READY;
    if (view == 2) frame = BV_ANIM_SET_LOAD + BV_ANIM_SET_LOAD_COUNT - 1;
    if (view == 3) frame = BV_ANIM_SET + 3;
    if (view == 4) frame = BV_ANIM_FLOAT_LOAD + BV_ANIM_FLOAT_LOAD_COUNT - 1;
    if (view == 5) frame = BV_ANIM_FLOAT_SERVE + 2;
    if (view == 6) frame = BV_ANIM_CUT + 3;
    if (view == 7) frame = BV_VIEW_ANIM_CUT_AWAY + 3;
    self.weaponframe = frame;
    if (time > 2 && !self.bv_handview_capture)
    {
        self.bv_handview_capture = TRUE;
        dprint("BEACH HAND VIEW frame=", ftos(frame), "\n");
        localcmd("con_notifytime 0\ncon_notifylines 0\nscr_fade 0\nscreenshot tga\n");
    }
    if (time > 2.5)
    {
        dprint("BEACH HAND VIEW DONE\n");
        localcmd("quit\n");
    }
};
