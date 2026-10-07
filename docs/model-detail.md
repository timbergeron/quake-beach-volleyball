# Dense models for QSS-M

The development assets use QSS-M's larger MD3 surface budget. The engine
supports **65,535 vertices per surface** and **1,024 animation frames per model**.
Its triangle guard is `INT_MAX / 3`, rather than the portable exporter's 8,192
triangles per surface. File size, memory, rendering cost and the position grid
set the useful production budget.

The limits were checked in QSS-M revision
`9714f766ecb844ada219f8988c946bbaf4a5594c`, in
[`Mod_ValidateMD3Model` / `Mod_LoadMD3Model`](https://github.com/timbergeron/QSS-M/blob/9714f766ecb844ada219f8988c946bbaf4a5594c/Quake/gl_mesh.c)
and [`MAXALIASFRAMES`](https://github.com/timbergeron/QSS-M/blob/9714f766ecb844ada219f8988c946bbaf4a5594c/Quake/gl_model.h).
The [harness density profile](https://github.com/timbergeron/md3harness/blob/main/docs/qssm-limits.md)
keeps these separate from conservative portable export limits.

| Model | Previous triangles | Dense triangles | Poses |
| --- | ---: | ---: | ---: |
| Athlete, each kit | 5,004 | 35,422 | 389 |
| First-person hands | 6,808 | 21,766 | 402 |
| Ball | 960 | 20,544 | 1 |
| Net and equipment | 28,588 | 88,736 | 37 |

All five MD3 files are regenerated: home and away bodies, hands, ball and net.
Three visible bots plus the hands and all equipment total 237,312 model
triangles, before view culling. Animation ranges, contact timing, gameplay
physics and collision hulls retain their existing contracts.

The athletes use continuous CC0 anatomical geometry with a face, neck, torso,
limbs, hands and bare feet. Dual quaternion skinning retargets the existing
volleyball poses. Shared geometric normals cross UV seams, while a fixed crease
layout handles strongly folded skin. The 2048×2048 body atlases include original
Norway kit artwork; a separate 512×512 atlas supplies the cap and mirrored shield.
The shield fits around the anatomical face and covers both eyes.

The hands retain their 512×2048 skin atlas and authored deep-dish, float and cut
motions. Refinement spends samples on curved anatomy. A complete pose sweep
identifies compression zones that need larger faces; the saved refinement plan
keeps a small finger crease coarser. Only disagreeing crease normals reserve
extra corners. This increases detail while using less packed pose storage than
the previous broadly split hand mesh.

The ball uses five icosphere refinements, with a clipped UV meridian and stable
polar UVs. Its 3.4-unit gameplay radius is unchanged. Net pads use 96-sided
sections, cloth cords 16 sides, and rounded fittings and antennas have increased
detail. All 37 recoil poses keep the regulation dimensions and static equipment.

MD3 positions lie on a **1/64-unit grid**, about **0.49 mm** at this game's scale.
Tiny new faces can collapse when joints close. Refinement preserves fine source
triangles and uses shared edge points at coarse/dense transitions. Both the
source preflight and final binary checks cover the complete motion libraries.

Packed pose storage costs `8 × exported vertices × frames` bytes. QSS-M's pose
VBO costs another `12 × exported vertices × frames` bytes, plus indices, UVs,
textures and engine data. Multiple bots can share one model; the two kit files
are separate loaded models. The engine's default heap is 384 MiB. These density
targets prioritize desktop visual quality while keeping each animated file
below GitHub's 100 MiB per-file limit.

Normal builds need Python's standard library and current `main` of
`../md3harness`. The generators use the explicit `qssm` export profile and
40-frame batches. Prepared anatomy, input hashes and licensing are in
`resources/anatomy`; hand plans and source are in `resources/hands`.

To repeat body preparation from the pinned inputs described in
[the hand source notes](hands.md#source-extraction), install Pillow in a tooling
environment and run:

```sh
python3 prepare_body_source.py --source build/hand-source --output resources/anatomy
python3 anatomical_body.py --plan-creases
```

Recompute the body crease plan when changing its topology or poses, and run
`python3 hand_assets.py --plan-creases` when changing hand detail or motions.
Reject a failed candidate before replacing the runtime models. The committed
quality reports and engine captures record the delivered model and texture
hashes; see [player review](player.md) and [hand review](hands.md).

## Delivered memory and review

Each 389-pose athlete exports 21,079 vertices across five surfaces. The two
kit files are 63.23 MiB each. The 402-pose hands export 12,832 vertices across
two surfaces and occupy 39.81 MiB, down from 52.97 MiB despite the denser mesh.
The ball is 0.39 MiB; the 37-pose net is 15.51 MiB across 14 surfaces.

Together their packed positions/normals occupy approximately **178.7 MiB**
of CPU storage, and their pose VBOs approximately **268.0 MiB**. This excludes
textures, UVs, indices, maps and other engine allocations. Three bots can share
the two loaded kit models. Rendered triangle counts grow with visible instances;
the stored pose library is shared for each distinct model.

The [athlete gallery](model-review/player/index.html) contains nine captures of
the complete 389-pose file in QSS-M, including setting, approach, bow loading,
pike blocking and diving. Each image has a paired empty-studio baseline and
model/texture/engine hashes in its [report](model-review/player/review.json).
The standing view, new shield fit and folded poses were reviewed visually.
The [ball gallery](model-review/ball/index.html) records four native views and
paired baselines of the final 20,544-triangle sphere.

QSS-M also guards its loaded surface chain in
[`R_DrawAliasModel`](https://github.com/timbergeron/QSS-M/blob/9714f766ecb844ada219f8988c946bbaf4a5594c/Quake/r_alias.c):
a next-surface offset above 64 MiB stops traversal. Very large early surfaces
can therefore prevent later parts from rendering. The profile's count ceilings
do not guarantee that all maximum counts can be combined. Keep individual
loaded surfaces comfortably below that guard, split large animated surfaces,
and check the actual engine log and complete appearance. The delivered body's
largest surface contains about 54.55 MiB of packed poses, leaving room for its
frame, mesh, index and material metadata.

All five assets loaded together in the live game using the default 384 MiB
heap. QSS-M grew its separate data-cache budget to 409 MiB and reported
288.4 MiB used/peak with **zero evictions**. This cache count is separate from
GPU storage and total process memory. The [game summary](model-quality/game-summary.json)
records 257 QC assertions, three live float-serve checks, both doubles
receive/set/attack fixtures, net recoil and equipment views.
The [inventory](model-quality/inventory.json) records exact model and texture hashes.

Seven [first-person hand captures](model-review/hands/index.html) cover setting,
float serve and both cuts, including frame 392. Both compressed offline
reviewers preserve the exact MD3 bytes and passed their browser controls and
clip checks without errors: 31 body clips and 32 hand clips. Game and hand
capture commands accept `--timeout 300` for slower software renderers while
retaining their fixed simulation timestep. These checks establish loading,
geometry and rendered appearance; they do not measure a target GPU's frame rate.
