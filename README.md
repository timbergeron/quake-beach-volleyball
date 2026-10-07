# Quake beach volleyball

A playable first-person beach volleyball mod for
[QSS-M](https://github.com/timbergeron/QSS-M), written in QuakeC. Play training
drills or press **5** for local doubles: you and a blue AI teammate against two
red opponents. Position your feet, prepare your hands, and time the contact.

![Local doubles with the current athletes, anatomical hands and match HUD in QSS-M](docs/screenshots/doubles.png)

## Current development build — October 7, 2026

- **Anatomical first-person hands:** textured skin, knuckles, nail beds, palm
  contours and three joints per finger. Deep-dish setting spreads and flexes
  the fingers, opposes the thumbs, and yields through the wrists before release.
- **Distinct volleyball strokes:** firm-palm float toss/contact, inward and
  wrist-away cuts, two-arm approach backswing, bow-and-arrow loading, spike and
  roll follow-through, forearm passes, dives and recovery.
- **Norway-inspired athletes:** Mol/Sørum-inspired proportions, navy/red kit,
  sun caps, bare feet and full mirrored shield sunglasses. Bodies have 31 clips
  and 389 poses; first-person hands have 32 clips and 402 poses, sampled at 24 Hz.
- **Dense QSS-M models:** continuous anatomical bodies at 35,422 triangles each,
  21,814-triangle hands, a 20,544-triangle ball, and 88,736-triangle net equipment.
  [Density notes](docs/model-detail.md) cover the engine limits and memory budget.
- **Playable rallies and practice:** local doubles, float and jump-topspin serves,
  timed receiving, short/deep placement, spin, emergency digs, target drills,
  landing previews, and net/post/antenna collisions with animated net recoil.

The screenshots show the current `main` build. The latest published
[v0.6.0 ZIP](https://github.com/timbergeron/quake-beach-volleyball/releases/tag/v0.6.0)
contains the earlier first-person arms; build from source for the
dense anatomical models and directional cut animations shown here.

The design takes inspiration from
Virtua Tennis's preparation and positioning controls, described in Sega's
[Dreamcast manual](https://www.dreamcast.es/descargas/manuales/Virtua_Tennis.pdf).
The contact and flight code is an original QuakeC implementation.

Doubles is a playable prototype with rally scoring, three-touch limits and
same-player double-contact faults. Complete beach rules (including blocks,
service rotation and side changes), network doubles and match difficulty tiers
remain future work. Ball aerodynamics and contact assistance are tunable
gameplay values rather than a calibrated sports simulation.

## Play the built version

Download `beachvolley.zip` from the
[v0.6.0 release](https://github.com/timbergeron/quake-beach-volleyball/releases/tag/v0.6.0),
unpack it into your Quake directory, and launch
[QSS-M](https://github.com/timbergeron/QSS-M):

```sh
quakespasm -game beachvolley -fsaa 4 +exec beach.cfg +map beach
```

You need an installed copy of Quake, including `id1/pak0.pak`. The archive
contains mod assets and compiled QC; base Quake data comes
from your installation.

The v0.6.0 release includes the MD3 ball, animated net, prepared court textures,
Norwegian-inspired players and first-person arms. See the
[release notes](docs/releases/v0.6.0.md) for the asset inventory, animation review
download and validation details.

To play a source build, run this from the mod repository root after building:

```sh
python3 run.py \
  --bin /path/to/quakespasm --basedir /path/to/quake --window
```

For another installation, change `--bin` to the QSS-M executable and
`--basedir` to the directory containing `id1/pak0.pak`. The launcher keeps
configs in this mod's `.runtime` and `dist` directories and reads the base
PAKs through symlinks. It does not install files into your Quake directory.
The launcher enables 4× anti-aliasing to keep the fine net cords smooth. Use
`--samples 0` to disable it, or `--samples 2` / `--samples 8` to choose another level.

For a first session, press **1** for serve practice, **R** to ready a ball,
then hold and release **LMB** around the toss apex. Try **3** for setting, or
**5** for doubles. **H** opens help; **J** toggles the training overlays.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Hold and release LMB | Prepare and contact a forearm pass or high attack |
| Hold and release RMB | Prepare and contact a set, or an airborne roll shot |
| Wheel up / down | Increase / decrease arc in 5% steps |
| Hold Q / E | Adjust remembered sidespin left / right continuously |
| Z | Cycle topspin/backspin; positive values dip, negative values lift |
| F / V | Bias placement shorter / deeper; soften / firm up a receive |
| B | Reset placement depth to neutral |
| Middle mouse | Reset sidespin and restore moderate topspin |
| Shift + mouse | Change shot direction while preparing |
| Space | Jump; release between jumps |
| Ctrl | Dive in your movement direction; recovery has a short cooldown |
| R / T | Ready a serve / feed another ball |
| G | Select float or topspin jump serve; also selects the receive drill's serve |
| 1 / 2 / 3 / 4 | Leave doubles and enter serve / receive / setting / attack practice |
| 5 | Start or restart local doubles |
| C | Toggle assisted contact while holding a shot |
| J | Toggle landing preview and training minimap |
| H / Tab | Toggle help / hold for help |
| F12 | Console |

Aim before holding a shot button. Preparation stores your direction, allowing
you to look upward and track the ball. Hold Shift while preparing to change
that direction. For a cut, use **F** to bias an attack short, then turn the
stored heading more than about 20° with **Shift + mouse** during preparation.
Turning to the hitting side selects the wrist-away follow-through; the other
direction selects the inward cut. Spin controls the subsequent curve separately.

Release when the ball reaches your hands. With C assistance enabled, you can
keep holding: contact happens automatically only in the centre of physical hand
reach after preparation, with the same obstruction and recovery checks. This
is optional in both doubles and practice; doubles starts with manual contact.
Manual release retains the wider hand window and allows the best receive timing.
Assisted receives have a timing grade capped at 60%. Assistance never moves the
ball or your feet.

The reticle and timing cue turn green when the ball is within physical reach,
using the same obstruction checks as
contact. A brief contact window helps catch balls moving between server frames;
it still requires physical reach. Centred contacts give clean power and control;
reaching toward the edge of your hands produces softer, glancing shots.
Glances deflect toward the reach consistently. Receives rebound from incoming
ball velocity rather than charging a chosen outgoing speed.
Preparing early and planting your feet improves contact quality. Footing recovers
over about a quarter-second after you stop; jump attacks retain takeoff footing,
while dives provide an emergency save with reduced control.

Normal shot power fills over 0.75 seconds. Receiving is different: aim your
forearm platform toward your teammate, choose lift with the wheel, then release
as the ball reaches the hands. The clean timing band is about 35 ms either side
of closest approach, with a gradual penalty outside it. Preparing early helps
read the descending approach; Shift updates that read and your stored aim when
the ball drifts. Plant before contact. F softens the platform to absorb pace;
V makes the rebound firmer and longer. Holding longer does not increase receive
power. Overhead first contacts use the same timing and incoming-energy model.
Poor timing, a stretched reach or the wrong platform can shank or overpass.

F/V changes placement depth separately
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
around 0.45 seconds for a float serve at default gravity. Release around
0.35–0.55 seconds for a standing float, using the timing readout and
SERVE SWEET SPOT cue. Early/late
strikes lose power and control. Timing follows the configured gravity. Try F/V
and wheel arc for short/deep serves; extra depth can send the ball long.

G selects the serve type before the toss. FLOAT uses a hard, low-spin contact
with bounded lateral and vertical drift. Adding substantial Q/E sidespin
suppresses the float effect. TOPSPIN uses a higher toss with forward spin and
a faster downward bend. Jump with the toss and strike around its 0.67-second
apex for the fastest contact; a standing topspin contact loses pace. The type
sets forward spin for serves; Z still controls other strokes. The opponent
mixes serve types between points. Receive drill (2) uses the G selection.
The model rotates about the same world spin axis used by the flight forces.
Float movement is a deterministic wake approximation with a new phase per
serve, shared by live flight and previews. These are game-feel mechanics, not
a ball- or wind-tunnel-calibrated aerodynamic model.

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
prepare LMB toward your blue teammate and release at the hands, then get forward
for their set. The HUD
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

Aim receives toward your teammate and use F to cushion incoming pace. Ordinary
passes and sets use short depth (F); use B to restore neutral depth for the attack. Wheel arc changes
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

Requires Python 3.10+, [md3harness](https://github.com/timbergeron/md3harness),
FTEQCC, and the `qbsp`, `vis`, and `light` tools from
[ericw-tools](https://github.com/ericwa/ericw-tools). FTEQCC source is available
from the [FTE project](https://github.com/fte-team/fteqw); build its CLI with
`make -C engine/qclib qcc`. The prototype was built with ericw-tools v0.18.1.

Clone md3harness beside this repository, or install its Python package. From
the beach repository root, the sibling checkout is:

```sh
git clone https://github.com/timbergeron/md3harness.git ../md3harness
```

If that checkout already exists, use it. Normal asset builds use the prepared
source data and Python's standard library; Blender and Pillow are not required.
Pillow is only needed to repeat the optional anatomical source extraction.

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
Build outputs are ignored by Git. Asset generation code, prepared source data,
textures and validated MD3s are committed here; the exporter is in md3harness.

The court uses the supplied sand and water artwork, resized from 1254×1254 to
1024×1024 with Lanczos resampling. Ready-to-use uncompressed RGBA TGA files live
in `resources/textures`: `bv_sand.tga` for sand and `#bv_sea.tga` for the ocean.
The build copies these into `textures/beach`, generates practice markings over
the same sand, and embeds matching 64×64 Quake-palette fallbacks in the BSP.
The `#` filename is Quake's external replacement for the `*bv_sea` water material;
the sea keeps its animated water surface. No additional image tools are needed
to build with the prepared textures.

The volleyball is an original static MD3 with 10,381 vertices, 20,544 triangles, and a
512×512 skin. Its ten curved white/yellow/blue panels, seams, surface grain,
valve, and BEACH label are generated by `ball_assets.py`. Its centred 3.4-unit
radius matches the physics; gameplay applies the spin. To generate just the ball
without Quake data or external tools, run `python3 ball_assets.py`. This writes
`bv_ball.md3` and `bv_ball.tga` into `dist/beachvolley/progs`; keep the texture at
`progs/bv_ball.tga` within the game directory when using the MD3 elsewhere.

Ready-to-use copies are also committed in the repository:
[bv_ball.md3](resources/models/bv_ball.md3) and
[bv_ball.tga](resources/models/bv_ball.tga). Copy both into your mod's `progs/`
directory. To refresh these checked-in assets from the generator, run
`python3 ball_assets.py --output resources/models`.

![The dense volleyball MD3 rendered in QSS-M](docs/ball.png)

The original beach-net MD3 follows the standard construction in the
[FIVB 2025–2028 beach rules](https://www.fivb.com/wp-content/uploads/2025/02/FIVB-BeachVolleyball_Rules2025_2028-EN-v01.pdf):
8.5 metres long, one metre tall, 10-centimetre square mesh, 10-centimetre navy
top/bottom bands and 5-centimetre side bands. The men's net height is 2.43 metres.
Rounded, padded 2.55-metre posts sit one metre outside each sideline. Opposite-face
antennas extend 80 centimetres above the net with alternating red/white stripes.
The mesh uses actual open cord geometry, with stitched cloth, tension cords,
eyelets, anchor rings and turnbuckles. A 1024×1024 material atlas provides the
canvas, braided cord, padding and metal finishes. There are no tournament logos.

Net impacts select a local, mirrored recoil animation, then settle back to rest.
The 37 MD3 poses affect appearance; the shared collision model stays stable.
Ball contacts with the mesh and bands rebound, padded posts use rounded sweeps,
and antenna touches end the attempt or award the other team a point. The HUD and
trajectory preview report **ANTENNA** faults.
Hand reach and timing cues also respect the net, padding and antenna rods.

Ready-to-use [bv_net.md3](resources/models/bv_net.md3) and
[bv_net.tga](resources/models/bv_net.tga) live alongside the ball assets.
Copy both into `progs/`. Generate them independently with
`python3 net_assets.py --output resources/models`; the normal build regenerates
the game copies automatically, using only Python's standard library.

![The regulation-sized MD3 net, cloth, padding and tension fittings in QSS-M](docs/net.png)

## Athletes and volleyball animations

The male athlete takes visual inspiration from **Anders Mol and Christian
Sørum**: tall athletic proportions, Norway navy/red/white kit with a flag and
`NOR` marking, bare feet, a sun cap, and a broad blue mirrored shield that wraps
around the eyes and across the nose. The continuous anatomical mesh and skin
adapt CC0 MakeHuman assets; the clothing artwork, accessories, retargeting and
volleyball motions are authored here. There are no sponsor logos.

![The Norwegian-inspired male athlete and full mirrored shield in QSS-M](docs/player.png)

`player_assets.py` authors 31 body clips / 389 vertex poses at 24 samples per second
through [md3harness](https://github.com/timbergeron/md3harness). The
generator uses only the Python standard library and validates every exported
pose, normal, triangle, attachment tag, bound and texture with strict checks.
Two-bone IK preserves body arm and leg lengths as the poses change. The first
389 frames have shared body/hand ranges; the hand rig has 13 extra wrist-away poses.

Ready-to-use [home body](resources/models/bv_athlete.md3),
[away body](resources/models/bv_athlete_away.md3),
[first-person hands](resources/models/bv_hands.md3),
[home atlas](resources/models/bv_athlete.tga),
[away atlas](resources/models/bv_athlete_away.tga), and
[clip manifest](resources/models/bv_athlete.animations.json) are in
`resources/models`. Copy them into `progs/` to preserve the shader paths, including
the shared [cap and shield atlas](resources/models/bv_kit.tga).
The anatomical hand model also needs its [skin atlas](resources/hands/bv_hands.tga)
copied to `progs/bv_hands.tga` and has a separate
[hand clip manifest](resources/models/bv_hands.animations.json).

```sh
python3 player_assets.py --write-qc
python3 player_review.py
python3 hand_review.py
```

Open `build/player-review/animation.html` for an offline animated review. Choose
a clip or complete stroke, orbit the model, scrub the timeline, slow it down,
or switch kit colors. The review embeds the exported MD3 bytes and records
their hash; it requires a browser with WebGL and `DecompressionStream` support.
Open `build/hand-review/hands.html`
for the separate hand review, including first-person playback, an anatomy view,
and both cut directions. See [the player asset notes](docs/player.md)
for target-engine review commands and the animation inventory.

Live play selects ready movement, forward running, lateral shuffles,
backpedaling, forearm preparation/contact, deep hand setting, attack approach,
two-arm backswing, takeoff, bow-and-arrow preparation, spike/roll follow-through,
standing float and jump topspin serving, short angled cut shots, diving, getting up and landing. The
game sends poses at Quake's 0.1-second alias interpolation cadence, selecting
from the more densely sampled clips. Stride phase follows distance traveled.
Contact physics and collision still determine when a shot happens.

The library additionally includes back sets, jump sets, closed-knuckle
pokeys, split steps, pike blocks with left/right presses, peeling into defense,
and pancakes. These can be reviewed now; their separate gameplay actions and
block rules are not implemented yet. The clips contain no entity translation:
game physics supplies jump height and court movement.

## Anatomical first-person hands

The hand model has 21,814 triangles and 402 poses across 32 clips. Continuous
geometry, dual quaternion skinning, opposed thumbs and individual finger joints
preserve the palm and knuckle shapes during deep flexion. A separate 512×2048
skin atlas supplies the texture. The mesh, anatomy target, weights and skin are
trimmed CC0 MakeHuman assets; camera framing, skinning and volleyball motions
are authored here.

![Deep-dish setting with flexed fingers and opposed thumbs in QSS-M](docs/hands.png)

| Firm-palm float contact | Live float serve with contact feedback |
| --- | --- |
| ![The float-serve contact pose in QSS-M](docs/screenshots/float-contact.png) | ![A live float serve with anatomical hands and CLEAN SERVE feedback](docs/screenshots/serve-contact.png) |

| Inward cut | Wrist-away cut |
| --- | --- |
| ![The inward cut follow-through in QSS-M](docs/screenshots/cut-inward.png) | ![The wrist-away cut follow-through in QSS-M](docs/screenshots/cut-away.png) |

These are actual QSS-M captures from the October 7 dense-model build. The doubles and
serve feedback images come from live gameplay fixtures; the setting, float
pose and cut images use fixed poses to show the anatomy clearly.
[Capture metadata](docs/screenshots/review.json) records image, model, skin and
engine hashes. The first 389 hand frames retain the body ranges; 13 appended
frames provide the wrist-away cut.

To rebuild and review only the hands:

```sh
python3 hand_assets.py --output build/hand-candidate --reports build/hand-quality
python3 hand_review.py --game build/hand-candidate --reports build/hand-quality
```

Open `build/hand-review/hands.html` to play clips, scrub contact and recovery,
slow the animation, or orbit the palm detail. The reviewer embeds the exported
MD3 and texture. See [the hand notes](docs/hands.md) for motion details, source
extraction and native capture commands. Reusable hand-production lessons,
render evidence and packed-frame tools are also in
[md3harness](https://github.com/timbergeron/md3harness/blob/01ff02a05f785caedd1c224d4be3a1a4d1613fd5/docs/anatomical-hands.md).

## Physics and tuning

The court uses 32 units per metre: 16×8 metres, a 2.43-metre net, and a
21.25-centimetre ball. Ball integration runs at 120 Hz with retained fractional
time. Ground and net collisions are swept; the net uses a thin panel expanded
by the ball radius, including vertical and overlapping contacts. A ball cannot
fit through the 10-centimetre mesh openings. Posts and antennas use swept
sphere-versus-capsule collision with rounded tips.
Hand contacts are checked before the first obstacle, and under-net faults are
limited to crossings within the net's width before the ball lands. Prediction
and live play share the same integrator and net response.

The console exposes `bv_gravity`, `bv_drag`, `bv_magnus`, `bv_spin_decay`,
`bv_wind_x`, and `bv_wind_y`. Wind values use units/second; 32 is 1 m/s.
Gravity defaults to 313.92 units/second². Player gravity follows the ball's
gravity, while `server.cfg` sets sand movement speed, acceleration, and friction.
Shot velocity recipes are in `src/player.qc`, `src/serve.qc` and `src/receive.qc`; aerodynamic forces are in
`src/physics.qc`. The preview includes floor, net, post and antenna interactions
using the same equipment response as live play; other surroundings are traced
during live play.

## Verify

The October 7 dense-model build passed strict checks for all five MD3s, including
**389 body poses, 402 hand poses and 37 net poses**, plus **22 Python asset/launcher
tests** and **257 gameplay assertions** in the actual QC VM. Live float serving,
both doubles receive/set/attack fixtures, net recoil and equipment views passed
with the default engine heap. Nine body captures, seven first-person hand
captures and four ball views record the rendered assets. Offline browser reviews
exercised all 31 body and 32 hand clips without errors. The
[density notes](docs/model-detail.md) link the reports, galleries and memory evidence.

```sh
python3 -m unittest -v \
  test_anatomy_mesh test_ball_assets test_net_assets test_player_assets test_hand_assets test_launcher
```

Run the full gameplay and engine fixture suite after building:

```sh
python3 test_mod.py \
  --bin /path/to/quakespasm --basedir /path/to/quake
```

The runner uses temporary game directories and leaves installed configs alone.
It runs 257 assertions inside the actual QC VM, captures the court and compact
help/HUD through SDL's offscreen renderer, and performs standing serves from
both baselines through the normal input, toss, release, collision, flight,
scoring, and HUD update paths. Additional live serves check the sweet timing
window and the weaker result of a late strike, plus a physical jump topspin
serve. Four live receive fixtures cover clean float/topspin passes and early/late
manual releases, with timing/cushion HUD and contact feedback captures.
It also verifies that timing, contact grades, and landing cues reach the client HUD.
Three live doubles fixtures run at 50 Hz: human receive → bot set → human jump
attack → opponent return, and bot receive → human set → bot attack. They follow
normal reach/collision paths into a scored point, with match HUD captures;
the third verifies an opponent's physical jump topspin serve and the return rally.
Audio uses SDL's dummy device. Use `--skip-visual` for
dedicated-only checks. Emergency digs also run through live movement and contact
at 50 and 100 Hz, verifying the dive pose, reduced control and recovery. Use
`--case bot-dive --case bot-dive-fast` to run those cases alone, or select any
case listed by `--help`. Logs,
screenshots, and executable/progs hashes are written to `artifacts/`.
Seven net fixtures capture both faces, mesh, padding and close-up fittings, and
check live recoil plus antenna contact and fault feedback. Fixture settings use
a startup config so Quake's 50-argument command-line limit cannot drop the map.

Run `python3 -m unittest -v test_launcher` for three launcher regressions covering
installation switches, broken links, and preservation of regular runtime files.
The launcher refreshes its managed links when the installation or engine changes.

Run `python3 -m unittest -v test_ball_assets` for checks of the exported MD3
structure, bounds, winding, lighting normals, UVs, and texture wrapping.

Run `python3 -m unittest -v test_net_assets` for checks of all exported net poses,
surface limits, bounds, winding, open mesh, regulation dimensions, texture atlas
and stationary equipment during cloth recoil.

The separate launcher isolates configs. A manual installation uses the usual
engine config behavior and applies the bindings in `beach.cfg`.

## License

Copyright © 2026 timbergeron. Original source and generated assets are available
under the GNU General Public License, version 2 or later. The prepared MakeHuman
body/hand source and skin are CC0, with the [CC0 text](resources/anatomy/LICENSE.CC0.txt)
included. See [LICENSE](LICENSE) and
[THIRD_PARTY.md](THIRD_PARTY.md) for the license and upstream credits. Quake game
data is required separately and is not included in this repository or releases.
