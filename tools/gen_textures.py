"""Authors every texture for the shrine showcase. Run: python3 tools/gen_textures.py"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from texlib import *

OUT = os.path.join(os.path.dirname(__file__), "..", "showcase", "textures")
os.makedirs(OUT, exist_ok=True)
N = 1024


def P(name):
    return os.path.join(OUT, name)


def granite():
    big = fft_noise(N, 2.6, 1, lo=2)
    mid = fft_noise(N, 2.0, 2, lo=8)
    fine = fft_noise(N, 1.0, 3, lo=60)
    speck = (fft_noise(N, 0.2, 4, lo=200) > 0.72).astype(float)
    dark = (fft_noise(N, 0.4, 5, lo=150) > 0.8).astype(float)
    h = 0.5 * big + 0.3 * mid + 0.2 * fine
    base = colorize(h, [(0, (0.33, 0.32, 0.30)), (0.5, (0.50, 0.48, 0.45)), (1, (0.64, 0.61, 0.56))])
    base = base * (1 - 0.25 * dark[..., None]) + 0.10 * speck[..., None]
    # faint warm lichen blooms
    lich = np.clip((fft_noise(N, 2.4, 6, lo=3) - 0.62) * 4, 0, 1)
    base = base * (1 - 0.35 * lich[..., None]) + np.array([0.62, 0.60, 0.42]) * 0.35 * lich[..., None]
    save_rgb(P("granite_albedo.png"), base)
    save_rgb(P("granite_normal.png"), normal_from_height(h * 0.7 + fine * 0.3, 3.0))
    save_gray(P("granite_rough.png"), 0.72 + 0.2 * mid - 0.15 * lich)


def masonry():
    """Irregular cut-stone blocks (stair risers, retaining walls, lantern bases)."""
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    rows = 6
    rh = N / rows
    wob = (fft_noise(N, 2.2, 11, lo=2) - 0.5) * 18
    row = np.floor((yy + wob) / rh)
    offs = (row % 2) * 0.5 + np.sin(row * 7.3) * 0.13
    widths = 1.6 + (np.sin(row * 3.1) * 0.5 + 0.5) * 0.9
    u = (xx / rh) / widths + offs + (fft_noise(N, 2.2, 12, lo=2) - 0.5) * 0.08
    cell_x = np.floor(u)
    fu = u - cell_x
    fv = ((yy + wob) / rh) - row
    edge = np.minimum(np.minimum(fu, 1 - fu) * widths * 1.0, np.minimum(fv, 1 - fv))
    gap = np.clip(edge / 0.05, 0, 1)
    bevel = np.clip(edge / 0.16, 0, 1) ** 0.6
    fine = fft_noise(N, 1.6, 13, lo=20)
    cellv = (np.sin(cell_x * 12.9898 + row * 78.233) * 43758.5453) % 1.0
    h = bevel * (0.8 + 0.2 * fine) - (1 - gap) * 0.3 + cellv * 0.08
    g = granite_like(14) * (0.88 + 0.24 * cellv[..., None])
    mortar = np.array([0.26, 0.26, 0.22])
    moss_in_gaps = np.clip(1 - gap, 0, 1)[..., None]
    mossc = np.array([0.20, 0.26, 0.08])
    alb = g * gap[..., None] + (mortar * 0.5 + mossc * 0.5) * moss_in_gaps
    save_rgb(P("masonry_albedo.png"), alb)
    save_rgb(P("masonry_normal.png"), normal_from_height(h, 5.0))
    save_gray(P("masonry_rough.png"), 0.85 - 0.1 * fine)


def granite_like(seed):
    a = fft_noise(N, 2.4, seed, lo=2); b = fft_noise(N, 1.2, seed + 1, lo=40)
    h = 0.6 * a + 0.4 * b
    return colorize(h, [(0, (0.36, 0.35, 0.33)), (0.5, (0.52, 0.50, 0.47)), (1, (0.66, 0.63, 0.58))])


def flagstone():
    f1, f2, cid = voronoi(N, 26, 21, stretch=(1.0, 1.0))
    edge = (f2 - f1)
    gap = np.clip((edge - 0.004) / 0.004, 0, 1)
    bevel = np.clip(edge / 0.035, 0, 1) ** 0.5
    fine = fft_noise(N, 1.4, 22, lo=20)
    cv = ((cid * 0.618) % 1.0)
    h = bevel * (0.85 + 0.15 * fine) + cv * 0.05
    stone = granite_like(23) * (0.85 + 0.25 * cv[..., None])
    grout = np.array([0.18, 0.22, 0.08])  # moss between stones
    alb = stone * gap[..., None] + grout * (1 - gap[..., None])
    save_rgb(P("flagstone_albedo.png"), alb)
    save_rgb(P("flagstone_normal.png"), normal_from_height(h, 5.0))
    save_gray(P("flagstone_rough.png"), (0.8 - 0.1 * fine) * gap + 0.95 * (1 - gap))


def wood():
    """Weathered cedar planks: long grain along V."""
    grain = fft_noise(N, 2.0, 31, lo=2, aniso=(0.04, 1.0))
    fine = fft_noise(N, 1.2, 32, lo=30, aniso=(0.08, 1.0))
    rings = (np.sin(grain * 90.0 + fine * 6.0) * 0.5 + 0.5) ** 1.5
    planks = 4
    xx = np.mgrid[0:N, 0:N][1].astype(float)
    pf = (xx / N * planks) % 1.0
    seam = np.clip(np.minimum(pf, 1 - pf) / 0.012, 0, 1)
    pid = np.floor(xx / N * planks)
    tone = 0.9 + 0.15 * np.sin(pid * 5.1)
    h = 0.55 * rings + 0.3 * fine + 0.15 * grain
    alb = colorize(h, [(0, (0.19, 0.13, 0.09)), (0.45, (0.40, 0.30, 0.21)), (1, (0.62, 0.50, 0.38))])
    weather = fft_noise(N, 2.0, 33, lo=2)
    grey = np.array([0.50, 0.47, 0.43])
    alb = alb * (1 - 0.35 * weather[..., None]) + grey * 0.35 * weather[..., None]
    alb = alb * tone[..., None] * (0.35 + 0.65 * seam[..., None])
    save_rgb(P("wood_albedo.png"), alb)
    save_rgb(P("wood_normal.png"), normal_from_height(h * 0.6 + seam * 0.4, 3.0))
    save_gray(P("wood_rough.png"), 0.7 + 0.2 * weather)


def lacquer():
    """Vermilion shu-urushi with sun-faded mottling and worn patches showing dark wood."""
    m = fft_noise(N, 2.2, 41, lo=2)
    fine = fft_noise(N, 1.0, 42, lo=40)
    base = colorize(m, [(0, (0.62, 0.14, 0.07)), (0.6, (0.74, 0.20, 0.09)), (1, (0.80, 0.30, 0.14))])
    wear = np.clip((fft_noise(N, 1.8, 43, lo=6) * 0.7 + fine * 0.3 - 0.70) * 8, 0, 1)
    under = np.array([0.12, 0.07, 0.05])
    alb = base * (1 - wear[..., None]) + under * wear[..., None]
    streak = fft_noise(N, 2.0, 44, lo=2, aniso=(0.05, 1.0))
    alb *= (0.92 + 0.12 * streak[..., None])
    save_rgb(P("lacquer_albedo.png"), alb)
    save_rgb(P("lacquer_normal.png"), normal_from_height(fine * 0.3 - wear * 0.4, 2.0))
    save_gray(P("lacquer_rough.png"), 0.32 + 0.25 * fine + 0.35 * wear)


def roof_tiles():
    """Hongawara-style ceramic tile courses: U-channels across U, overlapping rows along V."""
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    cols = 8
    rows = 8
    u = xx / N * cols
    v = yy / N * rows
    fu = u % 1.0
    fv = v % 1.0
    ch = np.cos((fu - 0.5) * 2 * math.pi) * 0.5 + 0.5        # rounded cover tile ridges
    lap = np.clip(fv * 1.25, 0, 1) ** 0.7                      # each course tilts up to its lip
    lip = np.clip((fv - 0.9) / 0.1, 0, 1)
    h = ch * 0.6 + lap * 0.35 - lip * 0.5
    noise = fft_noise(N, 1.4, 51, lo=20)
    h = h + noise * 0.05
    tone = 0.85 + 0.25 * fft_noise(N, 2.2, 52, lo=1)
    rowtone = 0.92 + 0.12 * np.sin(np.floor(v) * 3.7 + np.floor(u) * 1.9)
    alb = np.array([0.24, 0.26, 0.29]) * (tone * rowtone * (0.55 + 0.6 * ch * (1 - lip * 0.7)))[..., None]
    lich = np.clip((fft_noise(N, 2.0, 53, lo=3) - 0.66) * 5, 0, 1)
    alb = alb * (1 - 0.6 * lich[..., None]) + np.array([0.42, 0.44, 0.26]) * 0.6 * lich[..., None]
    save_rgb(P("roof_albedo.png"), alb)
    save_rgb(P("roof_normal.png"), normal_from_height(h, 6.0))
    save_gray(P("roof_rough.png"), 0.5 + 0.3 * noise + 0.2 * lich)


def bark():
    ridges = fft_noise(N, 2.0, 61, lo=3, aniso=(0.12, 1.0))
    r2 = 1 - np.abs(ridges * 2 - 1)
    fine = fft_noise(N, 1.2, 62, lo=30, aniso=(0.3, 1.0))
    h = r2 ** 1.5 * 0.75 + fine * 0.25
    alb = colorize(h, [(0, (0.10, 0.08, 0.07)), (0.5, (0.25, 0.20, 0.17)), (1, (0.40, 0.35, 0.31))])
    lich = np.clip((fft_noise(N, 2.2, 63, lo=3) - 0.6) * 4, 0, 1) * (h > 0.45)
    alb = alb * (1 - 0.4 * lich[..., None]) + np.array([0.45, 0.50, 0.38]) * 0.4 * lich[..., None]
    save_rgb(P("bark_albedo.png"), alb)
    save_rgb(P("bark_normal.png"), normal_from_height(h, 7.0))


def ground_set():
    # grass/meadow floor (seen beneath grass blades)
    a = fft_noise(N, 2.2, 71, lo=2); b = fft_noise(N, 0.8, 72, lo=60)
    h = 0.6 * a + 0.4 * b
    grass = colorize(h, [(0, (0.10, 0.14, 0.05)), (0.5, (0.20, 0.26, 0.09)), (1, (0.33, 0.36, 0.13))])
    litter = (fft_noise(N, 0.3, 73, lo=180) > 0.8)[..., None]
    grass = np.where(litter, np.array([0.36, 0.28, 0.16]), grass)
    save_rgb(P("grass_albedo.png"), grass)
    save_rgb(P("grass_normal.png"), normal_from_height(h, 2.0))
    # moss (cushiony)
    m = fft_noise(N, 1.6, 74, lo=6)
    mf = fft_noise(N, 0.6, 75, lo=120)
    hm = 0.6 * m + 0.4 * mf
    moss = colorize(hm, [(0, (0.10, 0.15, 0.03)), (0.5, (0.24, 0.32, 0.06)), (1, (0.42, 0.48, 0.12))])
    save_rgb(P("moss_albedo.png"), moss)
    save_rgb(P("moss_normal.png"), normal_from_height(hm, 3.0))
    # damp dirt path with pebbles
    d = fft_noise(N, 2.0, 76, lo=2)
    f1, f2, cid = voronoi(N, 220, 77)
    peb = np.clip(1 - f1 * 40, 0, 1) ** 0.5 * (((cid * 0.37) % 1) > 0.55)
    hd = d * 0.5 + peb * 0.6 + fft_noise(N, 1.0, 78, lo=50) * 0.2
    dirt = colorize(d, [(0, (0.17, 0.13, 0.10)), (1, (0.33, 0.27, 0.21))])
    dirt = dirt * (1 - peb[..., None]) + np.array([0.45, 0.43, 0.40]) * peb[..., None] * (0.8 + 0.3 * ((cid * 0.61) % 1))[..., None]
    save_rgb(P("dirt_albedo.png"), dirt)
    save_rgb(P("dirt_normal.png"), normal_from_height(hd, 4.0))
    # raked gravel (karesansui): pebbles + combed lines modulated in shader
    f1, f2, cid = voronoi(N, 900, 79)
    pebs = np.clip(1 - f1 * 70, 0, 1) ** 0.6
    hg = pebs + fft_noise(N, 1.0, 80, lo=60) * 0.15
    tone = 0.75 + 0.3 * ((cid * 0.61803) % 1)
    gravel = np.array([0.70, 0.68, 0.64]) * (tone * (0.55 + 0.45 * pebs))[..., None]
    save_rgb(P("gravel_albedo.png"), gravel)
    save_rgb(P("gravel_normal.png"), normal_from_height(hg, 4.0))
    # cliff rock (layered, for terrain slopes)
    layers = fft_noise(N, 2.0, 81, lo=2, aniso=(1.0, 0.08))
    cr = fft_noise(N, 1.4, 82, lo=10)
    hr = 0.55 * (np.sin(layers * 30) * 0.5 + 0.5) + 0.45 * cr
    rock = colorize(hr, [(0, (0.22, 0.21, 0.20)), (0.5, (0.40, 0.38, 0.35)), (1, (0.58, 0.55, 0.50))])
    save_rgb(P("cliff_albedo.png"), rock)
    save_rgb(P("cliff_normal.png"), normal_from_height(hr, 5.0))


def plaster():
    a = fft_noise(N, 2.4, 91, lo=2); b = fft_noise(N, 1.0, 92, lo=60)
    stain = np.clip((fft_noise(N, 2.0, 93, lo=2, aniso=(1.0, 0.3)) - 0.6) * 3, 0, 1)
    alb = np.array([0.86, 0.82, 0.74]) * (0.9 + 0.1 * a)[..., None] * (1 - 0.18 * stain[..., None])
    save_rgb(P("plaster_albedo.png"), alb)
    save_rgb(P("plaster_normal.png"), normal_from_height(b * 0.6 + a * 0.4, 1.5))


def shoji():
    """Paper panel with kumiko lattice (used for hall walls and lantern windows)."""
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    cols, rows = 3, 5
    lx = np.minimum((xx / N * cols) % 1, 1 - (xx / N * cols) % 1)
    ly = np.minimum((yy / N * rows) % 1, 1 - (yy / N * rows) % 1)
    lat = ((lx < 0.035) | (ly < 0.035 * cols / rows * 1.6))
    frame = (np.minimum(np.minimum(xx, N - xx), np.minimum(yy, N - yy)) < 28)
    fib = fft_noise(N, 1.0, 94, lo=40, aniso=(0.2, 1.0))
    paper = np.array([0.93, 0.89, 0.80]) * (0.94 + 0.06 * fib)[..., None]
    woodc = np.array([0.30, 0.22, 0.16])
    m = (lat | frame)[..., None]
    alb = np.where(m, woodc, paper)
    save_rgb(P("shoji_albedo.png"), alb)
    save_gray(P("shoji_mask.png"), 1.0 - m[..., 0].astype(float))  # paper = 1 (transmits light)


def water_normal():
    a = fft_noise(N, 1.6, 101, lo=6, hi=90)
    b = fft_noise(N, 1.2, 102, lo=20, hi=200)
    save_rgb(P("water_normal.png"), normal_from_height(a * 0.6 + b * 0.4, 2.5))


def foliage():
    S = 1024
    SS = 2

    def canvas():
        return Image.new("RGBA", (S * SS, S * SS), (0, 0, 0, 0))

    def finish(im, name, bleed_col):
        im = im.resize((S, S), Image.LANCZOS)
        a = np.asarray(im).astype(float) / 255
        # bleed colour into transparent texels so mipmaps don't fringe dark
        rgb = a[..., :3].copy(); al = a[..., 3:4]
        bl = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(float) / 255
        fill = np.where(al > 0.02, rgb, bl * 0.5 + np.array(bleed_col) * 0.5)
        save_rgba(P(name), np.concatenate([fill, al], -1))

    r = np.random.default_rng(5)
    # --- sakura blossom cluster card
    im = canvas(); d = ImageDraw.Draw(im)
    W = S * SS
    # twigs
    for k in range(7):
        x0, y0 = W * 0.5 + r.normal(0, W * 0.05), W * 0.98
        ang = -math.pi / 2 + r.normal(0, 0.55)
        x, y = x0, y0
        for s in range(14):
            nx_, ny_ = x + math.cos(ang) * W * 0.045, y + math.sin(ang) * W * 0.045
            d.line([(x, y), (nx_, ny_)], fill=(58, 38, 30, 255), width=int(W * 0.012 * (1 - s / 16)))
            x, y = nx_, ny_
            ang += r.normal(0, 0.18)
    for k in range(60):  # a few young bronze-green leaves tucked among the flowers
        cx = r.normal(0.5, 0.2) * W; cy = r.normal(0.5, 0.2) * W
        rad = W * r.uniform(0.009, 0.013)
        d.ellipse([cx - rad, cy - rad * 0.45, cx + rad, cy + rad * 0.45], fill=(104, 118, 58, 255))
    for k in range(900):
        cx = r.normal(0.5, 0.21) * W; cy = r.normal(0.45, 0.21) * W
        if not (0.08 * W < cx < 0.92 * W and 0.06 * W < cy < 0.9 * W):
            continue
        rad = W * r.uniform(0.011, 0.018)
        base = np.array([0.95, 0.68, 0.79]) * r.uniform(0.88, 1.04) + r.normal(0, 0.025, 3)
        rot = r.uniform(0, math.tau)
        for p in range(5):
            a_ = rot + p * math.tau / 5
            px, py = cx + math.cos(a_) * rad * 0.8, cy + math.sin(a_) * rad * 0.8
            c = tuple(int(255 * min(1, v)) for v in base) + (255,)
            d.ellipse([px - rad * 0.62, py - rad * 0.62, px + rad * 0.62, py + rad * 0.62], fill=c)
        d.ellipse([cx - rad * 0.3, cy - rad * 0.3, cx + rad * 0.3, cy + rad * 0.3], fill=(236, 120, 150, 255))
        d.ellipse([cx - rad * 0.12, cy - rad * 0.12, cx + rad * 0.12, cy + rad * 0.12], fill=(250, 214, 120, 255))
    finish(im, "blossom_card.png", (0.95, 0.75, 0.82))

    # --- sugi (Cryptomeria) spray card: a dense fan of rope-like branchlets covered in
    # short awl needles, so the card reads as foliage mass rather than individual fronds
    im = canvas(); d = ImageDraw.Draw(im)
    for k in range(85):
        x, y = W * 0.5 + r.normal(0, W * 0.05), W * 0.5 + r.normal(0, W * 0.05)
        ang = r.uniform(0, math.tau)
        L = r.uniform(0.45, 0.75)
        steps = int(L * 60)
        for s_ in range(steps):
            nx_, ny_ = x + math.cos(ang) * W * 0.012, y + math.sin(ang) * W * 0.012
            u = s_ / steps
            g = r.uniform(0.7, 1.15) * (0.75 + 0.45 * u)
            base = (int(36 * g), int(66 * g), int(34 * g), 255)
            rad = W * 0.011 * (1 - 0.5 * u)
            d.ellipse([nx_ - rad, ny_ - rad, nx_ + rad, ny_ + rad], fill=(int(28 * g), int(50 * g), int(28 * g), 255))
            for q in range(5):
                na = ang + r.uniform(-1.4, 1.4)
                nl = W * r.uniform(0.008, 0.018)
                d.line([(nx_, ny_), (nx_ + math.cos(na) * nl, ny_ + math.sin(na) * nl)], fill=base, width=max(2, int(W * 0.0035)))
            if u > 0.85 and r.random() < 0.5:
                d.ellipse([nx_ - rad, ny_ - rad, nx_ + rad, ny_ + rad], fill=(int(70 * g), int(96 * g), int(40 * g), 255))
            x, y = nx_, ny_
            ang += r.normal(0, 0.08)
            if not (0.03 * W < x < 0.97 * W and 0.03 * W < y):
                break
    finish(im, "needle_card.png", (0.15, 0.27, 0.14))

    # --- broadleaf card (background deciduous / shrubs)
    im = canvas(); d = ImageDraw.Draw(im)
    for k in range(170):
        cx = r.normal(0.5, 0.2) * W; cy = r.normal(0.5, 0.2) * W
        if not (0.06 * W < cx < 0.94 * W and 0.06 * W < cy < 0.94 * W):
            continue
        L = W * r.uniform(0.035, 0.06); a_ = r.uniform(0, math.tau)
        g = r.uniform(0.75, 1.15)
        col = (int(70 * g), int(105 * g), int(42 * g), 255)
        pts = []
        for t in np.linspace(0, math.tau, 18):
            rr = L * (0.5 + 0.5 * abs(math.cos(t / 2)))
            pts.append((cx + math.cos(t + a_) * rr * (1 if math.cos(t) > 0 else 0.6), cy + math.sin(t + a_) * rr * 0.45))
        d.polygon(pts, fill=col)
    finish(im, "leaf_card.png", (0.25, 0.38, 0.16))

    # --- single petal (falling particles)
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse([20, 34, 108, 94], fill=(252, 214, 224, 255))
    d.polygon([(64, 30), (58, 44), (70, 44)], fill=(0, 0, 0, 0))
    im.save(P("petal.png"))


if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for f in (granite, masonry, flagstone, wood, lacquer, roof_tiles, bark, ground_set, plaster, shoji, water_normal, foliage):
        if only and f.__name__ not in only:
            continue
        f()
        print("done", f.__name__, flush=True)
