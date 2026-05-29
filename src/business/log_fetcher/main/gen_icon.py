"""
Log Fetcher icon generator — Pillow only, no cairosvg required.
Produces log_fetcher_icon.png (512x512) and log_fetcher.ico (multi-size).
"""
from PIL import Image, ImageDraw, ImageFont
import math, os

SIZE = 512
M    = 4          # supersampling factor → draw at 2048, downscale to 512
S    = SIZE * M

OUT_PNG = 'log_fetcher_icon.png'
OUT_ICO = 'log_fetcher.ico'

# ── colour palette (R,G,B) ───────────────────────────────
BG       = (13,  17,  23)
CARD     = (22,  27,  34)
BORDER   = (48,  54,  61)
GREEN    = (35, 134,  54)
GREEN_LT = (63, 185,  80)
BLUE_LT  = (56, 139, 253)
MUTED    = (139,148,158)
TEXT_PRI = (230,237,243)

def c(rgb, a=255):
    """Return an RGBA tuple."""
    return (rgb[0], rgb[1], rgb[2], a)

def s(v):
    """Scale logical pixel → supersampled pixel."""
    return int(round(v * M))

def sp(pts):
    """Scale a list of (x,y) points."""
    return [(s(x), s(y)) for x, y in pts]

# ── canvas ───────────────────────────────────────────────
img  = Image.new('RGBA', (S, S), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

CORNER = s(96)

# rounded background
draw.rounded_rectangle([0, 0, S-1, S-1], radius=CORNER, fill=c(BG))

# ── subtle grid ──────────────────────────────────────────
for gx in range(64, 512, 128):
    draw.line([(s(gx), 0), (s(gx), S)], fill=c(GREEN, 18), width=M)
for gy in range(64, 512, 128):
    draw.line([(0, s(gy)), (S, s(gy))], fill=c(GREEN, 18), width=M)

# ── helper: draw a thick arc as a chain of filled circles ─
def thick_arc(cx, cy, rx, ry, a0, a1, colour, dot_r=4, step=2):
    for deg in range(a0, a1+1, step):
        ang = math.radians(deg)
        x = cx + rx * math.cos(ang)
        y = cy + ry * math.sin(ang)
        r = dot_r
        draw.ellipse([s(x-r), s(y-r), s(x+r), s(y+r)], fill=colour)

# ── satellite dish ────────────────────────────────────────
DCX, DCY = 185, 215       # dish centre
DRX, DRY = 105, 78        # dish radii

# bowl lower arc  (180° → 360° = bottom half of ellipse)
thick_arc(DCX, DCY, DRX, DRY, 0, 180, c(GREEN), dot_r=5, step=2)

# rim upper arc (subtle)
thick_arc(DCX, DCY, DRX, DRY*0.28, 180, 360, c(GREEN, 80), dot_r=3, step=3)

# pole
draw.line([s(DCX), s(DCY+DRY-4), s(DCX), s(388)],
          fill=c(BORDER), width=s(10))

# base mount
draw.rounded_rectangle([s(DCX-50), s(384), s(DCX+50), s(404)],
                        radius=s(7), fill=c(BORDER))

# focal arm + point
FX, FY = 278, 162
draw.line([s(DCX), s(DCY), s(FX), s(FY)],
          fill=c(GREEN_LT, 150), width=s(4))
draw.ellipse([s(FX-13), s(FY-13), s(FX+13), s(FY+13)], fill=c(GREEN))
draw.ellipse([s(FX-7),  s(FY-7),  s(FX+7),  s(FY+7)],  fill=c(GREEN_LT))

# ── signal arcs (right side of dish) ─────────────────────
ACX, ACY = 355, 215
for radius, alpha in [(72, 55), (115, 95), (158, 140)]:
    thick_arc(ACX, ACY, radius, radius, -150, -30,
              c(BLUE_LT, alpha), dot_r=5, step=3)

# activity dot
DOT_X = ACX + int(158 * math.cos(math.radians(-90)))
DOT_Y = ACY + int(158 * math.sin(math.radians(-90)))
draw.ellipse([s(DOT_X-13), s(DOT_Y-13), s(DOT_X+13), s(DOT_Y+13)],
             fill=c(GREEN_LT))
draw.ellipse([s(DOT_X-22), s(DOT_Y-22), s(DOT_X+22), s(DOT_Y+22)],
             fill=c(GREEN_LT, 40))

# ── download arrow ────────────────────────────────────────
AX, ATOP, ABOT = 408, 295, 438
draw.line([s(AX), s(ATOP), s(AX), s(ABOT)],
          fill=c(GREEN_LT), width=s(16))
draw.polygon(sp([(AX-30, ABOT-8), (AX, ABOT+33), (AX+30, ABOT-8)]),
             fill=c(GREEN_LT))

# ── log file card ─────────────────────────────────────────
CX, CY, CW, CH = 285, 375, 185, 108
draw.rounded_rectangle([s(CX), s(CY), s(CX+CW), s(CY+CH)],
                        radius=s(10), fill=c(CARD), outline=c(BORDER), width=s(2))

# corner fold
FOLD = 30
draw.polygon(sp([(CX+CW-FOLD, CY), (CX+CW, CY+FOLD), (CX+CW, CY)]),
             fill=c(BORDER))

# log lines
lines = [
    (CX+16, CY+18,  75, GREEN_LT, 210),
    (CX+16, CY+38, 125, MUTED,    165),
    (CX+16, CY+56,  65, MUTED,    140),
    (CX+16, CY+74, 105, MUTED,    110),
]
for lx, ly, lw, col, a in lines:
    draw.rounded_rectangle([s(lx), s(ly), s(lx+lw), s(ly+9)],
                            radius=s(4), fill=c(col, a))

# ── bottom label bar ─────────────────────────────────────
BAR = 66
draw.rounded_rectangle([0, s(SIZE-BAR), S-1, S-1],
                        radius=CORNER, fill=(10, 14, 20, 210))

try:
    font = ImageFont.truetype(
        '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf', s(20))
except Exception:
    font = ImageFont.load_default()

label = 'LOG FETCHER'
bbox  = draw.textbbox((0, 0), label, font=font)
tw    = bbox[2] - bbox[0]
tx    = (S - tw) // 2
ty    = s(SIZE - BAR + 16)
draw.text((tx, ty), label, fill=c(TEXT_PRI), font=font)

# ── border ring ──────────────────────────────────────────
draw.rounded_rectangle([s(2), s(2), s(510), s(510)],
                        radius=CORNER - s(2),
                        outline=c(GREEN, 140), width=s(3))

# ── downsample (anti-alias) ───────────────────────────────
final = img.resize((SIZE, SIZE), Image.LANCZOS)
final.save(OUT_PNG)
print(f'PNG → {OUT_PNG}')

# ── ICO (multi-size: 16 32 48 64 128 256) ────────────────
sizes   = [16, 32, 48, 64, 128, 256]
frames  = [final.resize((sz, sz), Image.LANCZOS) for sz in sizes]
frames[0].save(OUT_ICO, format='ICO',
               append_images=frames[1:],
               sizes=[(sz, sz) for sz in sizes])
print(f'ICO → {OUT_ICO}')