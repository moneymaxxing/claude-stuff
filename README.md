# Thumbnail Headline Generator

Takes a YouTube thumbnail image and generates 4-5 variants with different
headlines, in the same visual style as the original.

## How it works

1. Sends your thumbnail to Claude (vision) to read the current headline text
   and detect where it sits, its background box color (if any), and its text
   color/style.
2. Asks Claude to write 4-5 alternate headlines using different high-CTR
   angles (curiosity, bold claim, number, question, shock).
3. Renders each headline back onto a copy of your original image: covers the
   old text (with a matching solid box, or a blurred/darkened patch of the
   photo if there's no box) and draws the new headline centered in the same
   spot, bold and outlined for readability.

## Setup

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
```

## Usage

```bash
python thumbnail_headlines/generate.py my_thumbnail.jpg --output-dir out --count 5
```

Outputs `out/variant_1_<slug>.jpg` ... `out/variant_5_<slug>.jpg`.

## Notes

- Works best on thumbnails with clear, legible headline text already on them
  (common creator style: bold caps text on a solid-color banner or box).
- If your thumbnail's text sits directly on the photo (no box), the tool
  blurs and darkens that region before placing new text — results will vary
  more with busy backgrounds.
- For best-looking text, install a condensed/impact-style bold font (e.g.
  Bebas Neue, Anton, Archivo Black) and add its path to the front of
  `FONT_CANDIDATES` in `thumbnail_headlines/generate.py`.
