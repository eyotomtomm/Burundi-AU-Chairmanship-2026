"""Rendered 1200x630 social preview cards for shared content.

Two reasons this exists rather than pointing ``og:image`` straight at the
content photo: every image in this project is stored as WebP, which WhatsApp
and LinkedIn refuse to render in a link preview, and a bare cropped photo
makes a dull card. Here the photo is composited under a scrim with the
content type, the headline and the brand strip, and handed out as a plain
JPEG that every chat app understands.
"""
from __future__ import annotations

import io
import os
from functools import lru_cache

from django.conf import settings
from PIL import Image, ImageDraw, ImageFont

CARD_W, CARD_H = 1200, 630
PAD = 72

GREEN = (64, 152, 67)
GREEN_DEEP = (11, 38, 18)
RED = (225, 28, 35)
GOLD = (252, 209, 22)
WHITE = (255, 255, 255)

# Ordered by preference; Pillow's bundled default is the last-resort fallback
# so a container with no fonts installed still renders a readable card.
_FONT_PATHS = (
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
)


@lru_cache(maxsize=16)
def _font(size: int) -> ImageFont.FreeTypeFont:
    for path in _FONT_PATHS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


@lru_cache(maxsize=1)
def _logo() -> Image.Image | None:
    path = os.path.join(settings.BASE_DIR, 'static', 'img', 'b4africa_icon.png')
    if not os.path.exists(path):
        return None
    logo = Image.open(path).convert('RGBA')
    logo.thumbnail((110, 110), Image.LANCZOS)
    return logo


def _cover(img: Image.Image) -> Image.Image:
    """Scale and centre-crop to exactly the card size."""
    scale = max(CARD_W / img.width, CARD_H / img.height)
    resized = img.resize(
        (max(1, round(img.width * scale)), max(1, round(img.height * scale))),
        Image.LANCZOS,
    )
    left = (resized.width - CARD_W) // 2
    top = (resized.height - CARD_H) // 2
    return resized.crop((left, top, left + CARD_W, top + CARD_H))


def _backdrop(photo_bytes: bytes | None) -> Image.Image:
    if photo_bytes:
        try:
            with Image.open(io.BytesIO(photo_bytes)) as src:
                return _cover(src.convert('RGB'))
        except Exception:
            pass  # Unreadable or unsupported photo — fall through to the brand fill.
    base = Image.new('RGB', (CARD_W, CARD_H), GREEN_DEEP)
    draw = ImageDraw.Draw(base)
    for y in range(CARD_H):  # Diagonal-ish wash from deep green to brand green.
        t = y / CARD_H
        draw.line(
            [(0, y), (CARD_W, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(GREEN_DEEP, GREEN)),
        )
    return base


def _scrim(base: Image.Image) -> Image.Image:
    """Darken the photo bottom-up so white text always clears contrast."""
    mask = Image.new('L', (1, CARD_H))
    px = mask.load()
    for y in range(CARD_H):
        t = y / CARD_H
        # The photo keeps its punch down to a third of the card, then a
        # smoothstep ramp drops a near-solid bed under the headline.
        k = min(1.0, max(0.0, (t - 0.30) / 0.32))
        px[0, y] = round(255 * (0.06 + 0.86 * (k * k * (3 - 2 * k))))
    veil = Image.new('RGB', (CARD_W, CARD_H), GREEN_DEEP)
    return Image.composite(veil, base, mask.resize((CARD_W, CARD_H)))


def _tracked(draw, xy, text, font, fill, tracking=0):
    """Draw text with letter spacing — PIL has no tracking of its own."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += font.getlength(ch) + tracking
    return x


def _wrap(text: str, font, max_width: float, max_lines: int) -> list[str]:
    words, lines, line = text.split(), [], ''
    for word in words:
        probe = f'{line} {word}'.strip()
        if font.getlength(probe) <= max_width or not line:
            line = probe
            continue
        lines.append(line)
        line = word
        if len(lines) == max_lines:
            break
    if line and len(lines) < max_lines:
        lines.append(line)
    if len(lines) == max_lines and (len(' '.join(lines).split()) < len(words)):
        last = lines[-1]
        while last and font.getlength(last + '…') > max_width:
            last = last[:-1].rstrip()
        lines[-1] = last + '…'
    return lines


def render(kind_label: str, title: str, footer: str, photo_bytes: bytes | None) -> bytes:
    """Compose one card and return it as JPEG bytes."""
    card = _scrim(_backdrop(photo_bytes))
    draw = ImageDraw.Draw(card)

    title_font = _font(58)
    label_font = _font(24)
    foot_font = _font(22)

    lines = _wrap(title, title_font, CARD_W - 2 * PAD, 3)
    line_h = 72
    baseline = CARD_H - 96 - len(lines) * line_h

    # Content type, above the headline, on a gold rule.
    draw.rectangle([PAD, baseline - 52, PAD + 56, baseline - 46], fill=GOLD)
    _tracked(draw, (PAD + 76, baseline - 62), kind_label.upper(), label_font, GOLD, 3)

    y = baseline
    for line in lines:
        draw.text((PAD, y), line, font=title_font, fill=WHITE)
        y += line_h

    _tracked(draw, (PAD, y + 14), footer.upper(), foot_font, (226, 236, 226), 2.5)

    logo = _logo()
    if logo is not None:
        card.paste(logo, (CARD_W - PAD - logo.width, PAD - 20), logo)

    # Burundi flag stripe along the bottom edge.
    for i, colour in enumerate((GREEN, WHITE, RED)):
        draw.rectangle(
            [i * CARD_W // 3, CARD_H - 10, (i + 1) * CARD_W // 3, CARD_H], fill=colour
        )

    out = io.BytesIO()
    card.save(out, format='JPEG', quality=88, optimize=True, progressive=True)
    return out.getvalue()
