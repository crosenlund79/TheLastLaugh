"""Small tileable-texture toolkit (numpy + PIL). Everything wraps seamlessly."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RNG = np.random.default_rng(7)


def fft_noise(n, beta=2.0, seed=0, lo=1.0, hi=None, aniso=(1.0, 1.0)):
    """Tileable fractal noise in [0,1]: white noise shaped by 1/f^beta in frequency space."""
    r = np.random.default_rng(seed)
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    fy = np.fft.fftfreq(n)[:, None] * n * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * n * aniso[0]
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1.0
    amp = 1.0 / np.power(k, beta / 2.0)
    amp[k < lo] = 0.0
    if hi is not None:
        amp *= np.exp(-(k / hi) ** 2)
    out = np.real(np.fft.ifft2(f * amp))
    out -= out.min()
    out /= max(out.max(), 1e-9)
    return out


def norm(a):
    a = a - a.min()
    return a / max(a.max(), 1e-9)


def sample(img, x, y):
    """Bilinear wrapped sampling of a 2D array at float coords (pixels)."""
    n = img.shape[0]
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    fx = x - x0; fy = y - y0
    x0 %= n; y0 %= n
    x1 = (x0 + 1) % n; y1 = (y0 + 1) % n
    a = img[y0, x0] * (1 - fx) + img[y0, x1] * fx
    b = img[y1, x0] * (1 - fx) + img[y1, x1] * fx
    return a * (1 - fy) + b * fy


def warp(img, wx, wy, amount):
    n = img.shape[0]
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    return sample(img, xx + (wx - 0.5) * amount, yy + (wy - 0.5) * amount)


def blur(a, r):
    im = Image.fromarray((norm(a) * 65535).astype(np.uint16).astype(np.int32), mode="I")
    # PIL blur on float via 3 tiles for wrap
    n = a.shape[0]
    t = np.tile(a, (3, 3))
    pim = Image.fromarray(t.astype(np.float32), mode="F").filter(ImageFilter.GaussianBlur(r))
    return np.asarray(pim)[n:2 * n, n:2 * n]


def voronoi(n, count, seed=0, jitter=1.0, stretch=(1.0, 1.0)):
    """Tileable F1/F2 distances and cell ids."""
    r = np.random.default_rng(seed)
    pts = r.random((count, 2))
    yy, xx = np.mgrid[0:n, 0:n] / n
    f1 = np.full((n, n), 9.0); f2 = np.full((n, n), 9.0); cid = np.zeros((n, n), int)
    for i, (px, py) in enumerate(pts):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                dx = (xx - (px + ox)) * stretch[0]
                dy = (yy - (py + oy)) * stretch[1]
                d = np.sqrt(dx * dx + dy * dy)
                closer = d < f1
                f2 = np.where(closer, f1, np.minimum(f2, d))
                cid = np.where(closer, i, cid)
                f1 = np.where(closer, d, f1)
    return f1, f2, cid


def normal_from_height(h, strength=4.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx = -dx * strength * h.shape[0] / 256.0
    ny = dy * strength * h.shape[0] / 256.0  # OpenGL (Y+) convention for Godot
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def colorize(t, stops):
    """t in [0,1] -> RGB via list of (pos, (r,g,b)) stops."""
    pos = np.array([s[0] for s in stops]); cols = np.array([s[1] for s in stops], float)
    out = np.zeros(t.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(t, pos, cols[:, c])
    return out


def save_rgb(path, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(path, optimize=True)


def save_gray(path, g):
    Image.fromarray((np.clip(g, 0, 1) * 255 + 0.5).astype(np.uint8), "L").save(path, optimize=True)


def save_rgba(path, rgba):
    Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)
