# Upstream credits

This project is licensed under GPL-2.0-or-later. A copy of the license is in
`LICENSE`.

- `resources/anorms.h` is the Quake alias-model normal table, copied without
  changes from [QSS-M](https://github.com/timbergeron/QSS-M/blob/qsrebase/Quake/anorms.h).
  Copyright (C) 1996–1997 id Software, Inc.; GPL-2.0-or-later. Its original notice
  is preserved. The table gives the generated models correct lighting.
- `src/defs.qc` adapts the minimal NetQuake ABI declarations from QSS-M's
  `Misc/ssqcharness/src/defs.qc`, with shared server/client declarations and
  volleyball-specific extensions added on 2026-10-04. The QSS-M source is
  distributed under the GNU GPL; these declarations remain under GPL-2.0-or-later.
- [FTEQCC](https://github.com/fte-team/fteqw) and
  [ericw-tools](https://github.com/ericwa/ericw-tools) are external build tools.
  Their binaries are not bundled here.

The court, textures, skybox, ball, shadow, marker, athlete and hand models, bitmap HUD font, and contact
sounds are generated from this project's Python source. No Quake PAK files, stock models,
or stock textures are distributed. A local Quake installation supplies the
palette during the build.

The controls take inspiration from Virtua Tennis. No Sega assets or code are
used. This is an independent mod and is not affiliated with Sega or id Software.
