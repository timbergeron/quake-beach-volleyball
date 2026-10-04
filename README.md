# Quake beach volleyball

A playable first-person QuakeC prototype for QSS-M. It includes a beach court,
serve tosses, passes, sets, spikes, roll shots, continuous power and arc controls,
sidespin and topspin/backspin, jumps, dives, landing previews, and repeatable
training feeds. The design takes inspiration from Virtua Tennis's preparation
and positioning controls.

This version is a solo practice court. Opponent AI, competitive 2v2 matches,
complete beach volleyball rules, and first-person hand animations are future
work. Ball aerodynamics and contact assistance are tunable gameplay values.

![The beach court and first-person shot preview](docs/court.png)

## Play the built version

Download `beachvolley.zip` from the
[releases page](https://github.com/timbergeron/quake-beach-volleyball/releases),
unpack it into your Quake directory, and launch
[QSS-M](https://github.com/timbergeron/QSS-M):

```sh
quakespasm -game beachvolley +exec beach.cfg +map beach
```

You need an installed copy of Quake, including `id1/pak0.pak`. The archive
contains generated mod assets and compiled QC; base Quake data and the player
model come from your installation.

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
| Middle mouse | Reset sidespin and restore moderate topspin |
| Shift + mouse | Change shot direction while preparing |
| Space | Jump; release between jumps |
| Ctrl | Dive in your movement direction; recovery has a short cooldown |
| R / T | Ready a serve / feed another ball |
| 1 / 2 / 3 / 4 | Serve / receive / setting / attack drill |
| H / Tab | Toggle help / hold for help |
| F12 | Console |

Aim before holding a shot button. Preparation stores your direction, allowing
you to look upward and track the ball. Hold Shift while preparing to change
that direction for a cut or wrist-away shot. Spin controls the subsequent curve
separately from the launch direction.

Release when the ball reaches your hands. The reticle and timing cue turn green
when the ball is within physical reach, using the same obstruction checks as
contact. A brief contact window helps catch balls moving between server frames;
it still requires physical reach. Preparing
early improves contact quality, and a moving set loses some precision. Power
fills over 0.75 seconds. The gold ring previews the landing location for a
balanced contact; actual contact height and footing can change the outcome.
The HUD predicts range, apex height, and target/in/out/net outcomes. Its overhead
court shows you in white, the ball in gold, and the predicted landing as an
outlined green or orange marker. Spin labels use L/R for sidespin and TOP/BACK
for vertical spin. Recent contact quality and landing feedback remain visible
for three seconds, including across automatic training feeds. The HUD uses an
original bitmap font when the engine supports CSQC font loading, with the normal
Quake font as a fallback.

Start with a serve: press R, move along the baseline, aim, and hold LMB to toss.
Release after roughly 0.35–0.7 seconds for a standing serve. Try small changes
to charge and wheel arc to alternate short and deep placement. Full power can
send the ball long. A jump raises your attack contact point.

Drills automatically feed another ball shortly after landing. Setting feeds
drop near you; attack mode moves you near the net. You can also set to yourself
and then attack. You can hold a shot early while waiting for an automatic feed;
the feed preserves your preparation and aim. R and manual feeds clear the old
contact window. A flight that lasts longer than eight seconds expires so a ball
caught on the tape cannot stall practice. Expired flights count as misses.
Targets are painted on both courts. The HUD shows shot speed
in metres per second and reports target hits, in/out, misses, and under-net
faults. Consecutive self contacts are allowed for practice.

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
the editable court MAP, a texture WAD, original alias models and sounds, and RGB
texture companions. It then compiles version-6 server QC, a simple CSQC HUD, and
the lit/visible BSP. Outputs go into `dist/beachvolley` and an install ZIP.
Generated files are ignored by Git; all source is in this directory.

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
It runs 77 assertions inside the actual QC VM, captures the court and compact
help/HUD through SDL's offscreen renderer, and performs standing serves from
both baselines through the normal input, toss, release, collision, flight,
scoring, and HUD update paths. It also verifies that timing and landing cues
reach the client HUD. Audio uses SDL's dummy device. Use `--skip-visual` for
dedicated-only checks. Logs,
screenshots, and executable/progs hashes are written to `artifacts/`.

Run `python3 -m unittest -v test_launcher` for three launcher regressions covering
installation switches, broken links, and preservation of regular runtime files.
The launcher refreshes its managed links when the installation or engine changes.

The separate launcher isolates configs. A manual installation uses the usual
engine config behavior and applies the bindings in `beach.cfg`.

## License

Copyright © 2026 timbergeron. Source and generated mod assets are available under
the GNU General Public License, version 2 or later. See [LICENSE](LICENSE) and
[THIRD_PARTY.md](THIRD_PARTY.md) for the license and upstream credits. Quake game
data is required separately and is not included in this repository or releases.
