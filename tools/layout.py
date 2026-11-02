"""World layout shared by the Blender build and the Godot scene.
Coordinates: Godot convention, metres. +X east, +Y up, -Z north (toward the shrine).
Run directly to write showcase/data/layout.json and grass.bin."""
import json, math, os, struct
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "showcase")

# terrain extent (inner, detailed)
X0, X1, Z0, Z1 = -72.0, 72.0, -110.0, 56.0
POND_C = (0.0, 22.0)
POND_R = (11.5, 6.8)
WATER_Y = -0.28
PLATEAU = (-19.0, 21.0, -72.0, -40.0)  # x0, x1, z0, z1 (courtyard)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def stair_y(z):
    """Exact stair/landing profile along the axis (x = 0)."""
    z = np.asarray(z, float)
    y = np.zeros_like(z)
    y = np.where(z < -6, (np.clip(-6 - z, 0, 10) / 10) * 4, y)
    y = np.where(z < -16, 4.0, y)
    y = np.where(z < -18, 4 + (np.clip(-18 - z, 0, 10) / 10) * 4, y)
    y = np.where(z < -28, 8.0, y)
    y = np.where(z < -30, 8 + (np.clip(-30 - z, 0, 10) / 10) * 4, y)
    y = np.where(z < -40, 12.0, y)
    return y


def _fbm(x, z, seed=0, octaves=5, f=0.03):
    v = np.zeros_like(x, dtype=float)
    a = 1.0
    for o in range(octaves):
        k = f * (2 ** o)
        v += a * (np.sin(x * k * 1.7 + seed + o * 1.3) * np.cos(z * k * 1.3 - seed * 0.7 + o)
                  + 0.5 * np.sin((x * 0.6 + z * 0.8) * k * 2.1 + seed * 2 + o * 2.7))
        a *= 0.5
    return v


def height(x, z):
    x = np.asarray(x, float); z = np.asarray(z, float)
    # broad hill rising north to the plateau, then the wooded ridge behind the hall
    hill = 12.0 * smooth(-4.0, -42.0, z)
    hill += np.clip(-72.0 - z, 0, None) * 0.9 * smooth(-72, -90, z) + 6.0 * smooth(-80, -110, z)
    # near the stair axis follow the exact stepped profile
    axis = np.exp(-(x / 7.0) ** 2)
    y = hill * (1 - axis) + stair_y(z) * axis
    # south rise behind the spawn
    y += np.clip(z - 34.0, 0, None) * 0.22
    # east ridge (wooded), west hills in the south
    y += 20.0 * smooth(22.0, 55.0, x) ** 1.3 * (0.6 + 0.4 * smooth(30, -40, z))
    y += 9.0 * smooth(-20.0, -48.0, x) * smooth(-8.0, 12.0, z)
    # north-west: the land falls away into the valley (overlook)
    drop = smooth(-21.0, -36.0, x) * smooth(4.0, -22.0, z)
    y = y * (1 - drop) + (-26.0 + 3.0 * _fbm(x, z, 3, 3, 0.02)) * drop
    # organic variation, suppressed in built-up areas
    built = np.maximum.reduce([
        axis * smooth(40.0, 30.0, z),
        plateau_mask(x, z),
        pond_mask(x, z, 1.25),
        path_mask(x, z),
    ])
    y += _fbm(x, z, 1) * 0.55 * (1 - built)
    # flat courtyard
    pm = plateau_mask(x, z)
    y = y * (1 - pm) + 12.0 * pm
    # pond basin
    r = pond_r(x, z)
    basin = np.clip(1 - r * r, 0, 1) ** 0.6
    y = y - basin * 1.5 + smooth(1.0, 1.15, r) * smooth(1.45, 1.15, r) * 0.15
    return y


def pond_r(x, z):
    return np.sqrt(((x - POND_C[0]) / POND_R[0]) ** 2 + ((z - POND_C[1]) / POND_R[1]) ** 2)


def pond_mask(x, z, k=1.0):
    return smooth(k, k * 0.85, pond_r(x, z))


def plateau_mask(x, z):
    x0, x1, z0, z1 = PLATEAU
    mx = smooth(x0 - 1.5, x0 + 1.0, x) * smooth(x1 + 1.5, x1 - 1.0, x)
    mz = smooth(z0 - 1.5, z0 + 1.0, z) * smooth(z1 + 0.5, z1 - 0.5, z)
    return mx * mz


def path_x(z):
    """Gently meandering garden path centreline from the bridge to the stair foot."""
    return 1.2 * np.sin(np.asarray(z) * 0.19) * smooth(12.0, 4.0, z) * smooth(-6.0, 0.0, z)


def path_mask(x, z):
    on = smooth(-7.0, -5.0, z) * smooth(36.0, 33.0, z)
    d = np.abs(x - path_x(z))
    return smooth(2.6, 1.6, d) * on * (1 - pond_mask(x, z, 1.0))


def slope(x, z, e=0.5):
    hx = (height(x + e, z) - height(x - e, z)) / (2 * e)
    hz = (height(x, z + e) - height(x, z - e)) / (2 * e)
    return np.sqrt(hx * hx + hz * hz)


def splat(x, z):
    """Vertex colour weights: R = path dirt/flagstone, G = moss, B = rock."""
    s = slope(x, z)
    rock = smooth(0.75, 1.15, s)
    path = path_mask(x, z)
    near_stair = np.exp(-(np.abs(x) / 3.5) ** 2) * smooth(-3, -6, z) * smooth(-44, -40, z)
    shore = smooth(1.35, 1.0, pond_r(x, z))
    moss = np.clip(0.35 * shore + 0.7 * near_stair + 0.5 * smooth(-60, -80, z) + 0.25 * (np.sin(x * 0.21) * np.cos(z * 0.17) * 0.5 + 0.5), 0, 1)
    moss *= (1 - rock)
    court = plateau_mask(x, z)
    return np.stack([np.clip(path + court, 0, 1), moss, rock], -1)


# ------------------------------------------------------------------ placements
def P(x, z, **k):
    d = {"x": float(x), "y": float(height(x, z)), "z": float(z)}
    d.update(k)
    return d


def build_layout():
    rng = np.random.default_rng(11)
    L = {}
    L["spawn"] = {"x": 0.6, "y": float(height(0.6, 36.0)) + 0.05, "z": 36.0, "yaw": 0.0}
    L["torii"] = [
        P(0, 9.0, s=0.95, kind="big"),
        P(0, -4.6, s=1.0, kind="big"),
        P(0, -16.9, s=0.95, kind="big"),
        P(0, -28.9, s=0.95, kind="big"),
        P(0, -41.2, s=1.1, kind="big"),
    ]
    L["senbon"] = [dict(x=0.0, y=float(stair_y(z)), z=float(z), s=0.62, kind="small") for z in np.arange(-18.7, -27.5, -0.95)]
    lan = []
    for z in (13.0, 5.0, -2.5):
        for sx in (-1, 1):
            xx = float(path_x(z)) + sx * 2.7
            lan.append(P(xx, z, lit=(z != 5.0), rot=0.0 if sx < 0 else math.pi))
    for z in (-45.0, -49.5):
        for sx in (-1, 1):
            lan.append(dict(x=sx * 3.3, y=12.0, z=z, lit=True, rot=0.0))
    lan.append(P(-9.0, 15.5, lit=True, rot=0.6))   # pond-side
    L["lanterns"] = lan
    # cherry blossoms: deliberate framing, not random scatter
    L["sakura"] = [
        P(-14.5, 19.5, s=1.15, rot=0.3), P(13.5, 26.0, s=1.0, rot=2.1), P(-12.0, 1.0, s=0.95, rot=4.0),
        P(12.5, -3.0, s=1.05, rot=1.2), P(-7.0, -13.0, s=0.9, rot=2.7), P(7.5, -21.5, s=0.95, rot=5.1),
        P(-14.0, -47.0, s=1.2, rot=0.9), P(-16.5, -63.0, s=1.0, rot=3.3), P(16.0, -45.5, s=1.0, rot=4.4),
        P(6.0, 40.5, s=1.1, rot=1.7), P(-21.0, 30.0, s=1.0, rot=0.2),
    ]
    L["maple"] = [P(-10.5, 10.0, s=0.9, rot=1.0), P(11.0, 13.0, s=0.8, rot=2.0), P(13.0, -64.0, s=1.0, rot=0.5), P(5.5, -35.0, s=0.75, rot=3.0)]
    L["sacred_tree"] = P(-9.5, -52.0, s=1.0, rot=0.4)
    # cedar forest: masses that frame the composition and close the horizon
    ced = []

    def ok(x, z):
        if pond_mask(x, z, 1.4) > 0.01 or path_mask(x, z) > 0.01 or plateau_mask(x, z) > 0.01:
            return False
        if abs(x) < 6 and -44 < z < 0:
            return False
        if slope(x, z) > 1.2:
            return False
        if height(x, z) < -20:
            return False
        for c in ced:
            if (c["x"] - x) ** 2 + (c["z"] - z) ** 2 < 4.2 ** 2:
                return False
        for t in L["sakura"] + L["maple"]:
            if (t["x"] - x) ** 2 + (t["z"] - z) ** 2 < 6.0 ** 2:
                return False
        return True
    # framing masses only: the stair axis and the hill must stay readable from the bridge
    regions = [  # (x0,x1,z0,z1,count)
        (26, 66, -100, 50, 64), (-60, 22, -108, -76, 46), (-60, -26, 4, 54, 26),
        (16, 26, -36, -6, 4), (-24, -16, -30, -8, 3), (-40, 30, 46, 56, 14),
    ]
    for (x0, x1, z0, z1, n) in regions:
        tries = 0
        made = 0
        while made < n and tries < n * 40:
            tries += 1
            x = rng.uniform(x0, x1); z = rng.uniform(z0, z1)
            if ok(x, z):
                ced.append(P(x, z, s=float(rng.uniform(0.75, 1.25)), rot=float(rng.uniform(0, 6.28))))
                made += 1
    L["cedars"] = ced
    # rocks
    rocks = []
    for k in range(22):  # pond shore
        a = k / 22 * math.tau + rng.uniform(-0.1, 0.1)
        rr = 1.0 + rng.uniform(0.0, 0.08)
        x = POND_C[0] + math.cos(a) * POND_R[0] * rr
        z = POND_C[1] + math.sin(a) * POND_R[1] * rr
        if abs(x) < 2.6:
            continue
        rocks.append(P(x, z, s=float(rng.uniform(0.5, 1.2)), v=int(rng.integers(0, 6)), rot=float(rng.uniform(0, 6.28)), sink=0.25))
    for (x, z, s) in [(4.5, 21, 1.6), (-3.8, 24.5, 1.1), (-4.5, 9, 1.3), (5.5, 6.0, 0.9), (-4.0, -6.5, 1.8), (4.4, -7.0, 1.4),
                      (-15, -56, 2.4), (-12, -58, 1.3), (-17.5, -52, 1.6), (17, -68, 2.0), (-23, -43, 2.6), (-24, -36, 3.2),
                      (-22, -28, 2.8), (10, 34, 1.6), (-12, 36, 2.2), (14, 8, 1.4), (-15, 4, 1.8)]:
        rocks.append(P(x, z, s=float(s), v=int(rng.integers(0, 6)), rot=float(rng.uniform(0, 6.28)), sink=0.3))
    for k in range(30):  # hillside outcrops
        x = rng.uniform(-30, 40); z = rng.uniform(-90, 50)
        if slope(x, z) > 0.45 and pond_mask(x, z, 1.4) < 0.01 and path_mask(x, z) < 0.01 and abs(x) > 5 and plateau_mask(x, z) < 0.01:
            rocks.append(P(x, z, s=float(rng.uniform(1.0, 2.6)), v=int(rng.integers(0, 6)), rot=float(rng.uniform(0, 6.28)), sink=0.5))
    L["rocks"] = rocks
    L["hall"] = {"x": 0.0, "y": 12.0, "z": -64.0, "s": 1.35}
    L["bell"] = {"x": 12.5, "y": 12.0, "z": -52.0}
    L["pavilion"] = {"x": -16.0, "y": 12.0, "z": -67.5}
    L["bridge"] = {"x": 0.0, "y": 0.0, "z": 22.0}
    L["pond"] = {"x": POND_C[0], "z": POND_C[1], "rx": POND_R[0], "rz": POND_R[1], "water_y": WATER_Y}
    L["plateau"] = list(PLATEAU)
    return L


def build_grass(L):
    """Grass clump transforms: x, y, z, yaw, scale, tint."""
    rng = np.random.default_rng(3)
    n = 220000
    x = rng.uniform(-48, 46, n); z = rng.uniform(-82, 52, n)
    # density falls off away from the explorable core
    keep = rng.random(n) < (0.25 + 0.75 * np.exp(-((x / 34) ** 2)))
    x, z = x[keep], z[keep]
    y = height(x, z)
    sp = splat(x, z)
    s = slope(x, z)
    m = (sp[:, 0] < 0.3) & (sp[:, 2] < 0.4) & (pond_mask(x, z, 1.08) < 0.05) & (s < 1.0) & (y > -18)
    m &= ~((np.abs(x) < 2.4) & (z < -3) & (z > -42))   # stair
    m &= plateau_mask(x, z) < 0.2
    # thin it where moss dominates (moss reads better clean)
    m &= rng.random(len(x)) > sp[:, 1] * 0.6
    x, y, z = x[m], y[m], z[m]
    yaw = rng.uniform(0, math.tau, len(x))
    sc = rng.uniform(0.5, 1.0, len(x)) * (1 - 0.3 * splat(x, z)[:, 1]) * (0.75 + 0.25 * smooth(1.5, 4.0, np.abs(x - path_x(z))))
    tint = rng.random(len(x))
    arr = np.stack([x, y, z, yaw, sc, tint], -1).astype(np.float32)
    return arr


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "data"), exist_ok=True)
    L = build_layout()
    with open(os.path.join(ROOT, "data", "layout.json"), "w") as f:
        json.dump(L, f, indent=1)
    g = build_grass(L)
    g.tofile(os.path.join(ROOT, "data", "grass.bin"))
    print("cedars", len(L["cedars"]), "rocks", len(L["rocks"]), "grass", len(g))
