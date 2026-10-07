// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 timbergeron
// ABI adapted from QSS-M on 2026-10-04; see THIRD_PARTY.md.
/* NetQuake version-6 ABI. Keep the system globals and fields in this order.
 * Shared by SSQC and QSS-M's simple CSQC HUD; no engine changes required.
 */

#pragma warning disable F210

entity self;
entity other;
entity world;
float time;
float frametime;
float force_retouch;
string mapname;
float deathmatch;
float coop;
float teamplay;
float serverflags;
float total_secrets;
float total_monsters;
float found_secrets;
float killed_monsters;
float parm1, parm2, parm3, parm4, parm5, parm6, parm7, parm8;
float parm9, parm10, parm11, parm12, parm13, parm14, parm15, parm16;
vector v_forward, v_up, v_right;
float trace_allsolid;
float trace_startsolid;
float trace_fraction;
vector trace_endpos;
vector trace_plane_normal;
float trace_plane_dist;
entity trace_ent;
float trace_inopen;
float trace_inwater;
entity msg_entity;

#ifdef CSQC
var void() main;
var void() StartFrame;
var void() PlayerPreThink;
var void() PlayerPostThink;
var void() ClientKill;
var void() ClientConnect;
var void() PutClientInServer;
var void() ClientDisconnect;
var void() SetNewParms;
var void() SetChangeParms;
#else
void() main;
void() StartFrame;
void() PlayerPreThink;
void() PlayerPostThink;
void() ClientKill;
void() ClientConnect;
void() PutClientInServer;
void() ClientDisconnect;
void() SetNewParms;
void() SetChangeParms;
#endif
void end_sys_globals;

.float modelindex;
.vector absmin, absmax;
.float ltime;
.float movetype;
.float solid;
.vector origin;
.vector oldorigin;
.vector velocity;
.vector angles;
.vector avelocity;
.vector punchangle;
.string classname;
.string model;
.float frame;
.float skin;
.float effects;
.vector mins, maxs;
.vector size;
.void() touch;
.void() use;
.void() think;
.void() blocked;
.float nextthink;
.entity groundentity;
.float health;
.float frags;
.float weapon;
.string weaponmodel;
.float weaponframe;
.float currentammo;
.float ammo_shells, ammo_nails, ammo_rockets, ammo_cells;
.float items;
.float takedamage;
.entity chain;
.float deadflag;
.vector view_ofs;
.float button0, button1, button2;
.float impulse;
.float fixangle;
.vector v_angle;
.float idealpitch;
.string netname;
.entity enemy;
.float flags;
.float colormap;
.float team;
.float max_health;
.float teleport_time;
.float armortype;
.float armorvalue;
.float waterlevel;
.float watertype;
.float ideal_yaw;
.float yaw_speed;
.entity aiment;
.entity goalentity;
.float spawnflags;
.string target;
.string targetname;
.float dmg_take;
.float dmg_save;
.entity dmg_inflictor;
.entity owner;
.vector movedir;
.string message;
.float sounds;
.string noise, noise1, noise2, noise3;
void end_sys_fields;

const float FALSE = 0;
const float TRUE = 1;
float MOVETYPE_NONE = 0;
float MOVETYPE_WALK = 3;
float MOVETYPE_STEP = 4;
float MOVETYPE_PUSH = 7;
float MOVETYPE_NOCLIP = 8;
float SOLID_NOT = 0;
float SOLID_TRIGGER = 1;
float SOLID_BBOX = 2;
float SOLID_BSP = 4;
float FL_FLY = 1;
float FL_ONGROUND = 512;

void(entity entity_to_move, vector new_origin) setorigin = #2;
void(entity entity_to_model, string model_name) setmodel = #3;
void(entity entity_to_size, vector new_mins, vector new_maxs) setsize = #4;
entity() spawn = #14;
void(vector start, vector end, float nomonsters, entity ignore) traceline = #16;
string(string sample) precache_sound = #19;
void(string text, ...) bprint = #23;
void(string text, ...) dprint = #25;
string(float value) ftos = #26;
float(float value) fabs = #43;
float(string name) cvar = #45;
void(string command) localcmd = #46;
float(string extension_name) checkextension = #99;

void(vector angles) makevectors = #1;
float() random = #7;
void(entity e, float channel, string sample, float volume, float attenuation) sound = #8;
vector(vector value) normalize = #9;
void(string text) error = #10;
float(vector value) vlen = #12;
float(vector direction) vectoyaw = #13;
float(float yaw, float distance) walkmove = #32;
float() droptofloor = #34;
void(entity e) remove = #15;
entity(entity start, .string field, string match) find = #18;
string(string name) precache_model = #20;
void(entity e, string text) stuffcmd = #21;
void(entity e, string text, ...) sprint = #24;
void(float style, string pattern) lightstyle = #35;
float(float value) floor = #37;
entity(entity e) nextent = #47;
void(vector position, vector direction, float color, float count) particle = #48;
float(float angle) sin = #60;
float(float angle) cos = #61;
float(float value) sqrt = #62;
float(float y, float x) atan2 = #474;
void(string name, string value) cvar_set = #72;
void(entity e, string text) centerprint = #73;
void(vector position, string sample, float volume, float attenuation) ambientsound = #74;
string(string first, string second, ...) strcat = #115;

#ifdef CSQC
// FTE CSQC event/key codes, also used by QSS-M's Key_NativeToQC.
const float IE_KEYDOWN = 0, IE_KEYUP = 1, IE_MOUSEABS = 3;
const float K_TAB = 9, K_ENTER = 13, K_ESCAPE = 27, K_SPACE = 32;
const float K_UPARROW = 128, K_DOWNARROW = 129, K_LEFTARROW = 130, K_RIGHTARROW = 131;
const float K_SHIFT = 134, K_F1 = 135, K_F12 = 146, K_KP_ENTER = 172;
const float K_MOUSE1 = 512, K_MOUSE2 = 513;
float drawfont;
void(float enabled, optional string image, optional vector hotspot, optional float scale) setcursormode = #343;
void(string command) registercommand = #352;
float(optional float effective) getcursormode = #0;
void(string eventname, string types, ...) sendevent = #359;
float(string text) tokenize = #441;
string(float index) argv = #442;
float(optional float timer) gettime = #519;
float(string text) strlen = #114;
string(string text, float start, float length) substring = #116;
float(string text, float index) str2chr = #222;
float(__variant builtin) checkbuiltin = #0;
string(string name, float flags) precache_pic = #317;
float(string name, string atlas, string sizes, float slot) loadfont = #357;
float(vector position, vector size, vector color, float alpha, float radius,
    optional float cornermask, optional float feather) drawroundedrect = #0;
void(vector position, vector size, string picture, vector source, vector extent,
    vector color, float alpha, float flags) drawsubpic = #328;
float(vector position, vector size, vector color, float alpha, float flags) drawfill = #323;
float(vector position, string text, vector size, vector color, float alpha, float flags) drawstring = #326;
float(float slot) getstatf = #331;
string(float slot) getstats = #332;
#else
void(float slot, float type, .__variant field) clientstat = #232;
void(float slot, float type, string name) globalstat = #233;
#endif
