#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Stage the HUD font and menu logo, or rebuild the DejaVu Sans atlas.

Normal builds need only Python's standard library. To regenerate the font:
python3 hud_assets.py --font
This optional operation requires libcairo and DejaVu Sans (Debian packages
libcairo2 and fonts-dejavu-core). Font licensing is in resources/ui/LICENSE.txt.
To refresh the menu logo from its original PNG, run with --logo (needs Pillow).
To rebuild menu icons and native court preview textures, run with --menu.
"""

import argparse
import ctypes as ct
import ctypes.util
from pathlib import Path
import shutil
import struct


HERE = Path(__file__).resolve().parent


def write_tga(path, width, height, pixels):
    header = bytearray(18)
    header[2] = 2
    struct.pack_into("<HH", header, 12, width, height)
    header[16:18] = bytes((32, 0x28))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + bytes(channel for pixel in pixels
                                   for channel in (pixel[2], pixel[1], pixel[0], pixel[3])))


def generate(destination):
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(HERE / "resources/ui/bv_ui.tga", destination / "bv_ui.tga")
    shutil.copyfile(HERE / "resources/ui/bv_logo.tga", destination / "bv_logo.tga")
    for name in ("bv_menu_icons.tga", "bv_menu_court.tga", "bv_menu_card.tga", "bv_ui_bold.tga"):
        shutil.copyfile(HERE / "resources/ui" / name, destination / name)


def generate_menu():
    """Bake original vector icons and stage a native court capture for previews."""
    import math

    cairo = ct.CDLL(ctypes.util.find_library("cairo"))

    def bind(name, restype, *argtypes):
        fn = getattr(cairo, "cairo_" + name)
        fn.restype, fn.argtypes = restype, argtypes
        return fn

    pointer, number = ct.c_void_p, ct.c_double
    surface = bind("image_surface_create", pointer, ct.c_int, ct.c_int, ct.c_int)(0, 512, 256)
    context = bind("create", pointer, pointer)(surface)
    move = bind("move_to", None, pointer, number, number)
    line = bind("line_to", None, pointer, number, number)
    curve = bind("curve_to", None, pointer, *([number] * 6))
    arc = bind("arc", None, pointer, *([number] * 5))
    stroke = bind("stroke", None, pointer)
    save = bind("save", None, pointer)
    restore = bind("restore", None, pointer)
    translate = bind("translate", None, pointer, number, number)
    scale = bind("scale", None, pointer, number, number)
    bind("set_source_rgba", None, pointer, *([number] * 4))(context, 1, 1, 1, 1)
    bind("set_line_width", None, pointer, number)(context, 1.6)
    bind("set_line_cap", None, pointer, ct.c_int)(context, 1)
    bind("set_line_join", None, pointer, ct.c_int)(context, 1)

    def path(points, close=False):
        move(context, *points[0])
        for point in points[1:]:
            line(context, *point)
        if close:
            line(context, *points[0])
        stroke(context)

    for icon in range(8):
        save(context)
        translate(context, (icon % 4) * 128 + 16, (icon // 4) * 128 + 16)
        scale(context, 3, 3)
        if icon == 0:
            arc(context, 16, 16, 14, 0, math.tau)
            stroke(context)
            for angle in (0, math.tau / 3, math.tau * 2 / 3):
                save(context)
                translate(context, 16, 16)
                bind("rotate", None, pointer, number)(context, angle)
                move(context, 0, 0)
                curve(context, 0, -7, 6, -9, 7, -12)
                move(context, 0, -6)
                curve(context, -4, -9, -4, -11, -3, -13.5)
                stroke(context)
                restore(context)
        elif icon == 1:
            path([(5, 16), (27, 16)])
            path([(19, 8), (27, 16), (19, 24)])
        elif icon == 2:
            arc(context, 16, 16, 13, 0, math.tau)
            stroke(context)
            path([(22, 9), (18, 20), (10, 24), (14, 13)], True)
        elif icon == 3:
            move(context, 9, 8)
            curve(context, 2, 8, 1, 23, 5, 25)
            curve(context, 8, 26, 10, 21, 12, 21)
            line(context, 20, 21)
            curve(context, 22, 21, 24, 26, 27, 25)
            curve(context, 31, 23, 30, 8, 23, 8)
            line(context, 9, 8)
            stroke(context)
            path([(7, 14), (13, 14)])
            path([(10, 11), (10, 17)])
            for x, y in ((22, 12), (25, 16)):
                arc(context, x, y, 1, 0, math.tau)
                stroke(context)
        elif icon == 4:
            arc(context, 16, 17, 12, -math.pi * 0.34, math.pi * 1.34)
            stroke(context)
            path([(16, 2), (16, 15)])
        elif icon == 5:
            path([(2, 12), (16, 5), (30, 12), (16, 19)], True)
            path([(8, 16), (8, 25), (16, 28), (24, 25), (24, 16)])
            path([(30, 12), (30, 24)])
        elif icon == 6:
            arc(context, 16, 16, 13, 0, math.tau)
            stroke(context)
            path([(9, 16), (23, 16)])
            path([(16, 9), (16, 23)])
        else:
            path([(2, 16), (30, 16)])
            for x, height in ((5, 8), (9, 12), (23, 12), (27, 8)):
                path([(x, 16 - height / 2), (x, 16 + height / 2)])
        restore(context)
    bind("surface_flush", None, pointer)(surface)
    data = bind("image_surface_get_data", ct.POINTER(ct.c_ubyte), pointer)(surface)
    stride = bind("image_surface_get_stride", ct.c_int, pointer)(surface)
    write_tga(HERE / "resources/ui/bv_menu_icons.tga", 512, 256,
              [(255, 255, 255, data[y * stride + x * 4 + 3]) for y in range(256) for x in range(512)])
    bind("destroy", None, pointer)(context)
    bind("surface_destroy", None, pointer)(surface)
    court = bind("image_surface_create_from_png", pointer, ct.c_char_p)(
        str(HERE / "docs/court.png").encode())
    surface = bind("image_surface_create", pointer, ct.c_int, ct.c_int, ct.c_int)(0, 640, 360)
    context = bind("create", pointer, pointer)(surface)
    source_width = bind("image_surface_get_width", ct.c_int, pointer)(court)
    source_height = bind("image_surface_get_height", ct.c_int, pointer)(court)
    scale(context, 640 / source_width, 360 / source_height)
    bind("set_source_surface", None, pointer, pointer, number, number)(context, court, 0, 0)
    bind("paint", None, pointer)(context)
    bind("surface_flush", None, pointer)(surface)
    data = bind("image_surface_get_data", ct.POINTER(ct.c_ubyte), pointer)(surface)
    stride = bind("image_surface_get_stride", ct.c_int, pointer)(surface)
    write_tga(HERE / "resources/ui/bv_menu_court.tga", 640, 360,
              [(data[y * stride + x * 4 + 2], data[y * stride + x * 4 + 1],
                data[y * stride + x * 4], 255) for y in range(360) for x in range(640)])
    write_tga(HERE / "resources/ui/bv_menu_card.tga", 640, 360,
              [(data[y * stride + x * 4 + 2], data[y * stride + x * 4 + 1],
                data[y * stride + x * 4], round(255 * min(x / 320, 1) * min(y / 24, (359 - y) / 24, 1)))
               for y in range(360) for x in range(640)])
    bind("destroy", None, pointer)(context)
    bind("surface_destroy", None, pointer)(surface)
    bind("surface_destroy", None, pointer)(court)


def generate_logo():
    """Prepare the supplied transparent artwork; never needed at runtime."""
    from PIL import Image

    with Image.open(HERE / "Quake Beach Volleyball Arcade Logo.png") as source:
        logo = source.convert("RGBA").resize((768, 576), Image.Resampling.LANCZOS)
        logo.save(HERE / "resources/ui/bv_logo.tga", compression=None)


def generate_font(bold=False):
    """Bake 32 px glyph cells and matching advances; never needed at runtime."""
    cairo = ct.CDLL(ctypes.util.find_library("cairo"))

    def bind(name, restype, *argtypes):
        fn = getattr(cairo, "cairo_" + name)
        fn.restype, fn.argtypes = restype, argtypes
        return fn

    class Extents(ct.Structure):
        _fields_ = [(name, ct.c_double) for name in
                    ("x_bearing", "y_bearing", "width", "height", "x_advance", "y_advance")]

    pointer, number = ct.c_void_p, ct.c_double
    surface = bind("image_surface_create", pointer, ct.c_int, ct.c_int, ct.c_int)(2, 512, 512)
    context = bind("create", pointer, pointer)(surface)
    bind("select_font_face", None, pointer, ct.c_char_p, ct.c_int, ct.c_int)(
        context, b"DejaVu Sans", 0, int(bold))
    bind("set_font_size", None, pointer, number)(context, 28)
    bind("set_source_rgba", None, pointer, number, number, number, number)(context, 1, 1, 1, 1)
    move = bind("move_to", None, pointer, number, number)
    show = bind("show_text", None, pointer, ct.c_char_p)
    save = bind("save", None, pointer)
    restore = bind("restore", None, pointer)
    rectangle = bind("rectangle", None, pointer, number, number, number, number)
    clip = bind("clip", None, pointer)
    measure = bind("text_extents", None, pointer, ct.c_char_p, ct.POINTER(Extents))
    advances = []
    for code in range(32, 127):
        character = chr(code).encode("ascii")
        extent = Extents()
        measure(context, character, ct.byref(extent))
        advances.append(round(extent.x_advance))
        ox, oy = (code % 16) * 32, (code // 16) * 32
        # A transparent texel gutter prevents adjacent glyphs bleeding when
        # the engine linearly filters a scaled subsection of the atlas.
        save(context)
        rectangle(context, ox + 1, oy + 1, 30, 30)
        clip(context)
        move(context, ox + 1, oy + 24)
        show(context, character)
        restore(context)
    bind("surface_flush", None, pointer)(surface)
    data = bind("image_surface_get_data", ct.POINTER(ct.c_ubyte), pointer)(surface)
    stride = bind("image_surface_get_stride", ct.c_int, pointer)(surface)
    atlas = "bv_ui_bold.tga" if bold else "bv_ui.tga"
    write_tga(HERE / "resources/ui" / atlas, 512, 512,
              [(255, 255, 255, data[y * stride + x]) for y in range(512) for x in range(512)])
    bind("destroy", None, pointer)(context)
    bind("surface_destroy", None, pointer)(surface)
    # Printable ASCII encodes each advance plus 33. Escape QC string syntax.
    widths = "".join(chr(value + 33) for value in advances).replace("\\", "\\\\").replace('"', '\\"')
    metrics = "hud_metrics_bold.qc" if bold else "hud_metrics.qc"
    function = "BV_GlyphBoldAdvance" if bold else "BV_GlyphAdvance"
    (HERE / "src" / metrics).write_text(
        "// Generated by hud_assets.py --font; DejaVu Sans, see resources/ui/LICENSE.txt.\n"
        f"float(float character) {function} =\n{{\n"
        "    if (character < 32 || character > 126) character = 63;\n"
        f'    return (str2chr("{widths}", character - 32) - 33) / 32;\n'
        "};\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--font", action="store_true")
    parser.add_argument("--logo", action="store_true")
    parser.add_argument("--menu", action="store_true")
    args = parser.parse_args()
    if args.font:
        generate_font()
        generate_font(bold=True)
    if args.logo:
        generate_logo()
    if args.menu:
        generate_menu()
    if not args.font and not args.logo and not args.menu:
        generate(HERE / "dist/beachvolley/gfx")
