# Renders a Markdown file the way VS Code's dark Markdown preview shows it
# (headings with rules, tables, task lists, diff code blocks, **bold** and
# `code`), then cuts it into two 1024x768 panels side by side (2080x768).
# Usage: python md_preview.py <file.md> <out.png> [second panel start y]
import sys, re
from PIL import Image, ImageDraw, ImageFont

F = "C:/Windows/Fonts/"
def font(name, size): return ImageFont.truetype(F + name, size)
BODY = font("segoeui.ttf", 17); BOLD = font("segoeuib.ttf", 17)
H1 = font("seguisb.ttf", 30); H2 = font("seguisb.ttf", 24); H3 = font("seguisb.ttf", 19)
MONO = font("consola.ttf", 15)
BG = (31, 31, 31); TXT = (204, 204, 204); HEAD = (231, 231, 231); RULE = (60, 60, 60)
CODEBG = (43, 43, 43); TH = (42, 45, 46); LINK = (79, 193, 255)
ADD = (35, 70, 40); DEL = (85, 35, 35); ADDT = (150, 230, 160); DELT = (240, 150, 150)
W = 1024; PAD = 40; IW = W - PAD * 2

def segments(text):
    out = []
    for part in re.split(r"(\*\*[^*]+\*\*|`[^`]+`)", text):
        if not part: continue
        if part.startswith("**"): out.append((part[2:-2], BOLD, TXT, False))
        elif part.startswith("`"): out.append((part[1:-1], MONO, (214, 157, 133), True))
        else: out.append((part, BODY, TXT, False))
    return out

def layout_inline(text, width):
    # word-wrap segments; returns lines of [(x, word, font, colour, code)]
    lines, line, x = [], [], 0
    d = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    for s, f, c, code in segments(text):
        words = [s] if code else re.split(r"(\s+)", s)
        for w in words:
            if w == "": continue
            ww = d.textlength(w, font=f) + (8 if code else 0)
            if x + ww > width and w.strip() and line:
                lines.append(line); line, x = [], 0
                if not w.strip(): continue
            line.append((x, w, f, c, code)); x += ww
    if line: lines.append(line)
    return lines

def draw_inline(d, x0, y, lines, lh=26):
    for ln in lines:
        for x, w, f, c, code in ln:
            if code:
                tw = d.textlength(w, font=f)
                d.rounded_rectangle([x0 + x, y + 2, x0 + x + tw + 8, y + lh - 3], 4, fill=CODEBG)
                d.text((x0 + x + 4, y + 5), w, font=f, fill=c)
            else:
                d.text((x0 + x, y + 2), w, font=f, fill=c)
        y += lh
    return y

def render(md):
    img = Image.new("RGB", (W, 4000), BG); d = ImageDraw.Draw(img)
    y = 30
    rows = md.splitlines(); i = 0
    while i < len(rows):
        r = rows[i]
        if r.startswith("# "):
            d.text((PAD, y), r[2:], font=H1, fill=HEAD); y += 44
            d.line([PAD, y, W - PAD, y], fill=RULE, width=1); y += 16
        elif r.startswith("## "):
            y += 10; HEADS[r[3:]] = y - 14; d.text((PAD, y), r[3:], font=H2, fill=HEAD); y += 36
            d.line([PAD, y, W - PAD, y], fill=RULE, width=1); y += 12
        elif r.startswith("### "):
            y += 6; d.text((PAD, y), r[4:], font=H3, fill=HEAD); y += 32
        elif r.strip().startswith("```"):
            ind = len(r) - len(r.lstrip())
            i += 1; code = []
            while i < len(rows) and not rows[i].strip().startswith("```"):
                code.append(rows[i][ind:]); i += 1
            h = len(code) * 21 + 20
            x0 = PAD + (24 if ind else 0)
            d.rounded_rectangle([x0, y, W - PAD, y + h], 6, fill=CODEBG)
            cy = y + 10
            for ln in code:
                if ln.startswith("+"): d.rectangle([x0, cy, W - PAD, cy + 20], fill=ADD); col = ADDT
                elif ln.startswith("-"): d.rectangle([x0, cy, W - PAD, cy + 20], fill=DEL); col = DELT
                else: col = TXT
                d.text((x0 + 14, cy + 1), ln, font=MONO, fill=col); cy += 21
            y += h + 14
        elif r.startswith("|"):
            tbl = []
            while i < len(rows) and rows[i].startswith("|"):
                cells = [c.strip() for c in rows[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", c) for c in cells): tbl.append(cells)
                i += 1
            i -= 1
            n = len(tbl[0])
            widths = [0] * n
            for row in tbl:
                for k, c in enumerate(row):
                    plain = re.sub(r"\*\*|`", "", c)
                    widths[k] = max(widths[k], d.textlength(plain, font=BOLD) + 28)
            scale = min(1.0, IW / sum(widths))
            widths = [w * scale for w in widths]
            for ri, row in enumerate(tbl):
                x = PAD
                laid = [layout_inline(c, widths[k] - 22) for k, c in enumerate(row)]
                rh = 32 if ri == 0 else max(1, max(len(l) for l in laid)) * 24 + 8
                if ri == 0: d.rectangle([PAD, y, PAD + sum(widths), y + rh], fill=TH)
                for k, c in enumerate(row):
                    d.rectangle([x, y, x + widths[k], y + rh], outline=RULE)
                    if ri == 0: d.text((x + 12, y + 5), c, font=BOLD, fill=HEAD)
                    else: draw_inline(d, x + 12, y + 2, laid[k], 24)
                    x += widths[k]
                y += rh
            y += 16
        elif re.match(r"\s*- \[ \] ", r) or r.startswith("- "):
            task = "[ ]" in r[:6]
            text = re.sub(r"^\s*- (\[ \] )?", "", r)
            bx = PAD + 8
            if task:
                d.rounded_rectangle([bx, y + 7, bx + 14, y + 21], 3, outline=TXT, width=1)
            else:
                d.ellipse([bx + 4, y + 11, bx + 10, y + 17], fill=TXT)
            y = draw_inline(d, PAD + 32, y, layout_inline(text, IW - 32)) + 4
        elif r.strip() == "":
            y += 6
        else:
            y = draw_inline(d, PAD, y, layout_inline(r.strip(), IW)) + 10
        i += 1
    return img.crop((0, 0, W, max(y + 30, 768)))

HEADS = {}
src, out = sys.argv[1], sys.argv[2]
full = render(open(src, encoding="utf-8").read())
start2 = HEADS.get(sys.argv[3], 708) if len(sys.argv) > 3 else 708
def panel(top):
    p = Image.new("RGB", (W, 768), BG)
    p.paste(full.crop((0, top, W, min(top + 768, full.height))), (0, 0))
    return p
pair = Image.new("RGB", (W * 2 + 32, 768), (10, 14, 24))
pair.paste(panel(0), (0, 0)); pair.paste(panel(start2), (W + 32, 0))
pair.save(out)
print(out, full.height)
