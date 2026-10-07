# Painting better textures for the current MD3 models

Download [texture-paint-kit.zip](https://github.com/timbergeron/quake-beach-volleyball/releases/download/v0.7.0/texture-paint-kit.zip),
unzip it and open its `index.html`. To regenerate a kit from a built game:

```sh
python3 texture_kit.py --output build/new-texture-kit
```

The sibling harness must include `tools/texture_kit.py`. Use a new or empty
output directory. This command exports the current game textures and UVs; it
does not change the runtime assets or generate the proposed improved artwork.

These PNGs are lossless conversions of the current game textures. The SVGs
show the exact UV edges from the delivered MD3s, with the image origin at the
top left. Open `index.html` to see them together. Do not include the blue UV
lines or orange labels in the finished texture.

Work in this order: first-person hands, athlete skin/uniforms, cap/sunglasses,
ball, net. Keep layered working files and export a flattened PNG for each asset.
The current QSS-M MD3 material path uses a color texture and vertex lighting;
normal, roughness and metallic maps will not be consumed by these materials.
Use neutral diffuse color with restrained painted surface detail.

| Output PNG | Current dimensions | Purpose |
| --- | --- | --- |
| `bv_hands.png` | 512 × 2048 | Both first-person hands and forearms |
| `bv_athlete.png` | 2048 × 2048 | Home athlete skin, hair and painted uniform |
| `bv_athlete_away.png` | 2048 × 2048 | Away athlete, identical UV layout |
| `bv_kit.png` | 512 × 512 | Shared cap, brim, shield sunglasses and temples |
| `bv_ball.png` | 512 × 512 | Spherical volleyball skin |
| `bv_net.png` | 1024 × 1024 | Net bands, cords, padding, metal and antennas |

For a first pass, keep these dimensions. You can paint at twice the resolution
and reduce to the listed sizes for delivery. If you deliver a larger version,
scale the entire atlas uniformly and preserve its aspect ratio and all
normalized UV locations. A larger image alone does not add new detail.

1. Import an original PNG into your editor as the locked base layer. Import its
   `_uv.svg` at the same canvas size as a separate guide layer. For hands, kit
   and net, also import the `_regions.svg` if helpful.
2. Use selection masks to edit one existing region at a time. Supply the
   original atlas, rather than a rendered character, as the image-editing input.
   Use the shared prompt below, followed by the asset-specific prompt.
3. Compare the generated image to the original at 50% opacity. Landmark edges,
   finger/nail positions, clothing boundaries, panel seams and symbols must
   remain registered. Copy improved material detail back into the original
   layout if the generator moves any features.
4. Blend across UV seams and retain the existing filled gutters. Extend material
   colors at least 8–16 pixels beyond an island where space permits, staying
   within its material region. For enlarged images, scale this padding too.
5. Hide every guide layer. Export an 8-bit RGB or RGBA PNG in sRGB. Keep alpha
   fully opaque, matching the current atlases. Keep the exact filenames above.
   Keep text/flag artwork on separate layers so it stays legible.

Use this instruction at the start of every image-editing prompt:

> Edit the supplied flat game texture atlas in place. Preserve its exact canvas
> dimensions, orientation, UV layout, island positions, proportions, boundaries
> and registration. Improve only the materials and surface detail in the selected
> region. Produce a flat diffuse color texture with neutral even illumination.
> Preserve the alpha channel and existing edge padding. No camera perspective,
> cast shadows, directional lighting, new UV layout, rendered character, drawn
> wireframe, labels or background scene.

Then add the appropriate material instruction:

**First-person hands — `bv_hands.png`**

> Refine the existing skin of an adult male professional beach volleyball player.
> Match the existing fair, lightly sun-tanned skin tone. Add fine natural pores,
> subtle pigmentation variation, faint freckles, restrained veins and sparse fine
> forearm hair. Retain the exact palm creases, finger joints and nail placements.
> Make knuckles slightly warmer and fingertips and palms softly pinker. Nails
> are short, natural, translucent-looking, with subtle nail beds and cuticles.
> Keep pores fine and contrast gentle; the skin should look healthy and matte.
> Blend wrist color continuously into the forearm region.

The separate forearm strip is **x=4..508, y=1820..2044** in the 512 × 2048
image. Its top connects to the wrist and its bottom extends toward the elbow
behind the camera. Match the wrist along the top edge; blend smoothly down the
strip. The strip wraps around the arm horizontally, so its left/right edges
need matching color and texture. Keep the existing four-pixel outer gutters.
Some hand UVs reuse skin areas; asymmetric large marks can repeat or mirror.

**Athletes — `bv_athlete.png`, then `bv_athlete_away.png`**

> Refine this exact anatomical texture atlas for an adult male beach volleyball
> athlete. Keep face, ears, lips, hands, feet, hair and all clothing boundaries
> registered. Match the hand texture's fair, lightly sun-tanned skin. Add subtle
> pores, natural facial color variation, faint stubble, gentle lip detail and
> restrained muscle definition through color variation. Improve the existing
> uniform with fine performance-fabric weave and subtle stitching at its existing
> edges. Preserve the Norway flag, NOR lettering and number 1 exactly. Home kit
> remains navy; away kit remains red. Preserve the shorts color and design.

Finish the home skin first. Transfer identical exposed-skin improvements to the
away atlas, then edit its uniform separately. This keeps the two athletes
consistent. Preserve the current white lettering and flag with masks if the
generator cannot reproduce them exactly.

**Cap and sunglasses — `bv_kit.png`**

> Improve the existing cap and sunglasses materials without moving atlas regions.
> Navy cap fabric has fine woven texture and understated stitching. The full sun
> shield uses a smooth cyan-to-deep-blue mirrored coating with a restrained broad
> sky-colored reflection band and a narrow soft highlight. The frame and temples
> retain their dark finish. Preserve the current color layout and UV padding.

The shield samples **x=384..512, y=256..384**; the navy cap/temples sample
**x=256..384, y=384..512** at the current resolution, with 16-pixel UV insets.
Use the orange region guide. Skin/uniform/hair regions in this small atlas are
legacy swatches; current body anatomy uses the separate 2048 × 2048 textures.
The shield's reflection is painted and stays attached to the texture during play.

**Ball — `bv_ball.png`**

> Refine the supplied spherical volleyball texture map in place. Preserve every
> existing curved white, yellow and blue panel, seam, valve and BEACH wordmark.
> Add fine embossed synthetic-leather grain, small consistent dimples, subtle
> manufacturing variation and lightly recessed seams. Keep panel colors clean
> and vivid, with warm off-white instead of blown-out pure white. Use neutral
> illumination and restrained microcontrast. Match the left and right image
> edges seamlessly; retain the existing smooth polar areas.

This is a spherical latitude/longitude map, not a square tiling material. The
left/right edges join; the top/bottom rows meet the poles. Preserve the existing
panel construction and avoid adding large new details around those poles.

**Net — `bv_net.png`**

> Refine this exact material atlas for professional beach volleyball equipment.
> Navy bands use fine woven canvas; cords use dark braided synthetic fiber;
> padded posts use navy vinyl with restrained seams; metal fittings use satin
> stainless steel with subtle machining variation; antennas retain clean red
> and warm-white fiberglass sections. Preserve all region boundaries and
> dominant colors. Keep detail small and contrast restrained for distant views.

Pixel rectangles use an exclusive right/bottom edge:

| Material | x0, y0, x1, y1 |
| --- | --- |
| Canvas | 0, 0, 512, 512 |
| Cord | 512, 0, 1024, 256 |
| Metal | 512, 256, 1024, 512 |
| Post padding | 0, 512, 512, 1024 |
| Red antenna | 512, 512, 1024, 768 |
| White antenna | 512, 768, 1024, 1024 |

Most net parts sample small patches near these rectangles' centers. The UV
overlay shows the actual sampled areas; large artwork elsewhere may not appear.
The open mesh is modeled cord geometry: paint its cord material, not a picture
of a complete net over the atlas.

Return the six finished PNGs together, keeping filenames and a consistent skin
palette. Keep the layered working files for later changes. Integration will
update the source textures, generated copies and quality hashes, then review the
setting, float contact, both cuts and moving bodies in the browser and QSS-M.
The existing generators recreate some atlases, so directly replacing files in
`dist/` is only a temporary preview and will be overwritten by a later build.
