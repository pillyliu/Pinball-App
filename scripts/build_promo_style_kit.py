#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import random
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps


CANVAS = (3840, 2160)
SAFE_MARGIN = 160
TEXT_SAFE_MARGIN = 220
PRESENTER_WIDTH = 1360
APP_PANE_WIDTH = 1760
APP_PANE_HEIGHT = 1320
APP_PANE_MARGIN_RIGHT = 180
APP_PANE_Y = (CANVAS[1] - APP_PANE_HEIGHT) // 2
FULL_APP_PANE = (CANVAS[0] - APP_PANE_MARGIN_RIGHT - APP_PANE_WIDTH, APP_PANE_Y)
FULL_APP_RECT = (*FULL_APP_PANE, FULL_APP_PANE[0] + APP_PANE_WIDTH, FULL_APP_PANE[1] + APP_PANE_HEIGHT)
FULL_APP_INNER_RECT = (2353, 440, 3207, 1720)
FOCUS_PANE_WIDTH = 1760
FOCUS_PANE_HEIGHT = 1056
FOCUS_PANE_X = CANVAS[0] - APP_PANE_MARGIN_RIGHT - FOCUS_PANE_WIDTH
FOCUS_PANE_Y = 552
FOCUS_PANE_RECT = (FOCUS_PANE_X, FOCUS_PANE_Y, FOCUS_PANE_X + FOCUS_PANE_WIDTH, FOCUS_PANE_Y + FOCUS_PANE_HEIGHT)
FOCUS_INNER_RECT = (1920, 572, 3640, 1588)
FOCUS_LABEL_RECT = (2260, 1656, 3300, 1788)
FEATURE_LABEL_RECT = (1948, 1492, 2876, 1604)
PHONE_CAPTURE_WIDTH = 1320
PHONE_CAPTURE_HEIGHT = 2868
PHONE_SCREEN_HEIGHT = 1960
PHONE_SCREEN_WIDTH = round(PHONE_SCREEN_HEIGHT * PHONE_CAPTURE_WIDTH / PHONE_CAPTURE_HEIGHT)
PHONE_BEZEL = 26
PHONE_FRAME_WIDTH = PHONE_SCREEN_WIDTH + PHONE_BEZEL * 2
PHONE_FRAME_HEIGHT = PHONE_SCREEN_HEIGHT + PHONE_BEZEL * 2
PHONE_FRAME_MARGIN_RIGHT = 180
PHONE_FRAME_X = CANVAS[0] - PHONE_FRAME_MARGIN_RIGHT - PHONE_FRAME_WIDTH
PHONE_FRAME_Y = (CANVAS[1] - PHONE_FRAME_HEIGHT) // 2
PHONE_FRAME_RECT = (
    PHONE_FRAME_X,
    PHONE_FRAME_Y,
    PHONE_FRAME_X + PHONE_FRAME_WIDTH,
    PHONE_FRAME_Y + PHONE_FRAME_HEIGHT,
)
PHONE_SCREEN_RECT = (
    PHONE_FRAME_X + PHONE_BEZEL,
    PHONE_FRAME_Y + PHONE_BEZEL,
    PHONE_FRAME_X + PHONE_BEZEL + PHONE_SCREEN_WIDTH,
    PHONE_FRAME_Y + PHONE_BEZEL + PHONE_SCREEN_HEIGHT,
)
PHONE_FRAME_RADIUS = 120
PHONE_SCREEN_RADIUS = 96
PHONE_FOCUS_CAPTURE_HEIGHT = PHONE_CAPTURE_WIDTH * 3 // 2
PHONE_FOCUS_SCREEN_HEIGHT = PHONE_SCREEN_HEIGHT
PHONE_FOCUS_SCREEN_WIDTH = round(PHONE_FOCUS_SCREEN_HEIGHT * PHONE_CAPTURE_WIDTH / PHONE_FOCUS_CAPTURE_HEIGHT)
PHONE_FOCUS_FRAME_WIDTH = PHONE_FOCUS_SCREEN_WIDTH + PHONE_BEZEL * 2
PHONE_FOCUS_FRAME_HEIGHT = PHONE_FOCUS_SCREEN_HEIGHT + PHONE_BEZEL * 2
PHONE_FOCUS_FRAME_X = CANVAS[0] - PHONE_FRAME_MARGIN_RIGHT - PHONE_FOCUS_FRAME_WIDTH
PHONE_FOCUS_FRAME_Y = PHONE_FRAME_Y
PHONE_FOCUS_FRAME_RECT = (
    PHONE_FOCUS_FRAME_X,
    PHONE_FOCUS_FRAME_Y,
    PHONE_FOCUS_FRAME_X + PHONE_FOCUS_FRAME_WIDTH,
    PHONE_FOCUS_FRAME_Y + PHONE_FOCUS_FRAME_HEIGHT,
)
PHONE_FOCUS_SCREEN_RECT = (
    PHONE_FOCUS_FRAME_X + PHONE_BEZEL,
    PHONE_FOCUS_FRAME_Y + PHONE_BEZEL,
    PHONE_FOCUS_FRAME_X + PHONE_BEZEL + PHONE_FOCUS_SCREEN_WIDTH,
    PHONE_FOCUS_FRAME_Y + PHONE_BEZEL + PHONE_FOCUS_SCREEN_HEIGHT,
)
INTRO_PRESENTER_CENTER = (1120, 1080)
INTRO_PRESENTER_SIZE = 1180
PRESENTER_FEATHER_RECT = (120, 150, 1680, 2010)
PRESENTER_FEATHER_RADIUS = 220
PRESENTER_FEATHER_BLUR = 120
INTRO_LOGO_CENTER = (2840, 1080)
INTRO_LOGO_FRAME_SIZE = 1120
INTRO_LOGO_SIZE = 910
OUTRO_LOGO_CENTER = (CANVAS[0] // 2, CANVAS[1] // 2)
OUTRO_LOGO_FRAME_SIZE = 1640
OUTRO_LOGO_SIZE = 1380
WATERMARK_LOGO_CENTER = (3635, 1910)
WATERMARK_FRAME_SIZE = 300
WATERMARK_LOGO_SIZE = 248
WATERMARK_FEATHER = 104

COLORS = {
    "launch_black": "#060609",
    "atmosphere_top": "#121724",
    "atmosphere_bottom": "#1A212E",
    "brand_gold": "#FFD44A",
    "brand_chalk": "#8AB8A8",
    "brand_ink": "#D1E6FF",
    "league_blue": "#7DD3FC",
    "success_green": "#6EE7B7",
    "warning_red": "#FCA5A5",
    "panel_graphite": "#121417",
    "panel_fill": "#1A1F25",
    "panel_outline": "#F3F6FB",
}

SECTION_ACCENTS = {
    "library": "#8FDBC7",
    "practice": "#FFDB66",
    "gameroom": "#F5C75C",
    "settings": "#B8E6C2",
    "league": "#7DD3FC",
}

TITLE_SUBTITLES = {
    "library": "Rulesheets, playfields, and gameplay at a glance",
    "practice": "Study notes, score entry, and practice targets",
    "gameroom": "Your machines, issues, and history",
    "settings": "Imports, locations, and profile setup",
    "league": "Stats, standings, and score targets",
}

TITLE_DISPLAY = {
    "library": "Library",
    "practice": "Practice",
    "gameroom": "GameRoom",
    "settings": "Settings",
    "league": "League",
}

SECTION_PREVIEW_LABELS = {
    "library": {"full": "Read Rulesheet", "focus": "View Playfield"},
    "practice": {"full": "Log Study", "focus": "Scan Score"},
    "gameroom": {"full": "Track Issues", "focus": "Organize Games"},
    "settings": {"full": "Import Venues", "focus": "IFPA Profile"},
    "league": {"full": "View Stats", "focus": "View Standings"},
}


@dataclass
class LayoutSpec:
    pane_rect: tuple[int, int, int, int]
    media_rect: tuple[int, int, int, int]
    corner_radius: int
    media_corner_radius: int | None = None


def rgba(hex_value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_value = hex_value.lstrip("#")
    return tuple(int(hex_value[index:index + 2], 16) for index in (0, 2, 4)) + (alpha,)


def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


def fit_text(draw: ImageDraw.ImageDraw, text: str, font_path: str, start_size: int, max_width: int) -> ImageFont.FreeTypeFont:
    size = start_size
    while size > 12:
        font = load_font(font_path, size)
        bbox = draw.textbbox((0, 0), text, font=font)
        if bbox[2] - bbox[0] <= max_width:
            return font
        size -= 2
    return load_font(font_path, 12)


def crop_center(image: Image.Image, target_ratio: float) -> Image.Image:
    width, height = image.size
    current_ratio = width / height
    if current_ratio > target_ratio:
        new_width = int(height * target_ratio)
        left = (width - new_width) // 2
        return image.crop((left, 0, left + new_width, height))
    new_height = int(width / target_ratio)
    top = (height - new_height) // 2
    return image.crop((0, top, width, top + new_height))


def cover_image(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGBA")
    target_ratio = size[0] / size[1]
    cropped = crop_center(image, target_ratio)
    return cropped.resize(size, Image.Resampling.LANCZOS)


def add_radial_glow(base: Image.Image, center: tuple[int, int], diameter: int, color: tuple[int, int, int], opacity: float) -> None:
    blur = max(24, diameter // 5)
    margin = blur * 3
    wide_size = (CANVAS[0] + margin * 2, CANVAS[1] + margin * 2)
    layer = Image.new("RGBA", wide_size, (0, 0, 0, 0))
    shifted_center = (center[0] + margin, center[1] + margin)
    bbox = (
        shifted_center[0] - diameter // 2,
        shifted_center[1] - diameter // 2,
        shifted_center[0] + diameter // 2,
        shifted_center[1] + diameter // 2,
    )
    ImageDraw.Draw(layer).ellipse(bbox, fill=(*color, int(255 * opacity)))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer.crop((margin, margin, margin + CANVAS[0], margin + CANVAS[1])))


def add_soft_ellipse(
    base: Image.Image,
    bbox: tuple[int, int, int, int],
    color: tuple[int, int, int, int],
    blur: int,
) -> None:
    margin = blur * 3
    wide_size = (CANVAS[0] + margin * 2, CANVAS[1] + margin * 2)
    layer = Image.new("RGBA", wide_size, (0, 0, 0, 0))
    shifted_bbox = (bbox[0] + margin, bbox[1] + margin, bbox[2] + margin, bbox[3] + margin)
    ImageDraw.Draw(layer).ellipse(shifted_bbox, fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer.crop((margin, margin, margin + CANVAS[0], margin + CANVAS[1])))


def rounded_mask(rect: tuple[int, int, int, int], radius: int, fill: int = 255) -> Image.Image:
    mask = Image.new("L", CANVAS, 0)
    ImageDraw.Draw(mask).rounded_rectangle(rect, radius=radius, fill=fill)
    return mask


def soft_rounded_falloff_mask(
    rect: tuple[int, int, int, int],
    radius: int,
    feather: int,
    inner_inset: int,
) -> Image.Image:
    outer = rounded_mask(rect, radius).filter(ImageFilter.GaussianBlur(feather))
    inner_rect = (
        rect[0] + inner_inset,
        rect[1] + inner_inset,
        rect[2] - inner_inset,
        rect[3] - inner_inset,
    )
    inner_radius = max(32, radius - inner_inset)
    inner = rounded_mask(inner_rect, inner_radius)
    return ImageChops.lighter(outer, inner)


def make_background(accent_bias: str | None = None) -> Image.Image:
    width, height = CANVAS
    background = Image.new("RGBA", CANVAS, rgba(COLORS["launch_black"]))
    start = Image.new("RGBA", CANVAS, rgba("#18202D"))
    end = Image.new("RGBA", CANVAS, rgba("#08101C"))
    diagonal = Image.linear_gradient("L").rotate(-35, expand=True).resize((width * 2, height * 2), Image.Resampling.BICUBIC)
    left = (diagonal.width - width) // 2
    top = (diagonal.height - height) // 2
    mask = diagonal.crop((left, top, left + width, top + height))
    gradient = Image.composite(end, start, mask)
    background = Image.alpha_composite(background, gradient)

    add_radial_glow(background, (560, 260), 1840, rgba(COLORS["brand_gold"])[:3], 0.18)
    add_radial_glow(background, (1040, 420), 980, rgba("#F6CF61")[:3], 0.06)
    add_radial_glow(background, (3250, 1810), 1980, rgba("#0F3B70")[:3], 0.18)
    add_radial_glow(background, (2580, 980), 1240, rgba("#16304F")[:3], 0.09)

    if accent_bias:
        add_radial_glow(background, (3000, 980), 1080, rgba(SECTION_ACCENTS[accent_bias])[:3], 0.08)

    vignette = Image.radial_gradient("L").resize((width, height), Image.Resampling.LANCZOS)
    vignette = vignette.point(lambda value: int(value * 0.18))
    vignette_layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    vignette_layer.putalpha(vignette)
    background = Image.alpha_composite(background, vignette_layer)
    return background


def rounded_panel_overlay(
    rect: tuple[int, int, int, int],
    radius: int,
    fill_color: tuple[int, int, int, int],
    border_color: tuple[int, int, int, int],
    border_width: int,
    glow_color: tuple[int, int, int, int] | None = None,
    shadow_alpha: int = 56,
    shadow_offset_y: int = 24,
    shadow_blur: int = 60,
) -> Image.Image:
    overlay = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    shadow_mask = Image.new("L", CANVAS, 0)
    shadow_draw = ImageDraw.Draw(shadow_mask)
    shadow_rect = (rect[0], rect[1] + shadow_offset_y, rect[2], rect[3] + shadow_offset_y)
    shadow_draw.rounded_rectangle(shadow_rect, radius=radius, fill=shadow_alpha)
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(shadow_blur)))
    overlay = Image.alpha_composite(overlay, shadow)

    if glow_color is not None:
        glow_mask = Image.new("L", CANVAS, 0)
        glow_draw = ImageDraw.Draw(glow_mask)
        expanded = (rect[0] - 6, rect[1] - 6, rect[2] + 6, rect[3] + 6)
        glow_draw.rounded_rectangle(expanded, radius=radius + 6, fill=glow_color[3])
        glow = Image.new("RGBA", CANVAS, (*glow_color[:3], 0))
        glow.putalpha(glow_mask.filter(ImageFilter.GaussianBlur(26)))
        overlay = Image.alpha_composite(overlay, glow)

    draw.rounded_rectangle(rect, radius=radius, fill=fill_color)
    draw.rounded_rectangle(rect, radius=radius, outline=border_color, width=border_width)
    return overlay


def feature_label_overlay(text: str, accent_hex: str) -> Image.Image:
    overlay = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    panel = rounded_panel_overlay(
        FEATURE_LABEL_RECT,
        radius=24,
        fill_color=rgba(COLORS["panel_fill"], 220),
        border_color=rgba(accent_hex, 56),
        border_width=2,
        glow_color=rgba(accent_hex, 42),
        shadow_alpha=38,
        shadow_offset_y=18,
        shadow_blur=38,
    )
    overlay = Image.alpha_composite(overlay, panel)
    draw = ImageDraw.Draw(overlay)
    accent_bar = (
        FEATURE_LABEL_RECT[0] + 26,
        FEATURE_LABEL_RECT[1] + 30,
        FEATURE_LABEL_RECT[0] + 36,
        FEATURE_LABEL_RECT[1] + 82,
    )
    draw.rounded_rectangle(accent_bar, radius=999, fill=rgba(accent_hex))
    ui_font_path = "/System/Library/Fonts/SFNS.ttf"
    font = fit_text(draw, text, ui_font_path, 50, 700)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_x = FEATURE_LABEL_RECT[0] + 70
    text_y = FEATURE_LABEL_RECT[1] + ((FEATURE_LABEL_RECT[3] - FEATURE_LABEL_RECT[1]) - (bbox[3] - bbox[1])) // 2 - 4
    draw.text((text_x, text_y), text, font=font, fill=rgba("#F3F6FB"))
    return overlay


def focus_phrase_overlay(text: str, accent_hex: str) -> Image.Image:
    overlay = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    panel = rounded_panel_overlay(
        FOCUS_LABEL_RECT,
        radius=30,
        fill_color=rgba(COLORS["panel_fill"], 224),
        border_color=rgba(accent_hex, 60),
        border_width=2,
        glow_color=rgba(accent_hex, 46),
        shadow_alpha=34,
        shadow_offset_y=20,
        shadow_blur=34,
    )
    overlay = Image.alpha_composite(overlay, panel)
    draw = ImageDraw.Draw(overlay)
    font = fit_text(draw, text, "/System/Library/Fonts/SFNS.ttf", 60, 900)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_x = FOCUS_LABEL_RECT[0] + ((FOCUS_LABEL_RECT[2] - FOCUS_LABEL_RECT[0]) - (bbox[2] - bbox[0])) // 2
    text_y = FOCUS_LABEL_RECT[1] + ((FOCUS_LABEL_RECT[3] - FOCUS_LABEL_RECT[1]) - (bbox[3] - bbox[1])) // 2 - 6
    draw.text((text_x, text_y), text, font=font, fill=rgba("#F3F6FB"))
    return overlay


def pane_base(rect: tuple[int, int, int, int], radius: int, accent_hex: str) -> Image.Image:
    pane = rounded_panel_overlay(
        rect,
        radius=radius,
        fill_color=rgba(COLORS["panel_graphite"], 228),
        border_color=rgba(COLORS["panel_outline"], 46),
        border_width=2,
        glow_color=rgba(accent_hex, 38),
    )
    draw = ImageDraw.Draw(pane)
    highlight_rect = (rect[0] + 6, rect[1] + 6, rect[2] - 6, rect[1] + 118)
    highlight = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.rounded_rectangle(highlight_rect, radius=radius - 8, fill=rgba("#FFFFFF", 18))
    highlight = highlight.filter(ImageFilter.GaussianBlur(18))
    pane = Image.alpha_composite(pane, highlight)
    draw.rounded_rectangle((rect[0] + 1, rect[1] + 1, rect[2] - 1, rect[3] - 1), radius=radius, outline=rgba(accent_hex, 22), width=1)
    return pane


def transparent_phone_frame_overlay(layout: LayoutSpec, accent_hex: str) -> Image.Image:
    outer_radius = layout.corner_radius
    inner_radius = layout.media_corner_radius or max(24, outer_radius - 24)
    outer_mask = rounded_mask(layout.pane_rect, outer_radius)
    inner_mask = rounded_mask(layout.media_rect, inner_radius)
    ring_mask = ImageChops.subtract(outer_mask, inner_mask)

    overlay = Image.new("RGBA", CANVAS, (0, 0, 0, 0))

    shadow_mask = Image.new("L", CANVAS, 0)
    shifted_shadow_rect = (
        layout.pane_rect[0],
        layout.pane_rect[1] + 28,
        layout.pane_rect[2],
        layout.pane_rect[3] + 28,
    )
    ImageDraw.Draw(shadow_mask).rounded_rectangle(shifted_shadow_rect, radius=outer_radius, fill=92)
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(62)))
    overlay = Image.alpha_composite(overlay, shadow)

    glow_mask = rounded_mask(
        (
            layout.pane_rect[0] - 8,
            layout.pane_rect[1] - 8,
            layout.pane_rect[2] + 8,
            layout.pane_rect[3] + 8,
        ),
        outer_radius + 8,
    )
    glow = Image.new("RGBA", CANVAS, rgba(accent_hex, 0))
    glow.putalpha(glow_mask.filter(ImageFilter.GaussianBlur(28)).point(lambda value: min(255, int(value * 0.18))))
    overlay = Image.alpha_composite(overlay, glow)

    frame_fill = Image.new("RGBA", CANVAS, rgba("#101318", 228))
    frame_fill.putalpha(ring_mask)
    overlay = Image.alpha_composite(overlay, frame_fill)

    draw = ImageDraw.Draw(overlay)
    draw.rounded_rectangle(layout.pane_rect, radius=outer_radius, outline=rgba("#F3F6FB", 44), width=2)
    draw.rounded_rectangle(layout.media_rect, radius=inner_radius, outline=rgba("#F3F6FB", 28), width=2)
    draw.rounded_rectangle(
        (
            layout.pane_rect[0] + 3,
            layout.pane_rect[1] + 3,
            layout.pane_rect[2] - 3,
            layout.pane_rect[3] - 3,
        ),
        radius=outer_radius - 2,
        outline=rgba(accent_hex, 22),
        width=1,
    )
    return overlay


def transparent_window_matte(layout: LayoutSpec) -> Image.Image:
    inner_radius = layout.media_corner_radius or max(24, layout.corner_radius - 24)
    matte = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(matte).rounded_rectangle(layout.media_rect, radius=inner_radius, fill=(255, 255, 255, 255))
    return matte


def phone_frame_preview(background: Image.Image, screenshot_path: Path, accent_hex: str) -> Image.Image:
    preview = background.copy()
    screenshot = cover_image(Image.open(screenshot_path), (PHONE_SCREEN_WIDTH, PHONE_SCREEN_HEIGHT))
    preview.alpha_composite(screenshot, (PHONE_SCREEN_RECT[0], PHONE_SCREEN_RECT[1]))
    preview.alpha_composite(
        transparent_phone_frame_overlay(
            LayoutSpec(PHONE_FRAME_RECT, PHONE_SCREEN_RECT, PHONE_FRAME_RADIUS, PHONE_SCREEN_RADIUS),
            accent_hex,
        )
    )
    return preview


def intro_logo_glow_plate() -> Image.Image:
    plate = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    add_radial_glow(plate, INTRO_LOGO_CENTER, 1260, rgba(COLORS["brand_gold"])[:3], 0.12)
    add_radial_glow(plate, (INTRO_LOGO_CENTER[0] + 60, INTRO_LOGO_CENTER[1] - 20), 920, rgba("#F6CF61")[:3], 0.08)
    return plate


def presenter_feather_matte() -> Image.Image:
    mask = Image.new("L", CANVAS, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        PRESENTER_FEATHER_RECT,
        radius=PRESENTER_FEATHER_RADIUS,
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(PRESENTER_FEATHER_BLUR))
    matte = Image.new("RGBA", CANVAS, (255, 255, 255, 0))
    matte.putalpha(mask)
    return matte


def feather_presenter_on_background(background: Image.Image, presenter_path: Path) -> Image.Image:
    canvas = background.copy()
    presenter = cover_image(Image.open(presenter_path), (INTRO_PRESENTER_SIZE, INTRO_PRESENTER_SIZE))
    presenter_x = INTRO_PRESENTER_CENTER[0] - presenter.width // 2
    presenter_y = INTRO_PRESENTER_CENTER[1] - presenter.height // 2
    presenter_layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    presenter_layer.alpha_composite(presenter, (presenter_x, presenter_y))
    matte = presenter_feather_matte()
    presenter_layer.putalpha(ImageChops.multiply(presenter_layer.getchannel("A"), matte.getchannel("A")))
    return Image.alpha_composite(canvas, presenter_layer)


def logo_square_frame_overlay_at(center: tuple[int, int], frame_size: int, accent_hex: str = COLORS["brand_gold"]) -> Image.Image:
    half = frame_size // 2
    rect = (
        center[0] - half,
        center[1] - half,
        center[0] + half,
        center[1] + half,
    )
    overlay = rounded_panel_overlay(
        rect,
        radius=96,
        fill_color=rgba(COLORS["panel_graphite"], 228),
        border_color=rgba(COLORS["panel_outline"], 42),
        border_width=2,
        glow_color=rgba(accent_hex, 34),
        shadow_alpha=64,
        shadow_offset_y=18,
        shadow_blur=60,
    )
    highlight = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    highlight_rect = (rect[0] + 10, rect[1] + 10, rect[2] - 10, rect[1] + 150)
    ImageDraw.Draw(highlight).rounded_rectangle(highlight_rect, radius=84, fill=rgba("#FFFFFF", 18))
    highlight = highlight.filter(ImageFilter.GaussianBlur(18))
    overlay = Image.alpha_composite(overlay, highlight)
    draw = ImageDraw.Draw(overlay)
    draw.rounded_rectangle(
        (rect[0] + 2, rect[1] + 2, rect[2] - 2, rect[3] - 2),
        radius=94,
        outline=rgba(accent_hex, 18),
        width=1,
    )
    return overlay


def logo_art_layer(logo_path: Path, center: tuple[int, int], frame_size: int, logo_size: int) -> Image.Image:
    logo = Image.open(logo_path).convert("RGBA").resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    logo_x = center[0] - logo.width // 2
    logo_y = center[1] - logo.height // 2
    logo_layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    logo_layer.alpha_composite(logo, (logo_x, logo_y))
    logo_mask_rect = (
        center[0] - frame_size // 2 + 22,
        center[1] - frame_size // 2 + 22,
        center[0] + frame_size // 2 - 22,
        center[1] + frame_size // 2 - 22,
    )
    logo_mask = rounded_mask(logo_mask_rect, max(120, frame_size // 7))
    logo_layer.putalpha(ImageChops.multiply(logo_layer.getchannel("A"), logo_mask))
    return logo_layer


def logo_square_window_matte(center: tuple[int, int], frame_size: int) -> Image.Image:
    rect = (
        center[0] - frame_size // 2 + 22,
        center[1] - frame_size // 2 + 22,
        center[0] + frame_size // 2 - 22,
        center[1] + frame_size // 2 - 22,
    )
    matte = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(matte).rounded_rectangle(rect, radius=max(120, frame_size // 7), fill=(255, 255, 255, 255))
    return matte


def outro_logo_glow_plate() -> Image.Image:
    plate = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    add_radial_glow(plate, OUTRO_LOGO_CENTER, 1380, rgba(COLORS["brand_gold"])[:3], 0.14)
    add_radial_glow(plate, (OUTRO_LOGO_CENTER[0], OUTRO_LOGO_CENTER[1] - 40), 980, rgba("#F6CF61")[:3], 0.09)
    return plate


def watermark_logo_overlay(logo_path: Path) -> Image.Image:
    overlay = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    rect = (
        WATERMARK_LOGO_CENTER[0] - WATERMARK_FRAME_SIZE // 2,
        WATERMARK_LOGO_CENTER[1] - WATERMARK_FRAME_SIZE // 2,
        WATERMARK_LOGO_CENTER[0] + WATERMARK_FRAME_SIZE // 2,
        WATERMARK_LOGO_CENTER[1] + WATERMARK_FRAME_SIZE // 2,
    )

    add_radial_glow(overlay, WATERMARK_LOGO_CENTER, 520, rgba(COLORS["brand_gold"])[:3], 0.075)
    add_radial_glow(overlay, (WATERMARK_LOGO_CENTER[0], WATERMARK_LOGO_CENTER[1] - 8), 300, rgba("#F6CF61")[:3], 0.05)

    patch_mask = soft_rounded_falloff_mask(
        rect,
        max(84, WATERMARK_FRAME_SIZE // 3),
        WATERMARK_FEATHER,
        inner_inset=40,
    )

    patch = Image.new("RGBA", CANVAS, rgba(COLORS["panel_graphite"], 0))
    patch.putalpha(patch_mask.point(lambda value: int(value * 0.34)))
    overlay = Image.alpha_composite(overlay, patch)

    warm_rect = (
        rect[0] + 18,
        rect[1] + 18,
        rect[2] - 18,
        rect[3] - 18,
    )
    warm_mask = soft_rounded_falloff_mask(
        warm_rect,
        max(68, WATERMARK_FRAME_SIZE // 4),
        max(44, WATERMARK_FEATHER // 2),
        inner_inset=30,
    )
    warm = Image.new("RGBA", CANVAS, rgba(COLORS["brand_gold"], 0))
    warm.putalpha(warm_mask.point(lambda value: int(value * 0.09)))
    overlay = Image.alpha_composite(overlay, warm)

    logo = Image.open(logo_path).convert("RGBA").resize((WATERMARK_LOGO_SIZE, WATERMARK_LOGO_SIZE), Image.Resampling.LANCZOS)
    logo_x = WATERMARK_LOGO_CENTER[0] - logo.width // 2
    logo_y = WATERMARK_LOGO_CENTER[1] - logo.height // 2
    logo_layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    logo_layer.alpha_composite(logo, (logo_x, logo_y))
    logo_rect = (
        logo_x + 6,
        logo_y + 6,
        logo_x + logo.width - 6,
        logo_y + logo.height - 6,
    )
    logo_mask = rounded_mask(
        logo_rect,
        max(52, logo.width // 5),
    ).filter(ImageFilter.GaussianBlur(3))
    logo_layer.putalpha(ImageChops.multiply(logo_layer.getchannel("A"), logo_mask))
    overlay = Image.alpha_composite(overlay, logo_layer)

    return overlay


def watermark_preview(background: Image.Image, logo_path: Path) -> Image.Image:
    preview = background.copy()
    preview = Image.alpha_composite(preview, watermark_logo_overlay(logo_path))
    return preview


def intro_logo_reveal_preview(background: Image.Image, presenter_path: Path, logo_path: Path) -> Image.Image:
    canvas = feather_presenter_on_background(background, presenter_path)
    canvas = Image.alpha_composite(canvas, intro_logo_glow_plate())
    canvas = Image.alpha_composite(canvas, logo_square_frame_overlay_at(INTRO_LOGO_CENTER, INTRO_LOGO_FRAME_SIZE))
    canvas = Image.alpha_composite(canvas, logo_art_layer(logo_path, INTRO_LOGO_CENTER, INTRO_LOGO_FRAME_SIZE, INTRO_LOGO_SIZE))
    return canvas


def title_card(section: str) -> Image.Image:
    accent = SECTION_ACCENTS[section]
    background = make_background(section if section == "league" else None)
    panel_rect = (690, 490, 3150, 1670)
    glow = rounded_panel_overlay(
        panel_rect,
        radius=36,
        fill_color=rgba("#101318", 210),
        border_color=rgba("#FFFFFF", 46),
        border_width=2,
        glow_color=rgba(accent, 60),
        shadow_alpha=64,
        shadow_offset_y=18,
        shadow_blur=70,
    )
    background = Image.alpha_composite(background, glow)

    wash = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    wash_draw = ImageDraw.Draw(wash)
    wash_draw.rounded_rectangle(panel_rect, radius=36, fill=rgba(accent, 26))
    wash = wash.filter(ImageFilter.GaussianBlur(24))
    background = Image.alpha_composite(background, wash)

    draw = ImageDraw.Draw(background)
    line_y = 764
    draw.rounded_rectangle((1130, line_y, 2710, line_y + 10), radius=999, fill=rgba(accent))

    title = TITLE_DISPLAY[section]
    subtitle = TITLE_SUBTITLES[section]
    title_font = fit_text(draw, title, "/System/Library/Fonts/Supplemental/Didot.ttc", 176, 1800)
    subtitle_font = fit_text(draw, subtitle, "/System/Library/Fonts/SFNS.ttf", 50, 1700)
    title_box = draw.textbbox((0, 0), title, font=title_font)
    subtitle_box = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    title_x = (CANVAS[0] - (title_box[2] - title_box[0])) // 2
    title_y = 888
    subtitle_x = (CANVAS[0] - (subtitle_box[2] - subtitle_box[0])) // 2
    subtitle_y = 1186
    draw.text((title_x, title_y), title, font=title_font, fill=rgba(COLORS["brand_gold"]))
    draw.text((subtitle_x, subtitle_y), subtitle, font=subtitle_font, fill=rgba(COLORS["brand_ink"], 234))
    return background


def layout_preview(
    background: Image.Image,
    presenter_path: Path,
    app_path: Path,
    pane_rect: tuple[int, int, int, int],
    media_rect: tuple[int, int, int, int],
    pane_accent_hex: str,
    label_overlay: Image.Image | None = None,
) -> Image.Image:
    canvas = background.copy()
    presenter = cover_image(Image.open(presenter_path), (PRESENTER_WIDTH, CANVAS[1] - SAFE_MARGIN * 2))
    presenter_canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    presenter_canvas.alpha_composite(presenter, (SAFE_MARGIN - 20, SAFE_MARGIN))
    canvas = Image.alpha_composite(canvas, presenter_canvas)

    pane = pane_base(pane_rect, 34 if pane_rect == FULL_APP_RECT else 30, pane_accent_hex)
    canvas = Image.alpha_composite(canvas, pane)

    screenshot = cover_image(Image.open(app_path), (media_rect[2] - media_rect[0], media_rect[3] - media_rect[1]))
    rounded_mask = Image.new("L", (media_rect[2] - media_rect[0], media_rect[3] - media_rect[1]), 0)
    ImageDraw.Draw(rounded_mask).rounded_rectangle((0, 0, rounded_mask.width, rounded_mask.height), radius=28, fill=255)
    rounded_screenshot = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    screenshot.putalpha(rounded_mask)
    rounded_screenshot.alpha_composite(screenshot, (media_rect[0], media_rect[1]))
    canvas = Image.alpha_composite(canvas, rounded_screenshot)

    if label_overlay is not None:
        canvas = Image.alpha_composite(canvas, label_overlay)

    return canvas


def make_end_card(background_path: Path) -> Image.Image:
    background = make_background()
    background = Image.alpha_composite(background, outro_logo_glow_plate())
    background = Image.alpha_composite(background, logo_square_frame_overlay_at(OUTRO_LOGO_CENTER, OUTRO_LOGO_FRAME_SIZE))
    background = Image.alpha_composite(background, logo_art_layer(background_path, OUTRO_LOGO_CENTER, OUTRO_LOGO_FRAME_SIZE, OUTRO_LOGO_SIZE))
    return background


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def save_flat_jpg(image: Image.Image, path: Path, background_hex: str = COLORS["launch_black"]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    flattened = Image.new("RGBA", image.size, rgba(background_hex))
    flattened = Image.alpha_composite(flattened, image.convert("RGBA")).convert("RGB")
    flattened.save(path, quality=95)


def build_overview(previews: Iterable[tuple[str, Path]]) -> Image.Image:
    overview = Image.new("RGBA", CANVAS, rgba(COLORS["launch_black"]))
    draw = ImageDraw.Draw(overview)
    title_font = load_font("/System/Library/Fonts/Supplemental/Didot.ttc", 120)
    subtitle_font = load_font("/System/Library/Fonts/SFNS.ttf", 42)
    draw.text((220, 140), "PinProf Promo Style Kit", font=title_font, fill=rgba(COLORS["brand_gold"]))
    draw.text((220, 290), "4K reusable Premiere elements derived from PinProf dark mode", font=subtitle_font, fill=rgba(COLORS["brand_ink"]))

    card_positions = [
        (220, 420, 1800, 1180),
        (2040, 420, 3620, 1180),
        (220, 1260, 1800, 2040),
        (2040, 1260, 3620, 2040),
    ]
    label_font = load_font("/System/Library/Fonts/SFNS.ttf", 38)
    for (label, path), rect in zip(previews, card_positions, strict=False):
        preview = Image.open(path).convert("RGBA").resize((rect[2] - rect[0], rect[3] - rect[1]), Image.Resampling.LANCZOS)
        card = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        ImageDraw.Draw(card).rounded_rectangle(rect, radius=32, fill=rgba("#101318", 220), outline=rgba("#FFFFFF", 38), width=2)
        overview = Image.alpha_composite(overview, card)
        inset = (rect[0] + 22, rect[1] + 22)
        overview.alpha_composite(preview, inset)
        draw.text((rect[0] + 36, rect[3] - 82), label, font=label_font, fill=rgba(COLORS["brand_ink"]))
    return overview


def manifest() -> dict[str, object]:
    return {
        "canvas": {"width": CANVAS[0], "height": CANVAS[1]},
        "safe_margins": {"outer": SAFE_MARGIN, "text": TEXT_SAFE_MARGIN},
        "palette": COLORS,
        "section_accents": SECTION_ACCENTS,
        "layouts": {
            "full_app_view": asdict(LayoutSpec(FULL_APP_RECT, FULL_APP_INNER_RECT, 34)),
            "focus_crop_view": asdict(LayoutSpec(FOCUS_PANE_RECT, FOCUS_INNER_RECT, 30)),
            "phone_frame_view": asdict(LayoutSpec(PHONE_FRAME_RECT, PHONE_SCREEN_RECT, PHONE_FRAME_RADIUS, PHONE_SCREEN_RADIUS)),
            "phone_focus_frame_view": asdict(LayoutSpec(PHONE_FOCUS_FRAME_RECT, PHONE_FOCUS_SCREEN_RECT, PHONE_FRAME_RADIUS, PHONE_SCREEN_RADIUS)),
            "intro_presenter_center": {"x": INTRO_PRESENTER_CENTER[0], "y": INTRO_PRESENTER_CENTER[1], "size": INTRO_PRESENTER_SIZE},
            "presenter_feather_rect": {
                "x1": PRESENTER_FEATHER_RECT[0],
                "y1": PRESENTER_FEATHER_RECT[1],
                "x2": PRESENTER_FEATHER_RECT[2],
                "y2": PRESENTER_FEATHER_RECT[3],
                "radius": PRESENTER_FEATHER_RADIUS,
                "blur": PRESENTER_FEATHER_BLUR,
            },
            "intro_logo_center": {"x": INTRO_LOGO_CENTER[0], "y": INTRO_LOGO_CENTER[1], "size": INTRO_LOGO_SIZE},
            "intro_logo_frame": {"x": INTRO_LOGO_CENTER[0], "y": INTRO_LOGO_CENTER[1], "size": INTRO_LOGO_FRAME_SIZE},
            "outro_logo_center": {"x": OUTRO_LOGO_CENTER[0], "y": OUTRO_LOGO_CENTER[1], "size": OUTRO_LOGO_SIZE},
            "outro_logo_frame": {"x": OUTRO_LOGO_CENTER[0], "y": OUTRO_LOGO_CENTER[1], "size": OUTRO_LOGO_FRAME_SIZE},
            "watermark_logo": {
                "x": WATERMARK_LOGO_CENTER[0],
                "y": WATERMARK_LOGO_CENTER[1],
                "frame_size": WATERMARK_FRAME_SIZE,
                "logo_size": WATERMARK_LOGO_SIZE,
                "feather": WATERMARK_FEATHER,
            },
            "feature_label_rect": FEATURE_LABEL_RECT,
            "focus_phrase_rect": FOCUS_LABEL_RECT,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the PinProf promo style kit assets in 4K.")
    parser.add_argument(
        "--output-dir",
        default="/Users/pillyliu/Documents/Codex/Pinball App/output/promo-style-kit-4k",
        help="Directory where the style kit assets should be written.",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    assets_dir = output_dir / "assets"
    preview_dir = output_dir / "previews"

    intro_dir = Path("/Users/pillyliu/Documents/Codex/Pinball App/Pinball App 2/Pinball App 2/SharedAppSupport/app-intro")
    presenter_path = intro_dir / "professor-headshot.webp"
    promo_logo_path = Path("/Users/pillyliu/Library/CloudStorage/Dropbox/Pinball/PinProf Logo/PinProf Logo Upscaled.png")
    section_screenshot_paths = {
        "library": intro_dir / "library-screenshot.webp",
        "practice": intro_dir / "practice-screenshot.webp",
        "gameroom": intro_dir / "gameroom-screenshot.webp",
        "settings": intro_dir / "settings-screenshot.webp",
        "league": intro_dir / "league-screenshot.webp",
    }

    random.seed(7)

    background_master = make_background()
    background_league = make_background("league")
    save_png(background_master, assets_dir / "background_plate_master_4k.png")
    save_png(background_league, assets_dir / "background_plate_league_4k.png")

    save_png(pane_base(FULL_APP_RECT, 34, COLORS["brand_gold"]), assets_dir / "full_app_pane_base_4k.png")
    save_png(pane_base(FOCUS_PANE_RECT, 30, SECTION_ACCENTS["league"]), assets_dir / "focus_crop_pane_base_4k.png")
    save_png(
        transparent_phone_frame_overlay(
            LayoutSpec(PHONE_FRAME_RECT, PHONE_SCREEN_RECT, PHONE_FRAME_RADIUS, PHONE_SCREEN_RADIUS),
            COLORS["brand_gold"],
        ),
        assets_dir / "phone_frame_overlay_4k.png",
    )
    save_png(
        transparent_window_matte(LayoutSpec(PHONE_FRAME_RECT, PHONE_SCREEN_RECT, PHONE_FRAME_RADIUS, PHONE_SCREEN_RADIUS)),
        assets_dir / "phone_frame_window_matte_4k.png",
    )
    save_png(
        transparent_phone_frame_overlay(
            LayoutSpec(PHONE_FOCUS_FRAME_RECT, PHONE_FOCUS_SCREEN_RECT, PHONE_FRAME_RADIUS, PHONE_SCREEN_RADIUS),
            COLORS["brand_gold"],
        ),
        assets_dir / "phone_focus_frame_overlay_4k.png",
    )
    save_png(
        transparent_window_matte(LayoutSpec(PHONE_FOCUS_FRAME_RECT, PHONE_FOCUS_SCREEN_RECT, PHONE_FRAME_RADIUS, PHONE_SCREEN_RADIUS)),
        assets_dir / "phone_focus_frame_window_matte_4k.png",
    )
    save_png(presenter_feather_matte(), assets_dir / "presenter_feather_matte_left_4k.png")
    save_png(intro_logo_glow_plate(), assets_dir / "intro_logo_glow_plate_4k.png")
    save_png(logo_square_frame_overlay_at(INTRO_LOGO_CENTER, INTRO_LOGO_FRAME_SIZE), assets_dir / "logo_square_frame_overlay_4k.png")
    save_png(logo_square_window_matte(INTRO_LOGO_CENTER, INTRO_LOGO_FRAME_SIZE), assets_dir / "logo_square_frame_window_matte_4k.png")
    save_png(outro_logo_glow_plate(), assets_dir / "outro_logo_glow_plate_4k.png")
    save_png(logo_square_frame_overlay_at(OUTRO_LOGO_CENTER, OUTRO_LOGO_FRAME_SIZE), assets_dir / "outro_logo_square_frame_overlay_4k.png")
    save_png(logo_square_window_matte(OUTRO_LOGO_CENTER, OUTRO_LOGO_FRAME_SIZE), assets_dir / "outro_logo_square_frame_window_matte_4k.png")
    save_png(watermark_logo_overlay(promo_logo_path), assets_dir / "watermark_logo_soft_overlay_4k.png")
    save_png(feature_label_overlay("Read Rulesheet", COLORS["brand_gold"]), assets_dir / "feature_label_sample_read_rulesheet_4k.png")
    save_png(focus_phrase_overlay("View Standings", SECTION_ACCENTS["league"]), assets_dir / "focus_phrase_sample_view_standings_4k.png")

    blank_feature = feature_label_overlay(" ", COLORS["brand_gold"])
    blank_phrase = focus_phrase_overlay(" ", SECTION_ACCENTS["league"])
    save_png(blank_feature, assets_dir / "feature_label_container_blank_4k.png")
    save_png(blank_phrase, assets_dir / "focus_phrase_container_blank_4k.png")

    for section in TITLE_DISPLAY:
        title_image = title_card(section)
        save_png(title_image, assets_dir / f"title_card_{section}_4k.png")
        save_flat_jpg(title_image, assets_dir / f"title_card_{section}_4k_flat.jpg")

    save_png(make_end_card(promo_logo_path), assets_dir / "end_card_4k.png")

    for section, screenshot_path in section_screenshot_paths.items():
        accent = SECTION_ACCENTS[section]
        background = make_background(section if section == "league" else None)
        preview_full = layout_preview(
            background,
            presenter_path,
            screenshot_path,
            FULL_APP_RECT,
            FULL_APP_INNER_RECT,
            accent,
            feature_label_overlay(SECTION_PREVIEW_LABELS[section]["full"], accent),
        )
        preview_focus = layout_preview(
            background,
            presenter_path,
            screenshot_path,
            FOCUS_PANE_RECT,
            FOCUS_INNER_RECT,
            accent,
            focus_phrase_overlay(SECTION_PREVIEW_LABELS[section]["focus"], accent),
        )
        save_png(preview_full, preview_dir / f"preview_full_app_layout_{section}_4k.png")
        save_png(preview_focus, preview_dir / f"preview_focus_crop_layout_{section}_4k.png")

    phone_preview = phone_frame_preview(background_master, section_screenshot_paths["library"], COLORS["brand_gold"])
    save_png(phone_preview, preview_dir / "preview_phone_frame_layout_library_4k.png")
    phone_focus_preview = background_master.copy()
    screenshot = cover_image(Image.open(section_screenshot_paths["library"]), (PHONE_FOCUS_SCREEN_WIDTH, PHONE_FOCUS_SCREEN_HEIGHT))
    phone_focus_preview.alpha_composite(screenshot, (PHONE_FOCUS_SCREEN_RECT[0], PHONE_FOCUS_SCREEN_RECT[1]))
    phone_focus_preview.alpha_composite(
        transparent_phone_frame_overlay(
            LayoutSpec(PHONE_FOCUS_FRAME_RECT, PHONE_FOCUS_SCREEN_RECT, PHONE_FRAME_RADIUS, PHONE_SCREEN_RADIUS),
            COLORS["brand_gold"],
        )
    )
    save_png(phone_focus_preview, preview_dir / "preview_phone_focus_frame_layout_library_4k.png")
    save_png(
        intro_logo_reveal_preview(background_master, presenter_path, promo_logo_path),
        preview_dir / "preview_intro_logo_reveal_4k.png",
    )
    save_png(
        make_end_card(promo_logo_path),
        preview_dir / "preview_outro_logo_endcard_4k.png",
    )
    save_png(
        watermark_preview(background_master, promo_logo_path),
        preview_dir / "preview_watermark_logo_4k.png",
    )
    save_png(
        feather_presenter_on_background(background_master, presenter_path),
        preview_dir / "preview_presenter_feather_left_4k.png",
    )

    overview = build_overview(
        [
            ("Intro Logo Reveal", preview_dir / "preview_intro_logo_reveal_4k.png"),
            ("Outro End Card", preview_dir / "preview_outro_logo_endcard_4k.png"),
            ("Watermark", preview_dir / "preview_watermark_logo_4k.png"),
            ("End Card", assets_dir / "end_card_4k.png"),
        ]
    )
    save_png(overview, preview_dir / "preview_style_kit_overview_4k.png")

    (output_dir / "style_kit_manifest.json").write_text(json.dumps(manifest(), indent=2) + "\n", encoding="utf-8")

    print(output_dir)


if __name__ == "__main__":
    main()
