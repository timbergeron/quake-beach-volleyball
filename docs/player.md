# Beach athlete authoring and review

The original stylized male player is inspired by Norway's Anders Mol and
Christian Sørum. Visual cues are a tall, lean build; navy/red/white tournament
kit; a Norway flag; `NOR` and number 1; bare feet; a navy sun cap; fair hair;
and a full mirrored sun shield. The shield is curved mesh spanning both eyes
and dipping over the nose, with light temples. It uses a painted reflective
gradient suitable for QSS-M's alias material rendering, rather than a reflective
shader. This is an authored character, not a scan or motion capture.

The rest silhouette is approximately 1.95 metres tall at 32 units per metre.
X points forward, Y left and Z up. The entity origin matches the game's existing
player origin: bare soles are about -24 units. Gameplay hulls remain separate
from visual geometry. No animation drives entity translation or contacts.
The first-person rig brings the upper arms in from below and behind the camera
so shoulder caps do not obscure the ball. It shares the body's stroke timing
and hand poses, with camera-space framing for its wrists and elbows.

## Rebuild

The generator imports the installed `md3harness` Python package, or the sibling
checkout `../md3harness`. Blender is not required. The harness is GPL-2.0-or-later
and remains an external source dependency.

```sh
python3 player_assets.py --write-qc
python3 player_review.py
```

The first command writes home/away body MD3s, the first-person arm MD3, two
512×512 original RGBA atlases, and `bv_athlete.animations.json` under
`dist/beachvolley/progs/`. It writes strict quality reports under
`build/player-quality/`. `--output` takes a game root, not a `progs/` directory.
The normal mod build invokes this same generator.

The checked-in `src/animation_frames.qc` is generated from the animation
inventory. Refresh it with `--write-qc` whenever clip durations/order change.
The renderer interpolates single alias poses over 0.1 seconds. Live game
animation therefore publishes at that cadence and selects from the 24 Hz
source sampling. This avoids restarting a 0.1-second blend every server frame.
Preparation holds the final loaded pose; recovery clips start at contact.

## Inventory

| Clips | Movement |
| --- | --- |
| ready, run, shuffle_l, shuffle_r, backpedal, split_step | Ready breathing, directional footwork and a defensive split |
| pass_load, pass | Joined forearm platform, knee/hip extension, controlled recovery |
| set_load, set, back_set, jump_set | Deep hand bowl near the forehead, extension through elbows and wrists, backward and airborne variants |
| approach, takeoff, attack_load | Right-left closing steps, both arms backward, drive upward, independent guide/hitting arms in a bow posture |
| spike, roll, cut, poke | High contact, trunk rotation, cross-body follow-through, soft roll, cut and closed knuckles |
| float_load, float_serve, jump_serve | Toss preparation, firm float contact, approach and bow posture for topspin |
| block_load, block_pike, block_l, block_r, peel | Raised/spread palms, hip pike and forward feet, lateral press, retreat to defense |
| dive, pancake, getup, land | Committed low platform, one-hand pancake, push-up recovery and bent-knee landing |

Core pass, set, attack, roll, serve, dive and locomotion animations are connected
to existing human/bot states in `src/animations.qc`. The remaining variants are
authored assets for review and future mechanics. A library clip does not add
block touches, a new input, or a ball-contact rule.

## Inspect the exact asset in QSS-M

```sh
PYTHONPATH=../md3harness python3 -m md3harness check \
  dist/beachvolley/progs/bv_athlete.md3 \
  --asset-root dist/beachvolley \
  --manifest build/player-quality/athlete.contract.json --strict

PYTHONPATH=../md3harness python3 -m md3harness preview \
  dist/beachvolley/progs/bv_athlete.md3 \
  --asset-root dist/beachvolley --output build/player-review/qssm \
  --frames 0,121,124,162,180,182,283,346 \
  --engine /path/to/quakespasm --basedir /path/to/quake \
  --fteqcc /path/to/fteqcc --qbsp /path/to/qbsp \
  --vis /path/to/vis --light /path/to/light
```

Use a fresh output directory for each engine review. The harness captures front,
back, quarter and detail views plus selected setting, backswing, bow, strike,
pike and dive poses. It checks each capture against an empty studio and records
model/texture/tool hashes. The offline `animation.html` complements these actual
engine captures with continuous interpolation, clip selection and scrubbing.

Animation selection and recovery regressions run inside the real QC VM as part
of `python3 test_mod.py`. Live doubles and dive fixtures also exercise the
extended model frame numbers above 255 and render the new body/view models.

Run `python3 -m unittest -v test_player_assets` for regression checks of the
standing scale, source/game frame agreement, fixed topology and exported
winding in deep folds, including the setting and pancake in-between poses.

## References

- [Volleyball World: Mol/Sørum at Montréal](https://en.volleyballworld.com/beachvolleyball/competitions/beach-pro-tour/2026/elite16/montreal-can/news/mol-says-goodbye-to-sand-montreal-three-peat-sorum)
  supplies the named visual reference. No photos are packaged as textures.
- [USA Volleyball: attacking approach advice](https://usavolleyball.org/resource/pro-tips-for-attacking-middle-blockers-and-beach/)
  and [shot-making](https://usavolleyball.org/resource/the-lost-art-of-shot-making-giving-hitters-additional-tools-for-terminating-the-ball/)
  inform the step-close, full approach and shared attack preparation cues.
- [md3harness workflow](https://github.com/timbergeron/md3harness/blob/main/docs/workflow.md)
  defines binary validation, texture protection and target-renderer review.
