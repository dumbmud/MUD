# glyphmap_names.py
# Dark glyph sheet. Tiles show glyph name on hover. Click copies the literal.
from fontTools.ttLib import TTFont
from base64 import b64encode
from pathlib import Path
from html import escape

TTF = Path("CozetteVector.ttf")
FONT_SIZE_PX = 24

tt = TTFont(TTF)

def best_cmap(tt):
    cmaps = tt["cmap"].tables
    for fmt in (12, 4):  # prefer full Unicode, then BMP
        for t in cmaps:
            if t.format == fmt and (t.platformID, t.platEncID) in [(3,10),(0,4),(0,6),(0,3),(3,1)]:
                return t.cmap
    return tt["cmap"].getBestCmap()

cmap = best_cmap(tt)              # codepoint -> glyph name
codepoints = sorted(cmap.keys())

font_data = TTF.read_bytes()
data_url = "data:font/ttf;base64," + b64encode(font_data).decode("ascii")

cells = []
for cp in codepoints:
    if 0 <= cp <= 0x10FFFF and not (0xD800 <= cp <= 0xDFFF):
        gname = cmap.get(cp) or f"U+{cp:04X}"
        title = escape(gname)
        cells.append(f'''
<button class="cell" onclick="copyCP(0x{cp:X})" title="{title}">
  <span class="glyph">&#x{cp:X};</span>
</button>''')

html = f"""<!doctype html>
<meta charset="utf-8">
<title>Glyph Map</title>
<style>
@font-face {{
  font-family: "CozetteMap";
  src: url("{data_url}") format("truetype");
}}
:root {{
  --bg: #121212;
  --fg: #d0d0d0;
  --tile: #e5e5e5;
  --tile-hover: #d6d6d6;
  --border: #2a2a2a;
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 10px;
  background: var(--bg);
  color: var(--fg);
  font-family: system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, "Noto Sans", Arial, sans-serif;
}}
.wrap {{
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(40px, 1fr));
  gap: 6px;
}}
.cell {{
  display: flex;
  align-items: center;
  justify-content: center;
  height: 44px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--tile);
  cursor: pointer;
  padding: 0;
  outline: none;
}}
.cell:hover {{ background: var(--tile-hover); }}
.cell:active {{ filter: brightness(0.95); }}
.glyph {{
  font-family: "CozetteMap";
  font-size: {FONT_SIZE_PX}px;
  line-height: 1;
  color: #000;
}}
.header {{
  margin: 0 0 10px 0;
  font-size: 12px;
  color: #9aa0a6;
}}
</style>
<div class="header">Hover shows glyph name. Click copies the character.</div>
<div class="wrap">
{''.join(cells)}
</div>
<script>
async function copy(txt) {{
  try {{ await navigator.clipboard.writeText(txt); }}
  catch(e) {{
    const ta = document.createElement('textarea');
    ta.value = txt; document.body.appendChild(ta);
    ta.select(); document.execCommand('copy'); ta.remove();
  }}
}}
function copyCP(cp) {{
  copy(String.fromCodePoint(cp));
}}
</script>
"""
Path("glyphmap.html").write_text(html, encoding="utf-8")
print("Wrote glyphmap.html")
