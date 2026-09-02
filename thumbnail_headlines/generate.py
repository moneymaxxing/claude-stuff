#!/usr/bin/env python3
"""
Generate alternate headline versions of a YouTube thumbnail.

Given a thumbnail image, this tool:
  1. Asks Claude (vision) to read the thumbnail's current headline text and
     describe where it sits and how it's styled (position, box color, text
     color).
  2. Asks Claude to write 4-5 alternate headlines in the same spirit but
     with different angles (curiosity, bold claim, number, question, shock).
  3. Renders each alternate headline back onto a copy of the original image,
     covering the old text and drawing the new headline in a similar style.

Usage:
    python generate.py thumbnail.jpg --output-dir out --count 5

Requires ANTHROPIC_API_KEY in the environment (or pass --api-key).
"""
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

MODEL = "claude-sonnet-5"

# Candidate bold/condensed fonts to try, in order of preference. Any of
# these that exist on the machine will be used; falls back to whatever
# PIL can find.
FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/mnt/skills/examples/canvas-design/canvas-fonts/BigShoulders-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "C:\\Windows\\Fonts\\arialbd.ttf",
]


@dataclass
class ThumbnailAnalysis:
    topic: str
    original_headline: str | None
    bbox: tuple[float, float, float, float]  # x0, y0, x1, y1 as fractions of image size
    has_solid_box: bool
    box_color: str | None
    text_color: str
    style_notes: str


def _client(api_key: str | None):
    import anthropic

    return anthropic.Anthropic(api_key=api_key or os.environ.get("ANTHROPIC_API_KEY"))


def _image_block(image_path: Path) -> dict:
    media_type = mimetypes.guess_type(image_path.name)[0] or "image/jpeg"
    data = base64.standard_b64encode(image_path.read_bytes()).decode("utf-8")
    return {
        "type": "image",
        "source": {"type": "base64", "media_type": media_type, "data": data},
    }


def _extract_json(text: str) -> dict:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise ValueError(f"No JSON object found in model response:\n{text}")
    return json.loads(match.group(0))


def analyze_thumbnail(client, image_path: Path) -> ThumbnailAnalysis:
    prompt = (
        "You are looking at a YouTube thumbnail. Reply with ONLY a JSON object "
        "(no prose, no markdown fences) with these keys:\n"
        '  "topic": short description of what the thumbnail is about\n'
        '  "original_headline": the exact headline/caption text overlaid on the image, '
        "or null if there is no text\n"
        '  "bbox": [x0, y0, x1, y1] bounding box of the headline text as fractions of the '
        "image width/height (0.0 to 1.0), tightly around the text (or its background box "
        "if it has one)\n"
        '  "has_solid_box": true if the text sits on a solid/near-solid color background '
        "box or banner, false if it sits directly on the photo\n"
        '  "box_color": hex color of that background box, or null if has_solid_box is false\n'
        '  "text_color": hex color of the headline text itself\n'
        '  "style_notes": brief notes on font weight/case/style (e.g. "bold condensed '
        'all-caps yellow text with black outline")\n'
    )
    response = client.messages.create(
        model=MODEL,
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": [_image_block(image_path), {"type": "text", "text": prompt}],
            }
        ],
    )
    data = _extract_json(response.content[0].text)
    x0, y0, x1, y1 = data.get("bbox") or [0.05, 0.72, 0.95, 0.95]
    return ThumbnailAnalysis(
        topic=data.get("topic", "").strip(),
        original_headline=(data.get("original_headline") or None),
        bbox=(float(x0), float(y0), float(x1), float(y1)),
        has_solid_box=bool(data.get("has_solid_box")),
        box_color=data.get("box_color"),
        text_color=data.get("text_color") or "#FFFFFF",
        style_notes=data.get("style_notes", ""),
    )


def generate_headlines(client, analysis: ThumbnailAnalysis, count: int) -> list[str]:
    prompt = (
        f"A YouTube thumbnail is about: {analysis.topic or 'unknown topic'}.\n"
        f"Its current headline text is: {analysis.original_headline or '(none)'}\n"
        f"Style notes: {analysis.style_notes or 'n/a'}\n\n"
        f"Write {count} alternate headlines for this same thumbnail, each using a "
        "different high-CTR angle (e.g. curiosity gap, bold claim, number/stat, "
        "question, shock/controversy). Keep each headline SHORT (2-6 words), punchy, "
        "and in the same spirit/tone as the original if one exists. Reply with ONLY a "
        'JSON object: {"headlines": ["...", "...", ...]} — no prose, no markdown fences.'
    )
    response = client.messages.create(
        model=MODEL,
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}],
    )
    data = _extract_json(response.content[0].text)
    headlines = [h.strip() for h in data.get("headlines", []) if h and h.strip()]
    return headlines[:count]


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default(size)


def _fit_font(draw: ImageDraw.ImageDraw, text: str, box_w: int, box_h: int):
    size = box_h
    while size > 8:
        font = _load_font(size)
        lines = _wrap_text(draw, text, font, box_w)
        line_h = draw.textbbox((0, 0), "Hg", font=font)[3] + 4
        total_h = line_h * len(lines)
        max_w = max(draw.textbbox((0, 0), line, font=font)[2] for line in lines)
        if total_h <= box_h and max_w <= box_w:
            return font, lines, line_h
        size -= 2
    font = _load_font(16)
    return font, _wrap_text(draw, text, font, box_w), draw.textbbox((0, 0), "Hg", font=font)[3] + 4


def _wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    words = text.split()
    lines, current = [], ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textbbox((0, 0), candidate, font=font)[2] <= max_w or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def render_variant(image: Image.Image, analysis: ThumbnailAnalysis, headline: str) -> Image.Image:
    img = image.convert("RGB").copy()
    w, h = img.size
    x0, y0, x1, y1 = analysis.bbox
    box = (int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h))
    pad = int(0.02 * h)
    box = (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, w), min(box[3] + pad, h))
    box_w, box_h = box[2] - box[0], box[3] - box[1]

    draw = ImageDraw.Draw(img)
    if analysis.has_solid_box and analysis.box_color:
        draw.rectangle(box, fill=analysis.box_color)
    else:
        region = img.crop(box).filter(ImageFilter.GaussianBlur(radius=max(box_h // 12, 4)))
        overlay = Image.new("RGB", region.size, (0, 0, 0))
        region = Image.blend(region, overlay, alpha=0.45)
        img.paste(region, box)

    text = headline.upper()
    font, lines, line_h = _fit_font(draw, text, int(box_w * 0.92), int(box_h * 0.9))
    total_h = line_h * len(lines)
    ty = box[1] + (box_h - total_h) // 2
    stroke_color = "#000000" if analysis.text_color.upper() != "#000000" else "#FFFFFF"
    for line in lines:
        tw = draw.textbbox((0, 0), line, font=font)[2]
        tx = box[0] + (box_w - tw) // 2
        draw.text(
            (tx, ty),
            line,
            font=font,
            fill=analysis.text_color,
            stroke_width=max(box_h // 40, 2),
            stroke_fill=stroke_color,
        )
        ty += line_h
    return img


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("image", type=Path, help="Path to the source thumbnail image")
    parser.add_argument("--output-dir", type=Path, default=Path("thumbnail_variants"))
    parser.add_argument("--count", type=int, default=5, help="Number of headline variants (4-5 recommended)")
    parser.add_argument("--api-key", default=None, help="Anthropic API key (defaults to ANTHROPIC_API_KEY env var)")
    args = parser.parse_args()

    if not args.image.exists():
        sys.exit(f"Image not found: {args.image}")

    client = _client(args.api_key)

    print(f"Analyzing thumbnail: {args.image}")
    analysis = analyze_thumbnail(client, args.image)
    print(f"  topic: {analysis.topic}")
    print(f"  original headline: {analysis.original_headline}")
    print(f"  style: {analysis.style_notes}")

    print(f"Generating {args.count} headline variants...")
    headlines = generate_headlines(client, analysis, args.count)
    if not headlines:
        sys.exit("Model returned no headlines.")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    image = Image.open(args.image)
    for i, headline in enumerate(headlines, start=1):
        variant = render_variant(image, analysis, headline)
        out_path = args.output_dir / f"variant_{i}_{_slugify(headline)}.jpg"
        variant.save(out_path, quality=92)
        print(f"  [{i}] \"{headline}\" -> {out_path}")

    print("Done.")


def _slugify(text: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", text.strip().lower()).strip("-")
    return slug[:40] or "headline"


if __name__ == "__main__":
    main()
