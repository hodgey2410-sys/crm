#!/usr/bin/env bash
# after merging upstream
# ./scripts/rebrand-georgebot.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 - << 'PY'
from __future__ import annotations

import base64
import re
import struct
from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent if "__file__" in dir() else Path.cwd()
SRC = ROOT / "branding/logo.png"
PUBLIC = ROOT / "apps/app/public"
DARK = (8, 6, 0, 255)
CLEAR = (0, 0, 0, 0)

if not SRC.is_file():
	raise SystemExit(f"missing logo: {SRC}")

src = Image.open(SRC).convert("RGBA")


def fit_square(img: Image.Image, size: int, background, pad_ratio: float) -> Image.Image:
	canvas = Image.new("RGBA", (size, size), background)
	inner = max(1, int(size * (1 - pad_ratio * 2)))
	fitted = img.copy()
	fitted.thumbnail((inner, inner), Image.Resampling.LANCZOS)
	x = (size - fitted.width) // 2
	y = (size - fitted.height) // 2
	canvas.paste(fitted, (x, y), fitted)
	return canvas


def png_bytes(img: Image.Image) -> bytes:
	buf = BytesIO()
	img.save(buf, format="PNG", optimize=True)
	return buf.getvalue()


def write_ico(path: Path, images: list[Image.Image]) -> None:
	pngs = [png_bytes(im) for im in images]
	count = len(pngs)
	offset = 6 + 16 * count
	header = struct.pack("<HHH", 0, 1, count)
	entries = b""
	payload = b""
	for im, data in zip(images, pngs):
		w = 0 if im.width >= 256 else im.width
		h = 0 if im.height >= 256 else im.height
		entries += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(data), offset)
		payload += data
		offset += len(data)
	path.write_bytes(header + entries + payload)


favicon_96 = fit_square(src, 96, CLEAR, 0.04)
apple = fit_square(src, 180, DARK, 0.08)
manifest_192 = fit_square(src, 192, DARK, 0.12)
manifest_512 = fit_square(src, 512, DARK, 0.12)
logo_256 = fit_square(src, 256, CLEAR, 0.02)
svg_embed = fit_square(src, 192, CLEAR, 0.04)
ico16 = fit_square(src, 16, CLEAR, 0.02)
ico32 = fit_square(src, 32, CLEAR, 0.02)
ico48 = fit_square(src, 48, CLEAR, 0.02)

PUBLIC.mkdir(parents=True, exist_ok=True)
(PUBLIC / "favicon-96x96.png").write_bytes(png_bytes(favicon_96))
(PUBLIC / "apple-touch-icon.png").write_bytes(png_bytes(apple))
(PUBLIC / "web-app-manifest-192x192.png").write_bytes(png_bytes(manifest_192))
(PUBLIC / "web-app-manifest-512x512.png").write_bytes(png_bytes(manifest_512))
write_ico(PUBLIC / "favicon.ico", [ico16, ico32, ico48])
(ROOT / "apps/app/app/favicon.ico").write_bytes((PUBLIC / "favicon.ico").read_bytes())

svg_b64 = base64.b64encode(png_bytes(svg_embed)).decode("ascii")
(PUBLIC / "favicon.svg").write_text(
	'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
	'width="192" height="192" viewBox="0 0 192 192">\n'
	f'<image width="192" height="192" href="data:image/png;base64,{svg_b64}"/>\n'
	"</svg>\n",
	encoding="utf-8",
)

logo_b64 = base64.b64encode(png_bytes(logo_256)).decode("ascii")
(ROOT / "packages/ui/src/components/logo.tsx").write_text(
	"import type * as React from \"react\";\n"
	"\n"
	"const Logo = (props: React.SVGProps<SVGSVGElement>) => (\n"
	"	<svg\n"
	"		xmlns=\"http://www.w3.org/2000/svg\"\n"
	"		width={512}\n"
	"		height={512}\n"
	"		viewBox=\"0 0 256 256\"\n"
	"		fill=\"none\"\n"
	"		aria-label=\"GeorgeBot CRM Logo\"\n"
	"		{...props}\n"
	"	>\n"
	f'		<image href="data:image/png;base64,{logo_b64}" width={{256}} height={{256}} />\n'
	"	</svg>\n"
	");\n"
	"export default Logo;\n",
	encoding="utf-8",
)

auth = ROOT / "apps/app/components/auth-shell.tsx"
auth_text = auth.read_text(encoding="utf-8")
auth_text = re.sub(
	r"\n\t\t\t\t<p className=\"relative font-mono text-xs/4 text-muted-foreground\">\n"
	r"\t\t\t\t\tMade with love by\{\" \"\}\n"
	r"\t\t\t\t\t<a\n"
	r"[\s\S]*?"
	r"\t\t\t\t\t</a>\n"
	r"\t\t\t\t</p>\n",
	"\n",
	auth_text,
	count=1,
)
auth.write_text(auth_text, encoding="utf-8")

layout = ROOT / "apps/app/app/layout.tsx"
layout_text = layout.read_text(encoding="utf-8")
layout_text = re.sub(
	r"title: \{\n\t\tdefault: \".*\",\n\t\ttemplate: \".*\",\n\t\},",
	'title: {\n\t\tdefault: "GeorgeBot CRM",\n\t\ttemplate: "%s · GeorgeBot CRM",\n\t},',
	layout_text,
	count=1,
)
layout_text = re.sub(
	r'description: ".*",',
	'description: "Customer Relationship Management for GeorgeBot CRM",',
	layout_text,
	count=1,
)
layout.write_text(layout_text, encoding="utf-8")

manifest = ROOT / "apps/app/public/site.webmanifest"
manifest_text = manifest.read_text(encoding="utf-8")
manifest_text = re.sub(r'"name": ".*"', '"name": "GeorgeBot CRM"', manifest_text, count=1)
manifest_text = re.sub(
	r'"short_name": ".*"',
	'"short_name": "GeorgeBot CRM"',
	manifest_text,
	count=1,
)
manifest.write_text(manifest_text, encoding="utf-8")

seed = ROOT / "packages/db/prisma/seed.ts"
seed_text = seed.read_text(encoding="utf-8")
seed_text = re.sub(
	r"async function main\(\) \{[\s\S]*?\n\}",
	"async function main() {\n\treturn;\n}",
	seed_text,
	count=1,
)
seed.write_text(seed_text, encoding="utf-8")

print("GeorgeBot CRM branding overlay applied.")
PY
