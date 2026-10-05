# Quake beach volleyball

A playable first-person QuakeC prototype for QSS-M. It includes a beach court,
serve tosses, passes, sets, spikes, roll shots, continuous power and arc controls,
sidespin and topspin/backspin, jumps, dives, landing previews, and repeatable
training feeds. Press **5** for a local 2v2 match: you and a blue AI teammate
against two orange opponents. Original animated athletes and first-person hands
show preparation, contact and recovery. The design takes inspiration from
Virtua Tennis's preparation and positioning controls, described in Sega's
[Dreamcast manual](https://www.dreamcast.es/descargas/manuales/Virtua_Tennis.pdf).
The contact and flight code is an original QuakeC implementation.

Doubles is a playable prototype with rally scoring, three-touch limits and
same-player double-contact faults. Complete beach rules (including blocks,
service rotation and side changes), network doubles and match difficulty tiers
remain future work. Ball aerodynamics and contact assistance are tunable
gameplay values rather than a calibrated sports simulation.

![The beach court and first-person contact feedback](docs/court.png)

## Play the built version

Download `beachvolley.zip` from the
[releases page](https://github.com/timbergeron/quake-beach-volleyball/releases),
unpack it into your Quake directory, and launch
[QSS-M](https://github.com/timbergeron/QSS-M):

```sh
quakespasm -game beachvolley +exec beach.cfg +map beach
```

You need an installed copy of Quake, including `id1/pak0.pak`. The archive
contains original generated mod assets and compiled QC; base Quake data comes
from your installation.

To play a source build, run this from the mod repository root after building:

```sh
python3 run.py \
  --bin /path/to/quakespasm --basedir /path/to/quake --window
```

For another installation, change `--bin` to the QSS-M executable and
`--basedir` to the directory containing `id1/pak0.pak`. The launcher keeps
configs in this mod's `.runtime` and `dist` directories and reads the base
PAKs through symlinks. It does not install files into your Quake directory.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Hold and release LMB | Prepare and contact a forearm pass or high attack |
| Hold and release RMB | Prepare and contact a set, or an airborne roll shot |
| Wheel up / down | Increase / decrease arc in 5% steps |
| Hold Q / E | Adjust remembered sidespin left / right continuously |
| Z | Cycle topspin/backspin; positive values dip, negative values lift |
| F / V | Bias placement shorter / deeper in 10% steps |
| B | Reset placement depth to neutral |
| Middle mouse | Reset sidespin and restore moderate topspin |
| Shift + mouse | Change shot direction while preparing |
| Space | Jump; release between jumps |
| Ctrl | Dive in your movement direction; recovery has a short cooldown |
| R / T | Ready a serve / feed another ball |
| 1 / 2 / 3 / 4 | Leave doubles and enter serve / receive / setting / attack practice |
| 5 | Start or restart local doubles |
| C | Toggle assisted contact while holding a shot |
| J | Toggle landing preview and training minimap |
| H / Tab | Toggle help / hold for help |
| F12 | Console |

Aim before holding a shot button. Preparation stores your direction, allowing
you to look upward and track the ball. Hold Shift while preparing to change
that direction for a cut or wrist-away shot. Spin controls the subsequent curve
separately from the launch direction.

Release when the ball reaches your hands. With C assistance enabled, you can
keep holding: contact happens automatically only in the centre of physical hand
reach after preparation, with the same obstruction and recovery checks. This
is enabled when starting doubles and optional in practice. Manual release
retains the wider hand window. Assistance never moves the ball or your feet.

The reticle and timing cue turn green when the ball is within physical reach,
using the same obstruction checks as
contact. A brief contact window helps catch balls moving between server frames;
it still requires physical reach. Centred contacts give clean power and control;
reaching toward the edge of your hands produces softer, glancing shots.
Glances deflect toward the reach consistently. Fast incoming balls also carry
a little momentum through a pass or set, especially when contact is stretched.
Preparing early and planting your feet improves contact quality. Footing recovers
over about a quarter-second after you stop; jump attacks retain takeoff footing,
while dives provide an emergency save with reduced control.

Normal shot power fills over 0.75 seconds. F/V changes placement depth separately
from that power and the wheel arc. Short/deep attacks change launch angle while
preserving arm speed, allowing a hard short cut. Passes, sets, rolls, and serves
change forward travel; sets retain their selected vertical lift. B restores
neutral depth. This is a placement bias, so movement, spin, net collisions,
and contact quality still affect the actual landing.

The gold ring previews a centred contact using your current preparation,
footing, depth and serve timing; reaching for the ball can change the outcome.
The HUD predicts range, apex height, and target/in/out/net outcomes. Its overhead
court shows you in white, the ball in gold, and the predicted landing as an
outlined green or orange marker. Spin labels use L/R for sidespin and TOP/BACK
for vertical spin. CLEAN, REACH, and GLANCE feedback identifies contact quality
and gives a cue about preparation, reaching, footing, digging, or serve timing.
Recent contact quality and landing feedback remain visible
for three seconds, including across automatic training feeds. The HUD uses an
original bitmap font when the engine supports CSQC font loading, with the normal
Quake font as a fallback.

Start with a serve: press R, move along the baseline, aim, and hold LMB to toss.
The serve gauge rises toward the toss apex and then falls; the sweet spot is
around 0.45 seconds at default gravity. Release around 0.35–0.55 seconds for a
standing serve, using the timing readout and SERVE SWEET SPOT cue. Early/late
strikes lose power and control. Timing follows the configured gravity. Try F/V
and wheel arc for short/deep serves; extra depth can send the ball long.
A jump raises your attack contact point.

Passes, sets, spikes, rolls, serves, and digs have distinct original contact
sounds and a small camera pulse. Set `bv_contact_kick 0` in the console to
disable the pulse, or use a value between 0 and 1 to reduce it.

Drills automatically feed another ball shortly after landing. Setting feeds
drop near you; attack mode moves you near the net. You can also set to yourself
and then attack. You can hold a shot early while waiting for an automatic feed;
the feed preserves your preparation and aim. R and manual feeds clear the old
contact window. A flight that lasts longer than eight seconds expires so a ball
caught on the tape cannot stall practice. Expired flights count as misses.
Targets are painted on both courts. The HUD shows shot speed
in metres per second and reports target hits, in/out, misses, and under-net
faults. Consecutive self contacts are allowed for practice.

## Doubles rallies

Press **5** to start. The opponents serve first; move into the incoming ball,
prepare LMB toward your blue teammate, then get forward for their set. The HUD
calls out receive, set, attack or cover and shows your team's touch count. Both
opponents use the same physical receive–set–attack sequence. Bots forecast the
ball's flight, move with collision-aware feet, prepare and strike only within
hand reach. Poor positioning can cause a miss.

At attack contact, bots simulate nine short/deep and angled spike/roll options
with the current wind, drag, spin and contact quality. They reject predicted
net and court faults, then compare when each defender could intercept the
descending ball. Both defenders affect placement. This is an approximate
reach estimate; collisions, dives and changes of direction can still save a shot.

Receivers can make an emergency dive when ordinary movement would arrive late
and a low dig is physically reachable. A dive commits to its original direction,
lowers control and costs recovery time even when it misses. A recovering teammate
also affects which player takes the next incoming ball. Repeated contacts require
the ball to leave the original hand volume as well as the recovery timer to expire.

Passes and sets stay in your own court when aimed toward your teammate with
short depth (F); use B to restore neutral depth for the attack. Wheel arc changes
the height. The direction is yours to choose, including on assisted contacts.
Jump + LMB attacks high balls; jump + RMB gives a slower looping roll shot.
Shot-specific follow-through briefly limits movement and prevents instant
recontacts. A small ball shadow helps read height even with J overlays off.

The default match is first to seven, win by two. The winner serves next after
a two-second pause; you serve home points and the far back bot serves away
points. Press 5 to restart or 1–4 to return to practice. R/T practice resets are
inactive during doubles. `bv_match_points` sets the next match's target (3–21),
and `bv_bot_speed` adjusts bot movement (80–220 units/second, default 155).
This mode is for one local human player; it does not provide network 2v2 slots.

## Build

Requires Python 3, FTEQCC, and the `qbsp`, `vis`, and `light` tools from
[ericw-tools](https://github.com/ericwa/ericw-tools). FTEQCC source is available
from the [FTE project](https://github.com/fte-team/fteqw); build its CLI with
`make -C engine/qclib qcc`. The prototype was built with ericw-tools v0.18.1.

```sh
python3 build.py \
  --basedir /path/to/quake \
  --fteqcc /path/to/fteqcc \
  --qbsp /path/to/qbsp --vis /path/to/vis --light /path/to/light
```

Tools can be omitted from the arguments if they are on PATH. The build generates
the editable court MAP, a texture WAD, original MDL/MD3 models and sounds, and RGB
texture companions. It then compiles version-6 server QC, a simple CSQC HUD, and
the lit/visible BSP. Outputs go into `dist/beachvolley` and an install ZIP.
Generated files are ignored by Git; all source is in this directory.

The volleyball is an original static MD3 with 561 vertices, 960 triangles, and a
512×512 RGB skin. Its ten curved white/yellow/blue panels, seams, surface grain,
valve, and BEACH label are generated by `ball_assets.py`. Its centred 3.4-unit
radius matches the physics; gameplay applies the spin. To generate just the ball
without Quake data or external tools, run `python3 ball_assets.py`. This writes
`bv_ball.md3` and `bv_ball.tga` into `dist/beachvolley/progs`; keep the texture at
`progs/bv_ball.tga` within the game directory when using the MD3 elsewhere.

![The original volleyball MD3, shown from three angles](docs/ball.png)

## Physics and tuning

The court uses 32 units per metre: 16×8 metres, a 2.43-metre net, and a
21.25-centimetre ball. Ball integration runs at 120 Hz with retained fractional
time. Ground and net collisions are swept; the net uses separate mesh and tape
volumes expanded by the ball radius, including vertical and overlapping contacts.
Hand contacts are checked before the first obstacle, and under-net faults are
limited to crossings within the net's width before the ball lands. Prediction
and live play share the same integrator and net response.

The console exposes `bv_gravity`, `bv_drag`, `bv_magnus`, `bv_spin_decay`,
`bv_wind_x`, and `bv_wind_y`. Wind values use units/second; 32 is 1 m/s.
Gravity defaults to 313.92 units/second². Player gravity follows the ball's
gravity, while `server.cfg` sets sand movement speed, acceleration, and friction.
Shot velocity recipes are in `src/player.qc`; aerodynamic forces are in
`src/physics.qc`. The current preview includes floor and net interactions; posts
and surroundings are additionally traced during live play.

## Verify

```sh
python3 test_mod.py \
  --bin /path/to/quakespasm --basedir /path/to/quake
```

The runner uses temporary game directories and leaves installed configs alone.
It runs 163 assertions inside the actual QC VM, captures the court and compact
help/HUD through SDL's offscreen renderer, and performs standing serves from
both baselines through the normal input, toss, release, collision, flight,
scoring, and HUD update paths. Additional live serves check the sweet timing
window and the weaker result of a late strike, with contact feedback captures.
It also verifies that timing, contact grades, and landing cues reach the client HUD.
Two live doubles fixtures run at 50 Hz: human receive → bot set → human jump
attack → opponent return, and bot receive → human set → bot attack. Both follow
normal reach/collision paths into a scored point, with match HUD captures.
Audio uses SDL's dummy device. Use `--skip-visual` for
dedicated-only checks. Emergency digs also run through live movement and contact
at 50 and 100 Hz, verifying the dive pose, reduced control and recovery. Use
`--case bot-dive --case bot-dive-fast` to run those cases alone, or select any
case listed by `--help`. Logs,
screenshots, and executable/progs hashes are written to `artifacts/`.

Run `python3 -m unittest -v test_launcher` for three launcher regressions covering
installation switches, broken links, and preservation of regular runtime files.
The launcher refreshes its managed links when the installation or engine changes.

Run `python3 -m unittest -v test_ball_assets` for checks of the exported MD3
structure, bounds, winding, lighting normals, UVs, and texture wrapping.

The separate launcher isolates configs. A manual installation uses the usual
engine config behavior and applies the bindings in `beach.cfg`.

## License

Copyright © 2026 timbergeron. Source and generated mod assets are available under
the GNU General Public License, version 2 or later. See [LICENSE](LICENSE) and
[THIRD_PARTY.md](THIRD_PARTY.md) for the license and upstream credits. Quake game
data is required separately and is not included in this repository or releases.
