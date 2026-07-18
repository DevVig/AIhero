# README images

Curated, web-sized screenshots used by the root [README.md](../../README.md).

Regenerate the full offscreen set, then refresh these:

```bash
swift run AIhero --render documentation/reference/screenshots

sips -Z 1400 documentation/reference/screenshots/companion.png --out docs/images/companion.png
sips -Z 1400 documentation/reference/screenshots/gallery.png    --out docs/images/gallery.png
sips -Z 1400 documentation/reference/screenshots/boxes.png      --out docs/images/boxes.png
sips -Z 1400 documentation/reference/screenshots/chamber.png    --out docs/images/chamber.png
sips -s format jpeg -s formatOptions 80 -Z 1200 \
  documentation/reference/screenshots/dossier.png --out docs/images/dossier.jpg

cp docs/images/gallery.png docs/images/hero-roster.png
```

Full QA surfaces (including settings / forge control placeholders) live in
[`documentation/reference/screenshots/`](../../documentation/reference/screenshots/).
