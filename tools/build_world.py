"""Blender (4.x) asset + world build for the shrine showcase.
Run:  blender -b --python tools/build_world.py -- [asset ...]
Exports GLBs into showcase/models/. Godot-space (x, y, z) maps to Blender (x, -z, y)."""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as LY

OUT = os.path.join(HERE, "..", "showcase", "models")
os.makedirs(OUT, exist_ok=True)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
TAU = math.tau


def G(x, y, z):
    """Godot coordinates -> Blender coordinates."""
    return Vector((x, -z, y))


# ------------------------------------------------------------------ scene utils
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        cols = {"lacquer": (0.7, 0.15, 0.06, 1), "black_lacquer": (0.03, 0.03, 0.03, 1), "granite": (0.5, 0.48, 0.45, 1),
                "wood": (0.4, 0.3, 0.2, 1), "roof": (0.25, 0.27, 0.3, 1), "plaster": (0.85, 0.82, 0.75, 1),
                "shoji": (0.9, 0.86, 0.78, 1), "bark": (0.25, 0.2, 0.17, 1), "blossom": (0.95, 0.75, 0.82, 1),
                "needles": (0.15, 0.3, 0.15, 1), "maple": (0.7, 0.2, 0.1, 1), "leaves": (0.25, 0.38, 0.15, 1),
                "gold": (0.9, 0.7, 0.3, 1), "bronze": (0.3, 0.4, 0.35, 1), "rope": (0.75, 0.65, 0.4, 1),
                "paper": (0.95, 0.95, 0.92, 1), "lantern_glow": (1.0, 0.8, 0.5, 1), "masonry": (0.5, 0.5, 0.48, 1),
                "flagstone": (0.5, 0.5, 0.48, 1), "terrain": (0.3, 0.35, 0.2, 1), "mountain": (0.3, 0.35, 0.45, 1),
                "gravel": (0.7, 0.7, 0.65, 1), "ridge": (0.15, 0.16, 0.18, 1), "dark_wood": (0.15, 0.1, 0.08, 1)}
        m.diffuse_color = cols.get(name, (0.8, 0.8, 0.8, 1))
    return m


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_obj(name, verts, faces, matname, uvs=None, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    if uvs is not None:
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                uvl.data[li].uv = uvs[vi]
    o = bpy.data.objects.new(name, me)
    o.location = loc
    link(o)
    me.materials.append(mat(matname))
    return o


def activate(o):
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)


def apply_mods(o):
    activate(o)
    for m in list(o.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception as e:
            print("modifier apply failed", m.name, e)
            o.modifiers.remove(m)


def bevel(o, w=0.02, seg=2, angle=40):
    m = o.modifiers.new("bev", "BEVEL")
    m.width = w
    m.segments = seg
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
    m.harden_normals = False
    return m


def weather(o, strength=0.01, size=0.25, subdiv=0):
    if subdiv:
        s = o.modifiers.new("sub", "SUBSURF")
        s.levels = subdiv
        s.render_levels = subdiv
        s.subdivision_type = "SIMPLE"
    t = bpy.data.textures.new("wt_" + o.name, "CLOUDS")
    t.noise_scale = size
    d = o.modifiers.new("disp", "DISPLACE")
    d.texture = t
    d.strength = strength
    d.mid_level = 0.5


def smooth_shade(o, angle=35):
    activate(o)
    bpy.ops.object.shade_smooth()
    try:
        o.data.use_auto_smooth = True
        o.data.auto_smooth_angle = math.radians(angle)
    except Exception:
        pass


def box(name, size, loc, matname, rot=(0, 0, 0), bev=0.0, seg=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    activate(o)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat(matname))
    if bev > 0:
        bevel(o, bev, seg)
    return o


def cyl(name, r1, r2, h, loc, matname, verts=24, rot=(0, 0, 0), bev=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat(matname))
    if bev > 0:
        bevel(o, bev, 2)
    smooth_shade(o)
    return o


def lathe(name, profile, segs, matname, loc=(0, 0, 0), cap=True):
    """Revolve [(r, z), ...] around Z."""
    verts, faces = [], []
    n = len(profile)
    for s in range(segs):
        a = TAU * s / segs
        for (r, z) in profile:
            verts.append((math.cos(a) * r, math.sin(a) * r, z))
    for s in range(segs):
        s2 = (s + 1) % segs
        for i in range(n - 1):
            faces.append((s * n + i, s2 * n + i, s2 * n + i + 1, s * n + i + 1))
    if cap:
        if profile[0][0] > 1e-4:
            faces.append(tuple(reversed([s * n for s in range(segs)])))
        if profile[-1][0] > 1e-4:
            faces.append(tuple([s * n + n - 1 for s in range(segs)]))
    o = mesh_obj(name, verts, faces, matname, loc=loc)
    activate(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    smooth_shade(o)
    return o


def tube(name, pts, radius, matname, sides=10, radii=None):
    """Sweep a circle along a polyline of Vectors."""
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        up = Vector((0, 0, 1)) if abs(t.z) < 0.95 else Vector((1, 0, 0))
        b1 = t.cross(up).normalized(); b2 = t.cross(b1).normalized()
        r = radii[i] if radii else radius
        for k in range(sides):
            a = TAU * k / sides
            verts.append(p + (b1 * math.cos(a) + b2 * math.sin(a)) * r)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
    o = mesh_obj(name, verts, faces, matname)
    smooth_shade(o, 80)
    return o


def join(objs, name):
    objs = [o for o in objs if o is not None]
    for o in objs:
        apply_mods(o)
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def export(path, objs=None):
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    objs = objs or list(bpy.context.scene.objects)
    for o in objs:
        o.select_set(True)
    kw = dict(filepath=os.path.join(OUT, path), export_format="GLB", use_selection=True, export_apply=True,
              export_normals=True, export_materials="EXPORT", export_yup=True)
    try:
        bpy.ops.export_scene.gltf(export_colors=True, **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("exported", path)


def collider(name, size, loc, rot=(0, 0, 0)):
    o = box(name + "-colonly", size, loc, "granite", rot)
    return o


# ------------------------------------------------------------------ architecture parts
def curved_beam(name, length, h, d, sag, z0, matname, segs=40, flare=0.25):
    """Kasagi-style lintel: rises toward its ends (sori) and flares in height."""
    verts, faces = [], []
    for i in range(segs + 1):
        u = i / segs * 2 - 1
        x = u * length / 2
        lift = sag * abs(u) ** 2.2
        hh = h * (1 + flare * abs(u) ** 3)
        zb = z0 + lift
        for (yy, zz) in ((-d / 2, zb), (d / 2, zb), (d / 2, zb + hh), (-d / 2, zb + hh)):
            verts.append((x, yy, zz))
    for i in range(segs):
        for k in range(4):
            k2 = (k + 1) % 4
            faces.append((i * 4 + k, i * 4 + k2, (i + 1) * 4 + k2, (i + 1) * 4 + k))
    faces.append((3, 2, 1, 0))
    e = segs * 4
    faces.append((e, e + 1, e + 2, e + 3))
    o = mesh_obj(name, verts, faces, matname)
    bevel(o, 0.02, 2)
    return o


def torii(simple=False):
    reset()
    parts = []
    span = 2.0 if not simple else 2.42
    H = 5.2 if not simple else 3.7
    pr = 1.0 if not simple else 0.66
    lean = math.radians(2.2)
    for sx in (-1, 1):
        p = cyl("pillar", 0.25 * pr, 0.2 * pr, H, (sx * span, 0, H / 2), "lacquer", 28)
        p.rotation_euler = (0, sx * lean * -1, 0)
        p.location.x = sx * (span - math.sin(lean) * H / 2)
        parts.append(p)
        parts.append(cyl("kamaki", 0.29 * pr, 0.28 * pr, 0.55 * pr, (sx * span, 0, 0.27 * pr), "black_lacquer", 28, bev=0.01))
        if not simple:
            parts.append(cyl("ring", 0.3, 0.3, 0.05, (sx * span, 0, 0.57), "black_lacquer", 28))
            b = box("base", (0.95, 0.95, 0.3), (sx * span, 0, -0.08), "granite", bev=0.05, seg=3)
            weather(b, 0.015, 0.3, 2)
            parts.append(b)
    k = H / 5.2
    parts.append(box("nuki", (span * 2 + 1.1 * pr, 0.17 * pr, 0.27 * pr), (0, 0, 3.85 * k), "lacquer", bev=0.012))
    parts.append(box("shimaki", (span * 2 + 1.9 * pr, 0.33 * pr, 0.3 * pr), (0, 0, 4.72 * k), "lacquer", bev=0.012))
    parts.append(curved_beam("kasagi", span * 2 + 3.3 * pr, 0.36 * pr, 0.48 * pr, 0.34 * pr, 4.72 * k + 0.15 * pr, "black_lacquer"))
    parts.append(box("gakuzuka", (0.24 * pr, 0.2 * pr, (4.72 - 3.85) * k), (0, 0, (4.72 + 3.85) / 2 * k), "lacquer", bev=0.01))
    if not simple:
        parts.append(box("plaque", (0.62, 0.08, 0.86), (0, -0.14, 4.28), "black_lacquer", bev=0.015))
        parts.append(box("plaque_rim", (0.7, 0.06, 0.94), (0, -0.115, 4.28), "gold", bev=0.01))
    o = join(parts, "torii_small" if simple else "torii")
    smooth_shade(o, 30)
    cols = [collider("p", (0.55 * pr, 0.55 * pr, H), (sx * span, 0, H / 2)) for sx in (-1, 1)]
    export("torii_small.glb" if simple else "torii.glb", [o] + cols)


def lantern():
    reset()
    parts = []
    hexr = 6
    base = cyl("kiso", 0.6, 0.52, 0.2, (0, 0, 0.1), "granite", hexr, bev=0.02)
    parts.append(base)
    parts.append(cyl("kiso2", 0.44, 0.34, 0.16, (0, 0, 0.28), "granite", hexr, bev=0.02))
    parts.append(lathe("sao", [(0.13, 0.36), (0.16, 0.4), (0.13, 0.46), (0.12, 0.8), (0.15, 0.84), (0.12, 0.88), (0.12, 1.22), (0.16, 1.28)], 20, "granite"))
    parts.append(cyl("chudai", 0.32, 0.44, 0.22, (0, 0, 1.38), "granite", hexr, bev=0.02))
    fire = cyl("hibukuro", 0.31, 0.31, 0.44, (0, 0, 1.71), "granite", hexr, bev=0.015)
    for a in (0, math.pi):  # carve two windows (front/back)
        cut = box("cut", (0.5, 0.2, 0.26), (0, 0, 1.73), "granite", rot=(0, 0, a + math.pi / 2))
        cut.location = (math.cos(a) * 0.3, math.sin(a) * 0.3, 1.73)
        m = fire.modifiers.new("cut", "BOOLEAN")
        m.object = cut
        m.operation = "DIFFERENCE"
        apply_mods(fire)
        bpy.data.objects.remove(cut)
    for a in (math.pi / 2, -math.pi / 2):  # round "moon" windows on the sides
        c = cyl("cutc", 0.1, 0.1, 0.4, (0, 0, 1.73), "granite", 20, rot=(0, math.pi / 2, a))
        c.location = (math.cos(a) * 0.3, math.sin(a) * 0.3, 1.73)
        m = fire.modifiers.new("cutc", "BOOLEAN")
        m.object = c
        m.operation = "DIFFERENCE"
        apply_mods(fire)
        bpy.data.objects.remove(c)
    parts.append(fire)
    glow = cyl("glow", 0.2, 0.2, 0.3, (0, 0, 1.72), "lantern_glow", 12)
    parts.append(glow)
    parts.append(lathe("kasa", [(0.0, 0.42), (0.14, 0.38), (0.34, 0.2), (0.56, 0.06), (0.66, 0.04), (0.66, 0.0), (0.6, -0.04), (0.3, -0.02), (0.0, -0.02)], 6, "granite", loc=(0, 0, 1.94)))
    for k in range(6):  # warabite curls at the roof corners
        a = TAU * k / 6
        s = bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06, location=(math.cos(a) * 0.66, math.sin(a) * 0.66, 2.02))
        o = bpy.context.active_object
        o.data.materials.append(mat("granite"))
        o.scale = (1, 1, 1.3)
        parts.append(o)
    parts.append(lathe("hoju", [(0.0, 0.0), (0.12, 0.02), (0.13, 0.06), (0.06, 0.1), (0.13, 0.16), (0.14, 0.24), (0.09, 0.33), (0.03, 0.4), (0.0, 0.43)], 16, "granite", loc=(0, 0, 2.34)))
    for p in parts:
        if p is not glow:
            weather(p, 0.008, 0.12)
    o = join(parts, "lantern")
    col = collider("c", (0.9, 0.9, 2.4), (0, 0, 1.2))
    export("lantern.glb", [o, col])


def roof_mesh(name, W, D, H, z0, ridge_curve=1.0, upturn=0.55, res=(70, 48), thick=0.32):
    """Curved hipped roof with swept eaves (sori) and upturned corners.
    UVs run down-slope so the tile courses follow the roof."""
    nx, ny = res
    verts, uvs, faces = [], [], []
    for j in range(ny + 1):
        for i in range(nx + 1):
            x = (i / nx - 0.5) * W
            y = (j / ny - 0.5) * D
            sx = W / 2 - abs(x)
            sy = D / 2 - abs(y)
            s = min(sx, sy)
            t = s / (D / 2)
            z = z0 + H * (t ** 0.72) * ridge_curve
            # eave corners curl upward (where both edges are near)
            c = max(0.0, 1 - sx / 2.6) * max(0.0, 1 - sy / 2.6)
            z += upturn * c ** 1.6
            # slight sag along the eave midpoints for that tensioned look
            z += 0.18 * (1 - t) ** 2 * (abs(x) / (W / 2)) ** 2
            verts.append((x, y, z))
            if sy < sx:
                uvs.append((x * 0.42, sy * 0.42))
            else:
                uvs.append((y * 0.42, sx * 0.42))
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    o = mesh_obj(name, verts, faces, "roof", uvs=uvs)
    o.data.materials.append(mat("wood"))
    o.data.materials.append(mat("dark_wood"))
    so = o.modifiers.new("solid", "SOLIDIFY")
    so.thickness = thick
    so.offset = -1
    so.material_offset = 1
    so.material_offset_rim = 2
    so.use_even_offset = True
    smooth_shade(o, 50)
    return o


def roof_height(W, D, H, z0, x, y, upturn=0.55):
    sx = W / 2 - abs(x); sy = D / 2 - abs(y)
    s = min(sx, sy); t = s / (D / 2)
    z = z0 + H * (t ** 0.72)
    c = max(0.0, 1 - sx / 2.6) * max(0.0, 1 - sy / 2.6)
    return z + upturn * c ** 1.6 + 0.18 * (1 - t) ** 2 * (abs(x) / (W / 2)) ** 2


def ridges(W, D, H, z0, upturn=0.55, thick=0.32):
    parts = []
    rl = (W - D) / 2
    top = z0 + H
    parts.append(box("ridge", (2 * rl + 0.6, 0.55, 0.5), (0, 0, top + 0.2), "ridge", bev=0.05))
    for sx in (-1, 1):
        o = box("oni", (0.4, 0.75, 1.05), (sx * (rl + 0.35), 0, top + 0.42), "ridge", bev=0.08, seg=3)
        parts.append(o)
        for sy in (-1, 1):  # hip ridges down to the corners
            pts = []
            for k in range(26):
                u = k / 25
                x = sx * (rl + u * (W / 2 - rl - 0.15))
                y = sy * u * (D / 2 - 0.15)
                pts.append(Vector((x, y, roof_height(W, D, H, z0, x, y, upturn) + 0.12)))
            parts.append(tube("hip", pts, 0.2, "ridge", 8))
            parts.append(box("hipend", (0.3, 0.3, 0.45), (pts[-1].x, pts[-1].y, pts[-1].z + 0.12), "ridge", bev=0.05))
    return parts


def rafters(W, D, z0, inset, count_x, count_y, H):
    parts = []
    for i in range(count_x):
        x = (i / (count_x - 1) - 0.5) * (W - 1.0)
        for sy in (-1, 1):
            y0 = sy * (D / 2 - 0.15)
            y1 = sy * (D / 2 - inset)
            z_a = roof_height(W, D, H, z0, x, y0) - 0.38
            z_b = roof_height(W, D, H, z0, x, y1) - 0.38
            L = abs(y1 - y0)
            ang = math.atan2(z_b - z_a, L) * (-sy)
            parts.append(box("rafter", (0.1, L, 0.13), (x, (y0 + y1) / 2, (z_a + z_b) / 2 - 0.05), "wood", rot=(ang, 0, 0)))
    return parts


def hall():
    reset()
    parts, cols = [], []
    PW, PD = 15.0, 12.0
    pod = box("podium", (PW, PD, 1.1), (0, 0, 0.55), "masonry", bev=0.06, seg=3)
    parts.append(pod)
    cols.append(collider("podium", (PW, PD, 1.1), (0, 0, 0.55)))
    for k in range(5):  # front stone steps (Blender -Y = Godot +Z = south, facing the courtyard)
        st = box("step", (4.6, 0.42, 0.22), (0, -PD / 2 - 0.21 - (4 - k) * 0.42 + 0.0, 0.11 + k * 0.22), "granite", bev=0.03)
        parts.append(st)
    cols.append(collider("steps", (4.6, 2.6, 0.2), (0, -PD / 2 - 1.0, 0.55), rot=(math.atan2(1.1, 2.1), 0, 0)))
    FW, FD = 12.4, 9.0
    deck_z = 1.62
    parts.append(box("deck", (FW + 1.4, FD + 1.4, 0.18), (0, 0, deck_z - 0.09), "wood", bev=0.02))
    parts.append(box("skirt", (FW + 1.2, FD + 1.2, 0.5), (0, 0, 1.3), "dark_wood"))
    cols.append(collider("deck", (FW + 1.4, FD + 1.4, 0.4), (0, 0, deck_z - 0.2)))
    for k in range(3):  # wooden steps from podium up to the veranda
        parts.append(box("wstep", (3.0, 0.32, 0.12), (0, -(FD + 1.4) / 2 - 0.16 - (2 - k) * 0.3, 1.18 + k * 0.15), "wood", bev=0.01))
    cols.append(collider("wsteps", (3.0, 1.2, 0.2), (0, -(FD + 1.4) / 2 - 0.4, 1.35), rot=(math.atan2(0.45, 0.9), 0, 0)))
    xs = [-6.0, -3.0, 0.0, 3.0, 6.0]
    ys = [-4.0, -1.33, 1.33, 4.0]
    top = deck_z + 4.0
    for x in xs:
        for y in ys:
            parts.append(cyl("post", 0.21, 0.2, top - deck_z, (x, y, (top + deck_z) / 2), "lacquer", 20, bev=0.0))
            parts.append(cyl("base", 0.26, 0.28, 0.12, (x, y, deck_z + 0.06), "black_lacquer", 20))
            # bracket set (masugumi)
            parts.append(box("masu", (0.55, 0.55, 0.26), (x, y, top + 0.13), "wood", bev=0.02))
            parts.append(box("hijiki", (1.4, 0.24, 0.2), (x, y, top + 0.36), "wood", bev=0.02))
            parts.append(box("hijiki2", (0.24, 1.4, 0.2), (x, y, top + 0.36), "wood", bev=0.02))
            parts.append(box("masu2", (0.42, 0.42, 0.2), (x, y, top + 0.56), "wood", bev=0.02))
    for z, h in ((deck_z + 1.0, 0.18), (top - 0.15, 0.3)):
        for y in (ys[0], ys[-1]):
            parts.append(box("nageshi", (12.6, 0.26, h), (0, y, z), "lacquer", bev=0.015))
        for x in (xs[0], xs[-1]):
            parts.append(box("nageshi", (0.26, 8.6, h), (x, 0, z), "lacquer", bev=0.015))
    parts.append(box("keta", (13.6, 9.6, 0.3), (0, 0, top + 0.8), "wood", bev=0.03))
    # walls: plaster on sides/back with dark timber framing; shoji screens across the front
    for i in range(4):
        xa, xb = xs[i], xs[i + 1]
        cx = (xa + xb) / 2
        parts.append(box("wall_back", (2.6, 0.12, 2.9), (cx, ys[-1], deck_z + 1.95), "plaster"))
        parts.append(box("koshi_back", (2.6, 0.16, 0.6), (cx, ys[-1], deck_z + 0.3), "dark_wood"))
        if i in (1, 2):
            sh = box("shoji_front", (2.6, 0.08, 2.75), (cx, ys[0] + 0.05, deck_z + 1.38), "shoji")
            parts.append(sh)
        else:
            parts.append(box("wall_front", (2.6, 0.12, 2.9), (cx, ys[0], deck_z + 1.95), "plaster"))
            parts.append(box("koshi_front", (2.6, 0.16, 0.6), (cx, ys[0], deck_z + 0.3), "dark_wood"))
        parts.append(box("ranma", (2.6, 0.1, 0.55), (cx, ys[0], top - 0.55), "dark_wood"))
    for j in range(3):
        ya, yb = ys[j], ys[j + 1]
        for x in (xs[0], xs[-1]):
            parts.append(box("wall_side", (0.12, 2.5, 2.9), (x, (ya + yb) / 2, deck_z + 1.95), "plaster"))
            parts.append(box("koshi_side", (0.16, 2.5, 0.6), (x, (ya + yb) / 2, deck_z + 0.3), "dark_wood"))
    cols.append(collider("walls", (12.2, 8.2, 4), (0, 0, deck_z + 2)))
    # veranda railing (kōran)
    rx, ry = (FW + 1.2) / 2, (FD + 1.2) / 2
    def rail(p0, p1):
        d = p1 - p0
        L = d.length
        ang = math.atan2(d.y, d.x)
        mid = (p0 + p1) / 2
        parts.append(box("rail", (L, 0.12, 0.1), (mid.x, mid.y, deck_z + 0.85), "lacquer", rot=(0, 0, ang), bev=0.01))
        parts.append(box("rail2", (L, 0.08, 0.08), (mid.x, mid.y, deck_z + 0.45), "lacquer", rot=(0, 0, ang)))
        n = max(2, int(L / 1.2))
        for k in range(n + 1):
            p = p0 + d * (k / n)
            parts.append(box("rpost", (0.13, 0.13, 0.9), (p.x, p.y, deck_z + 0.45), "lacquer"))
    rail(Vector((-rx, -ry, 0)), Vector((-1.6, -ry, 0)))
    rail(Vector((1.6, -ry, 0)), Vector((rx, -ry, 0)))
    rail(Vector((rx, -ry, 0)), Vector((rx, ry, 0)))
    rail(Vector((-rx, -ry, 0)), Vector((-rx, ry, 0)))
    rail(Vector((-rx, ry, 0)), Vector((rx, ry, 0)))
    for sx in (-1.6, 1.6):
        parts.append(cyl("giboshi_post", 0.09, 0.09, 1.0, (sx, -ry, deck_z + 0.5), "lacquer", 12))
        parts.append(lathe("giboshi", [(0.0, 0.0), (0.1, 0.02), (0.13, 0.1), (0.1, 0.2), (0.04, 0.28), (0.0, 0.34)], 16, "gold", loc=(sx, -ry, deck_z + 1.0)))
    # roof
    RW, RD, RH, rz = 19.0, 14.0, 4.6, top + 0.95
    parts.append(roof_mesh("roof", RW, RD, RH, rz))
    parts += ridges(RW, RD, RH, rz)
    parts += rafters(RW, RD, rz, 2.6, 30, 0, RH)
    # gable (irimoya) triangles at the ridge ends, set slightly into the roof
    rl = (RW - RD) / 2
    for sx in (-1, 1):
        x = sx * (rl + 0.1)
        verts = [(x, -1.6, rz + RH - 1.65), (x, 1.6, rz + RH - 1.65), (x, 0, rz + RH + 0.1)]
        g = mesh_obj("gable", verts, [(0, 1, 2) if sx > 0 else (2, 1, 0)], "lacquer")
        s = g.modifiers.new("s", "SOLIDIFY"); s.thickness = 0.12
        parts.append(g)
        parts.append(box("gegyo", (0.12, 0.5, 0.7), (x - sx * 0.05, 0, rz + RH - 0.55), "gold", bev=0.02))
    # shimenawa across the central bays + shide papers + bell
    pts = []
    for k in range(31):
        u = k / 30
        x = (u - 0.5) * 6.2
        pts.append(Vector((x, ys[0] - 0.55, top - 0.75 - 0.55 * math.sin(u * math.pi))))
    radii = [0.11 + 0.17 * math.sin(k / 30 * math.pi) for k in range(31)]
    parts.append(tube("rope", pts, 0.2, "rope", 12, radii))
    for k in range(5):
        u = (k + 1) / 6
        p = pts[int(u * 30)]
        verts, faces = [], []
        w = 0.1
        for j in range(6):
            zz = p.z - 0.2 - j * 0.12
            xx = p.x + (0.06 if j % 2 else -0.06)
            verts += [(xx - w, p.y - 0.02, zz), (xx + w, p.y - 0.02, zz)]
        for j in range(5):
            faces.append((j * 2, j * 2 + 1, j * 2 + 3, j * 2 + 2))
        sh = mesh_obj("shide", verts, faces, "paper")
        parts.append(sh)
    parts.append(lathe("suzu", [(0.0, 0.0), (0.16, 0.05), (0.22, 0.2), (0.18, 0.35), (0.06, 0.42), (0.0, 0.44)], 20, "gold", loc=(0, ys[0] - 0.9, top - 1.9)))
    parts.append(cyl("suzu_rope", 0.04, 0.04, 1.4, (0, ys[0] - 0.9, top - 2.2 - 0.7 + 0.3), "rope", 8))
    # offering box
    sb = box("saisen", (1.8, 0.8, 0.8), (0, -ry - 0.7, deck_z - 0.15), "wood", bev=0.02)
    parts.append(sb)
    for k in range(7):
        parts.append(box("slat", (1.7, 0.05, 0.05), (0, -ry - 1.05 + k * 0.1, deck_z + 0.27), "dark_wood"))
    # hanging bronze lanterns at the front corners
    for sx in (-1, 1):
        parts.append(cyl("tsuri_chain", 0.015, 0.015, 0.8, (sx * 5.4, -RD / 2 + 1.0, top + 0.6), "bronze", 6))
        parts.append(lathe("tsuri", [(0.0, 0.0), (0.12, 0.02), (0.16, 0.25), (0.16, 0.45), (0.3, 0.5), (0.05, 0.68), (0.0, 0.7)], 6, "bronze", loc=(sx * 5.4, -RD / 2 + 1.0, top - 0.5)))
        parts.append(cyl("tsuri_glow", 0.1, 0.1, 0.18, (sx * 5.4, -RD / 2 + 1.0, top - 0.15), "lantern_glow", 8))
    o = join(parts, "hall")
    export("hall.glb", [o] + cols)


def bridge():
    reset()
    parts, cols = [], []
    L = 18.0
    W = 2.6
    Hc = 1.2
    def deck_z(y):
        u = y / (L / 2)
        return 0.15 + Hc * (1 - u * u)
    n = 44
    for k in range(n):
        y0 = -L / 2 + k * L / n
        y1 = y0 + L / n * 0.98
        ym = (y0 + y1) / 2
        z0, z1 = deck_z(y0), deck_z(y1)
        ang = math.atan2(z1 - z0, y1 - y0)
        pl = box("plank", (W, (y1 - y0) / math.cos(ang), 0.1), (0, ym, (z0 + z1) / 2), "wood", rot=(ang, 0, 0), bev=0.012)
        parts.append(pl)
    for sx in (-1, 1):
        pts = [Vector((sx * (W / 2 - 0.05), -L / 2 + k * L / 40, deck_z(-L / 2 + k * L / 40) - 0.22)) for k in range(41)]
        b = tube("stringer", pts, 0.16, "lacquer", 4)
        parts.append(b)
        # railing: curved top rail following the arch, posts with finials at the ends
        rp = [Vector((sx * (W / 2 + 0.05), -L / 2 + 0.4 + k * (L - 0.8) / 40, deck_z(-L / 2 + 0.4 + k * (L - 0.8) / 40) + 0.85)) for k in range(41)]
        parts.append(tube("toprail", rp, 0.065, "lacquer", 8))
        rp2 = [p - Vector((0, 0, 0.45)) for p in rp]
        parts.append(tube("midrail", rp2, 0.04, "lacquer", 6))
        for k in range(11):
            y = -L / 2 + 0.4 + k * (L - 0.8) / 10
            z = deck_z(y)
            parts.append(box("rpost", (0.14, 0.14, 1.0), (sx * (W / 2 + 0.05), y, z + 0.42), "lacquer", bev=0.01))
        for y in (-L / 2 + 0.4, L / 2 - 0.4):
            parts.append(lathe("giboshi", [(0.0, 0.0), (0.1, 0.02), (0.14, 0.11), (0.1, 0.22), (0.04, 0.3), (0.0, 0.37)], 16, "gold", loc=(sx * (W / 2 + 0.05), y, deck_z(y) + 0.92)))
    for y in (-4.2, 0.0, 4.2):  # piers into the pond
        for sx in (-1, 1):
            z = deck_z(y)
            parts.append(cyl("pier", 0.13, 0.13, z + 1.2, (sx * 0.9, y, (z - 1.2) / 2 - 0.1), "lacquer", 16))
        parts.append(box("crossbeam", (2.4, 0.18, 0.2), (0, y, deck_z(y) - 0.35), "lacquer"))
    o = join(parts, "bridge")
    # smooth walkable collision strip + rail walls
    verts, faces = [], []
    for k in range(41):
        y = -L / 2 - 0.6 + k * (L + 1.2) / 40
        z = deck_z(max(-L / 2, min(L / 2, y))) + 0.05
        verts += [(-W / 2, y, z), (W / 2, y, z), (-W / 2, y, z - 0.4), (W / 2, y, z - 0.4)]
    for k in range(40):
        a = k * 4
        faces += [(a, a + 1, a + 5, a + 4), (a + 2, a + 6, a + 7, a + 3)]
    c = mesh_obj("deck-colonly", verts, faces, "wood")
    cols.append(c)
    for sx in (-1, 1):
        cols.append(collider("rail", (0.2, L, 3.0), (sx * (W / 2 + 0.1), 0, 1.6)))
    export("bridge.glb", [o] + cols)


def bell_pavilion():
    reset()
    parts, cols = [], []
    plinth = box("plinth", (4.6, 4.6, 0.5), (0, 0, 0.25), "masonry", bev=0.05, seg=3)
    parts.append(plinth)
    cols.append(collider("plinth", (4.6, 4.6, 0.5), (0, 0, 0.25)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = cyl("post", 0.17, 0.15, 3.8, (sx * 1.6, sy * 1.6, 2.4), "lacquer", 18)
            p.rotation_euler = (sy * math.radians(2), -sx * math.radians(2), 0)
            parts.append(p)
            parts.append(box("pbase", (0.5, 0.5, 0.25), (sx * 1.6, sy * 1.6, 0.6), "granite", bev=0.03))
            cols.append(collider("post", (0.35, 0.35, 4), (sx * 1.6, sy * 1.6, 2.5)))
    for z in (1.6, 4.1):
        for sx in (-1, 1):
            parts.append(box("beam", (0.2, 3.6, 0.22), (sx * 1.6, 0, z), "lacquer", bev=0.01))
            parts.append(box("beam", (3.6, 0.2, 0.22), (0, sx * 1.6, z), "lacquer", bev=0.01))
    parts.append(box("crossbeam", (3.8, 0.3, 0.3), (0, 0, 4.3), "wood", bev=0.02))
    parts.append(roof_mesh("roof", 6.2, 6.2, 2.0, 4.55, res=(40, 40), upturn=0.4, thick=0.25))
    parts.append(lathe("finial", [(0.0, 0.0), (0.25, 0.0), (0.2, 0.25), (0.08, 0.5), (0.0, 0.6)], 12, "bronze", loc=(0, 0, 6.5)))
    parts.append(lathe("bell", [(0.0, 3.85), (0.22, 3.85), (0.36, 3.75), (0.44, 3.3), (0.5, 2.75), (0.6, 2.55), (0.6, 2.5), (0.5, 2.5)], 32, "bronze"))
    for k in range(4):  # bell bands
        parts.append(lathe("band", [(0.47 + k * 0.01, 3.35 - k * 0.22), (0.5 + k * 0.012, 3.32 - k * 0.22), (0.47 + k * 0.01, 3.29 - k * 0.22)], 32, "bronze"))
    parts.append(cyl("striker", 0.1, 0.1, 1.6, (0, -1.0, 2.9), "wood", 12, rot=(0, math.pi / 2, 0)))
    for sx in (-0.5, 0.5):
        parts.append(cyl("str_rope", 0.015, 0.015, 1.3, (sx, -1.0, 3.6), "rope", 6))
    o = join(parts, "bell_pavilion")
    export("bell_pavilion.glb", [o] + cols)


def azumaya():
    reset()
    parts, cols = [], []
    parts.append(box("floor", (4.2, 4.2, 0.35), (0, 0, 0.17), "granite", bev=0.04))
    cols.append(collider("floor", (4.2, 4.2, 0.35), (0, 0, 0.17)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(cyl("post", 0.13, 0.12, 2.9, (sx * 1.7, sy * 1.7, 1.8), "wood", 14))
            cols.append(collider("post", (0.3, 0.3, 3), (sx * 1.7, sy * 1.7, 1.8)))
    for sx in (-1, 1):
        parts.append(box("beam", (0.16, 3.7, 0.18), (sx * 1.7, 0, 3.15), "wood", bev=0.01))
        parts.append(box("beam", (3.7, 0.16, 0.18), (0, sx * 1.7, 3.15), "wood", bev=0.01))
    for sy in (1,):
        parts.append(box("bench", (3.2, 0.5, 0.08), (0, sy * 1.35, 0.8), "wood", bev=0.01))
        parts.append(box("benchleg", (0.1, 0.4, 0.45), (-1.4, sy * 1.35, 0.57), "wood"))
        parts.append(box("benchleg", (0.1, 0.4, 0.45), (1.4, sy * 1.35, 0.57), "wood"))
    parts.append(roof_mesh("roof", 5.6, 5.6, 1.7, 3.25, res=(36, 36), upturn=0.3, thick=0.22))
    parts.append(lathe("finial", [(0.0, 0.0), (0.18, 0.0), (0.14, 0.2), (0.05, 0.38), (0.0, 0.45)], 12, "bronze", loc=(0, 0, 4.9)))
    o = join(parts, "azumaya")
    export("azumaya.glb", [o] + cols)


def pagoda():
    """Five-storey pagoda for the far ridge (seen across the valley from the overlook)."""
    reset()
    parts = []
    parts.append(box("podium", (9.0, 9.0, 1.4), (0, 0, 0.7), "masonry", bev=0.06))
    z = 1.4
    w = 6.0
    for tier in range(5):
        h = 2.6 if tier == 0 else 2.0
        parts.append(box("body", (w, w, h), (0, 0, z + h / 2), "lacquer"))
        parts.append(box("panel", (w * 0.55, w + 0.04, h * 0.6), (0, 0, z + h * 0.45), "plaster"))
        parts.append(box("panel", (w + 0.04, w * 0.55, h * 0.6), (0, 0, z + h * 0.45), "plaster"))
        for sx in (-1, 1):
            for sy in (-1, 1):
                parts.append(box("post", (0.4, 0.4, h), (sx * w / 2, sy * w / 2, z + h / 2), "lacquer"))
        parts.append(box("band", (w + 0.3, w + 0.3, 0.35), (0, 0, z + h - 0.2), "lacquer"))
        rw = w + 3.6
        parts.append(roof_mesh("roof", rw, rw, 1.3, z + h, res=(30, 30), upturn=0.55, thick=0.28))
        z += h + 0.9
        w *= 0.84
    parts.append(cyl("sorin", 0.12, 0.08, 6.0, (0, 0, z + 3.0), "bronze", 10))
    for k in range(9):
        parts.append(cyl("ring", 0.5 - k * 0.03, 0.5 - k * 0.03, 0.12, (0, 0, z + 0.8 + k * 0.5), "bronze", 16))
    parts.append(lathe("hoju", [(0.0, 0.0), (0.25, 0.05), (0.28, 0.25), (0.12, 0.5), (0.0, 0.7)], 12, "gold", loc=(0, 0, z + 6.0)))
    o = join(parts, "pagoda")
    export("pagoda.glb", [o])


def rocks():
    reset()
    objs = []
    rnd = random.Random(4)
    for v in range(6):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=1.0, location=(v * 4.0, 0, 0))
        o = bpy.context.active_object
        o.name = "rock%d" % v
        o.data.materials.append(mat("granite"))
        o.scale = (rnd.uniform(0.9, 1.5), rnd.uniform(0.8, 1.3), rnd.uniform(0.45, 0.8))
        activate(o)
        bpy.ops.object.transform_apply(scale=True, location=False)
        # large fractured planes (voronoi), then medium lumps, then fine chisel detail
        t = bpy.data.textures.new("rv%d" % v, "VORONOI")
        t.noise_scale = rnd.uniform(0.55, 0.85)
        t.distance_metric = "MINKOVSKY_FOUR"
        d = o.modifiers.new("d1", "DISPLACE"); d.texture = t; d.strength = 0.45; d.mid_level = 0.6
        t2 = bpy.data.textures.new("rc%d" % v, "CLOUDS"); t2.noise_scale = 0.35; t2.noise_depth = 3
        d2 = o.modifiers.new("d2", "DISPLACE"); d2.texture = t2; d2.strength = 0.16
        t3 = bpy.data.textures.new("rf%d" % v, "VORONOI"); t3.noise_scale = 0.12
        d3 = o.modifiers.new("d3", "DISPLACE"); d3.texture = t3; d3.strength = 0.05
        dec = o.modifiers.new("dec", "DECIMATE"); dec.ratio = 0.3
        apply_mods(o)
        # flatten the buried base
        for vtx in o.data.vertices:
            if vtx.co.z < -0.15:
                vtx.co.z = -0.15 - (vtx.co.z + 0.15) * 0.15
        o.location = (0, 0, 0)
        smooth_shade(o, 28)  # crisp fracture edges, soft within faces
        objs.append(o)
    for o in objs:
        o.location = (0, 0, 0)
    export("rocks.glb", objs)


# ------------------------------------------------------------------ trees
def grow(skel, p, d, length, radius, level, maxlev, rnd, params, tips):
    seg = params["seg"]
    pts = [p]
    dd = d.copy()
    for s in range(seg):
        dd = (dd + Vector((rnd.gauss(0, params["wobble"]), rnd.gauss(0, params["wobble"]), params["up"]))).normalized()
        pts.append(pts[-1] + dd * (length / seg))
    r0 = radius
    for i in range(len(pts) - 1):
        r = r0 * (1 - 0.55 * (i + 1) / seg)
        skel.append((pts[i], pts[i + 1], r0 * (1 - 0.55 * i / seg), r))
    end = pts[-1]
    if level >= maxlev:
        tips.append((end, dd))
        return
    nb = params["branches"][level]
    for b in range(nb):
        t = rnd.uniform(params["start"], 1.0) if b < nb - 1 else 1.0
        idx = min(int(t * seg), seg)
        origin = pts[idx]
        axis = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)).normalized()
        spread = params["spread"][level]
        nd = (dd * math.cos(spread) + axis * math.sin(spread) + Vector((0, 0, params["lift"]))).normalized()
        grow(skel, origin, nd, length * params["decay"] * rnd.uniform(0.8, 1.1), r0 * (1 - 0.55 * idx / seg) * params["rdecay"], level + 1, maxlev, rnd, params, tips)
        if level >= params.get("midlevel", 1) and rnd.random() < params.get("midtips", 0):
            tips.append((pts[max(1, idx)], nd))


def skeleton_mesh(name, skel, matname, target=8000, min_r=0.035):
    """Turn skeleton segments into a skin-modifier mesh -> organic trunk (decimated to budget)."""
    skel = [s for s in skel if s[2] >= min_r]
    verts, edges, radii = [], [], []
    index = {}
    def vid(p, r):
        key = (round(p.x, 3), round(p.y, 3), round(p.z, 3))
        if key not in index:
            index[key] = len(verts); verts.append(p); radii.append(r)
        return index[key]
    for (a, b, ra, rb) in skel:
        ia = vid(a, ra); ib = vid(b, rb)
        if ia != ib:
            edges.append((ia, ib))
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], edges, [])
    o = bpy.data.objects.new(name, me)
    link(o)
    o.modifiers.new("skin", "SKIN")
    for i, r in enumerate(radii):
        o.data.skin_vertices[0].data[i].radius = (max(r, 0.015), max(r, 0.015))
    o.data.skin_vertices[0].data[0].use_root = True
    s = o.modifiers.new("sub", "SUBSURF"); s.levels = 1; s.render_levels = 1
    t = bpy.data.textures.new("bk_" + name, "CLOUDS"); t.noise_scale = 0.35
    d = o.modifiers.new("d", "DISPLACE"); d.texture = t; d.strength = 0.05
    o.data.materials.append(mat(matname))
    apply_mods(o)
    nf = len(o.data.polygons)
    if nf > target:
        dec = o.modifiers.new("dec", "DECIMATE"); dec.ratio = target / nf
        apply_mods(o)
    smooth_shade(o, 80)
    print("trunk", name, nf, "->", len(o.data.polygons))
    return o


def foliage_cards(name, tips, matname, center, size, per, rnd, spread, extra=None):
    verts, faces, uvs, norms, aos = [], [], [], [], []
    pts = list(tips) + (extra or [])
    maxd = max([(p - center).length for (p, _) in pts] + [1.0])
    for (p, d) in pts:
        for k in range(per):
            c = p + Vector((rnd.gauss(0, spread), rnd.gauss(0, spread), rnd.gauss(0, spread * 0.6)))
            s = size * rnd.uniform(0.75, 1.25)
            nrm = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1))).normalized()
            t1 = nrm.cross(Vector((0, 0, 1)))
            if t1.length < 0.1:
                t1 = Vector((1, 0, 0))
            t1.normalize()
            t2 = nrm.cross(t1).normalized()
            rot = rnd.uniform(0, TAU)
            a1 = t1 * math.cos(rot) + t2 * math.sin(rot)
            a2 = nrm.cross(a1).normalized()
            base = len(verts)
            for (u, v) in ((0, 0), (1, 0), (1, 1), (0, 1)):
                verts.append(c + a1 * (u - 0.5) * s + a2 * (v - 0.5) * s)
                uvs.append((u, v))
            faces.append((base, base + 1, base + 2, base + 3))
            # soft canopy lighting: normals point away from the crown centre
            out = (c - center)
            out.z *= 0.6
            out = (out.normalized() * 0.75 + Vector((0, 0, 0.45))).normalized()
            norms += [out] * 4
            dd = (c - center)
            dd.z *= 0.7
            ao = 0.35 + 0.65 * min(1.0, (dd.length / maxd) ** 1.3)
            aos += [ao] * 4
    o = mesh_obj(name, verts, faces, matname, uvs=uvs)
    me = o.data
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, a in enumerate(aos):
        ca.data[i].color = (a, a, a, 1.0)
    loop_normals = [norms[l.vertex_index] for l in me.loops]
    try:
        me.use_auto_smooth = True
    except Exception:
        pass
    me.normals_split_custom_set(loop_normals)
    return o


# broad, layered, spreading crown: near-horizontal limbs, lobed clusters with gaps
SAKURA = dict(seg=6, wobble=0.2, up=0.02, branches=[4, 3, 3, 2], start=0.7, spread=[1.0, 0.95, 0.8, 0.7], lift=0.06, decay=0.78, rdecay=0.6, midtips=0.25, midlevel=2)
MAPLE = dict(seg=5, wobble=0.22, up=0.02, branches=[4, 3, 3], start=0.6, spread=[1.05, 0.9, 0.75], lift=0.04, decay=0.8, rdecay=0.6, midtips=0.3, midlevel=2)


def broadleaf(name, params, trunk_len, trunk_r, lean, leafmat, card, per, seed, lev=3, target=9000, spread_k=0.35):
    rnd = random.Random(seed)
    skel, tips = [], []
    d = Vector((math.sin(lean), 0.0, math.cos(lean))).normalized()
    grow(skel, Vector((0, 0, -0.3)), d, trunk_len, trunk_r, 0, lev, rnd, params, tips)
    # flared root buttresses
    for k in range(5):
        a = TAU * k / 5 + rnd.uniform(-0.3, 0.3)
        skel.append((Vector((0, 0, 0.6)), Vector((math.cos(a) * trunk_r * 2.6, math.sin(a) * trunk_r * 2.6, -0.25)), trunk_r * 0.7, trunk_r * 0.25))
    trunk = skeleton_mesh(name + "_trunk", skel, "bark", target, min_r=trunk_r * 0.06)
    c = Vector((0, 0, 0))
    for (p, _) in tips:
        c += p
    c /= max(1, len(tips))
    leaves = foliage_cards(name + "_leaves", tips, leafmat, c, card, per, rnd, card * spread_k)
    return trunk, leaves


def cedar(name, height_m, seed):
    rnd = random.Random(seed)
    skel, tips = [], []
    pts = [Vector((0, 0, -0.5))]
    for k in range(12):
        pts.append(pts[-1] + Vector((rnd.gauss(0, 0.06), rnd.gauss(0, 0.06), height_m / 12)))
    base_r = 0.032 * height_m + 0.1
    for i in range(len(pts) - 1):
        skel.append((pts[i], pts[i + 1], base_r * (1 - i / 12) ** 0.9 + 0.04, base_r * (1 - (i + 1) / 12) ** 0.9 + 0.03))
    for k in range(4):
        a = TAU * k / 4 + rnd.uniform(-0.4, 0.4)
        skel.append((Vector((0, 0, 0.7)), Vector((math.cos(a) * base_r * 2.4, math.sin(a) * base_r * 2.4, -0.3)), base_r * 0.6, base_r * 0.2))
    leaf_pts = []
    branches = []
    z = height_m * 0.32
    while z < height_m * 0.98:
        u = (z - height_m * 0.32) / (height_m * 0.68)
        reach = (1 - u) ** 0.9 * height_m * 0.17 + 0.6
        nb = 4 if u < 0.7 else 3
        for b in range(nb):
            a = rnd.uniform(0, TAU)
            o = Vector((rnd.gauss(0, 0.05), rnd.gauss(0, 0.05), z))
            e = o + Vector((math.cos(a) * reach, math.sin(a) * reach, reach * 0.15 - 0.3))
            if reach > 1.0:
                branches.append((o, e, base_r * 0.16 * (1 - u) + 0.035, 0.025))
            leaf_pts.append((e, (e - o).normalized()))
            leaf_pts.append((o.lerp(e, 0.55), (e - o).normalized()))
        z += rnd.uniform(0.55, 0.95)
    leaf_pts.append((Vector((0, 0, height_m)), Vector((0, 0, 1))))
    trunk = skeleton_mesh(name + "_trunk", skel, "bark", 3000, min_r=0.02)
    tubes = []
    for (o, e, r0, r1) in branches:
        mid = o.lerp(e, 0.5) + Vector((0, 0, 0.15))
        tubes.append(tube("br", [o, mid, e], r0, "bark", 5, [r0, (r0 + r1) / 2, r1]))
    if tubes:
        trunk = join([trunk] + tubes, name + "_trunk")
    leaves = foliage_cards(name + "_leaves", leaf_pts, "needles", Vector((0, 0, height_m * 0.6)), 1.7, 6, rnd, 0.5)
    return trunk, leaves


def trees():
    reset()
    objs = []
    for i, (seed, lean, tl, tr) in enumerate([(3, 0.2, 3.9, 0.32), (9, -0.16, 3.5, 0.28)]):
        t, l = broadleaf("sakura%d" % i, SAKURA, tl, tr, lean, "blossom", 1.5, 8, seed, 4, 9000, 0.45)
        objs += [t, l]
    t, l = broadleaf("maple0", MAPLE, 2.8, 0.2, 0.15, "maple", 1.3, 11, 21, 3, 6000, 0.45)
    objs += [t, l]
    for i, (h, seed) in enumerate([(20.0, 5), (16.0, 8), (24.0, 13)]):
        t, l = cedar("cedar%d" % i, h, seed)
        objs += [t, l]
    # the ancient sacred camphor tree
    big = dict(seg=7, wobble=0.15, up=0.04, branches=[5, 3, 3, 2], start=0.4, spread=[0.95, 0.8, 0.7, 0.6], lift=0.12, decay=0.66, rdecay=0.55, midtips=0.5)
    t, l = broadleaf("sacred", big, 4.8, 1.05, 0.05, "leaves", 2.3, 12, 77, 4, 16000)
    rope_pts = [Vector((math.cos(a) * 1.25, math.sin(a) * 1.25, 2.4 + 0.15 * math.sin(a * 2))) for a in np.linspace(0, TAU, 40)]
    rope = tube("sacred_rope", rope_pts, 0.13, "rope", 10)
    objs += [t, l, rope]
    for o in objs:
        o.location = (0, 0, 0)
    export("trees.glb", objs)


# ------------------------------------------------------------------ world (terrain, stairs, paving)
def terrain():
    reset()
    step = 0.8
    xs = np.arange(LY.X0, LY.X1 + 0.01, step)
    zs = np.arange(LY.Z0, LY.Z1 + 0.01, step)
    X, Z = np.meshgrid(xs, zs)
    Y = LY.height(X, Z)
    S = LY.splat(X, Z)
    nx, nz = len(xs), len(zs)
    verts = [G(X[j, i], Y[j, i], Z[j, i]) for j in range(nz) for i in range(nx)]
    faces = []
    for j in range(nz - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + nx, a + nx + 1, a + 1))
    o = mesh_obj("terrain-col", verts, faces, "terrain")
    me = o.data
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    flat = S.reshape(-1, 3)
    for i, c in enumerate(flat):
        col.data[i].color = (float(c[0]), float(c[1]), float(c[2]), 1.0)
    smooth_shade(o, 180)
    # far terrain: coarse skirt reaching the horizon (no collision)
    step2 = 8.0
    xs2 = np.arange(-600, 600.1, step2)
    zs2 = np.arange(-700, 400.1, step2)
    X2, Z2 = np.meshgrid(xs2, zs2)
    inner = (X2 > LY.X0 + 6) & (X2 < LY.X1 - 6) & (Z2 > LY.Z0 + 6) & (Z2 < LY.Z1 - 6)
    Y2 = LY.far_height(X2, Z2)
    Y2 = np.where(inner, Y2 - 3.0, Y2)
    n2x, n2z = len(xs2), len(zs2)
    v2 = [G(X2[j, i], Y2[j, i], Z2[j, i]) for j in range(n2z) for i in range(n2x)]
    f2 = []
    for j in range(n2z - 1):
        for i in range(n2x - 1):
            if inner[j, i] and inner[j + 1, i + 1] and inner[j, i + 1] and inner[j + 1, i]:
                continue
            a = j * n2x + i
            f2.append((a, a + n2x, a + n2x + 1, a + 1))
    o2 = mesh_obj("far_terrain", v2, f2, "terrain")
    c2 = o2.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i in range(len(v2)):
        c2.data[i].color = (0.0, 0.2, 0.0, 1.0)
    smooth_shade(o2, 180)
    # distant mountain ranges (layered silhouettes for aerial perspective)
    mts = []
    rr = random.Random(2)
    for layer, (dist, hgt, seg) in enumerate([(900, 170, 140), (1500, 300, 120), (2400, 520, 100)]):
        verts, faces = [], []
        for k in range(seg + 1):
            a = math.radians(-200 + 230 * k / seg)  # arc from south-west round the north to the east
            prof = 0.0
            for o_ in range(5):
                prof += math.sin(a * (3 + o_ * 4.7) + layer * 1.7 + o_) * (0.5 ** o_)
            h = hgt * (0.55 + 0.45 * prof) + rr.uniform(-8, 8)
            x = math.cos(a) * dist; z = math.sin(a) * dist - 40
            verts.append(G(x, -60, z)); verts.append(G(x, h, z))
        for k in range(seg):
            faces.append((k * 2, k * 2 + 2, k * 2 + 3, k * 2 + 1))
        m = mesh_obj("mountains%d" % layer, verts, faces, "mountain")
        mc = m.data.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i in range(len(verts)):
            mc.data[i].color = (layer / 2.0, 0, 0, 1)
        mts.append(m)
    export("terrain.glb", [o, o2] + mts)


def stairs_and_paving():
    reset()
    rnd = random.Random(12)
    parts, cols = [], []
    flights = [(-6.0, -16.0, 0.0), (-18.0, -28.0, 4.0), (-30.0, -40.0, 8.0)]
    for (za, zb, y0) in flights:
        n = 25
        tread = (za - zb) / n
        for k in range(n):
            z = za - (k + 0.5) * tread
            top = y0 + (k + 1) * 0.16
            w = 3.3 + rnd.uniform(-0.06, 0.06)
            b = box("step", (w, tread + 0.08, 0.34), G(rnd.uniform(-0.03, 0.03), top - 0.17, z), "granite",
                    rot=(rnd.uniform(-0.01, 0.01), rnd.uniform(-0.012, 0.012), rnd.uniform(-0.015, 0.015)), bev=0.035, seg=2)
            weather(b, 0.012, 0.2, 1)
            parts.append(b)
        # side curbs (stepped masonry) following the flight
        L = za - zb
        ang = math.atan2(4.0, L)
        for sx in (-1, 1):
            c = box("curb", (0.55, math.sqrt(L * L + 16), 0.55), G(sx * 1.95, y0 + 2.0 + 0.1, (za + zb) / 2), "masonry", rot=(ang, 0, 0), bev=0.05)
            parts.append(c)
        ramp_len = math.sqrt(L * L + 16)
        cols.append(collider("ramp", (3.4, ramp_len, 0.3), G(0, y0 + 2.0 - 0.07, (za + zb) / 2), rot=(ang, 0, 0)))
        for sx in (-1, 1):
            cols.append(collider("curbwall", (0.5, ramp_len, 2.5), G(sx * 1.95, y0 + 2.8, (za + zb) / 2), rot=(ang, 0, 0)))
    # landings: big irregular pavers
    for (z0, z1, y) in [(-16.0, -18.0, 4.0), (-28.0, -30.0, 8.0)]:
        for k in range(4):
            zz = z0 - (k + 0.5) * (z0 - z1) / 4
            for sx in (-0.8, 0.8):
                p = box("paver", (1.55, 0.47, 0.25), G(sx, y - 0.12, zz), "granite", rot=(0, rnd.uniform(-0.01, 0.01), rnd.uniform(-0.02, 0.02)), bev=0.03)
                weather(p, 0.01, 0.2, 2)
                parts.append(p)
        cols.append(collider("landing", (4.0, 2.2, 0.3), G(0, y - 0.15, (z0 + z1) / 2)))
    # approach paving from the top torii to the hall (ishidatami)
    zz = -40.0
    while zz > -55.6:
        L = rnd.uniform(0.7, 1.1)
        xs = -1.25
        while xs < 1.25:
            w = min(rnd.uniform(0.6, 1.1), 1.25 - xs)
            p = box("pave", (w - 0.05, L - 0.05, 0.16), G(xs + w / 2, 12.06, zz - L / 2), "granite", rot=(0, 0, rnd.uniform(-0.02, 0.02)), bev=0.03)
            weather(p, 0.008, 0.2, 1)
            parts.append(p)
            xs += w
        zz -= L
    # garden stepping stones from the bridge to the stair foot
    z = 12.5
    while z > -5.5:
        x = float(LY.path_x(z)) + rnd.uniform(-0.25, 0.25)
        y = float(LY.height(x, z))
        r = rnd.uniform(0.38, 0.52)
        s = cyl("stone", r, r * 1.04, 0.2, G(x, y + 0.04, z), "granite", 14, rot=(0, 0, rnd.uniform(0, 3)), bev=0.04)
        s.scale = (rnd.uniform(1.0, 1.35), rnd.uniform(0.8, 1.0), 1)
        weather(s, 0.02, 0.2, 1)
        parts.append(s)
        z -= rnd.uniform(0.85, 1.05)
    o = join(parts, "stairs")
    export("stairs.glb", [o] + cols)


def boundaries():
    """Invisible walls: pond edge (gap at the bridge), overlook balustrade, world edge."""
    reset()
    cols = []
    for k in range(48):
        a0 = k / 48 * TAU; a1 = (k + 1) / 48 * TAU
        x0 = LY.POND_C[0] + math.cos(a0) * LY.POND_R[0] * 0.97; z0 = LY.POND_C[1] + math.sin(a0) * LY.POND_R[1] * 0.97
        x1 = LY.POND_C[0] + math.cos(a1) * LY.POND_R[0] * 0.97; z1 = LY.POND_C[1] + math.sin(a1) * LY.POND_R[1] * 0.97
        if abs((x0 + x1) / 2) < 1.8:
            continue
        L = math.hypot(x1 - x0, z1 - z0)
        ang = math.atan2(-(z1 - z0), x1 - x0)
        cols.append(collider("pond", (L + 0.1, 0.3, 1.2), G((x0 + x1) / 2, 0.2, (z0 + z1) / 2), rot=(0, 0, ang)))
    # world bounds
    for (cx, cz, sx, sz) in [(0, 54, 120, 1), (0, -84, 120, 1), (40, -10, 1, 150), (-38, 25, 1, 60)]:
        cols.append(collider("bound", (sx, sz, 80), G(cx, 0, cz)))
    # west cliff edge of the courtyard
    cols.append(collider("cliff", (1, 40, 8), G(-20.2, 14, -56)))
    cols.append(collider("cliff2", (20, 1, 8), G(-28, 8, -22)))
    cols.append(collider("cliff3", (1, 24, 30), G(-24, 0, -34)))
    for c in cols:
        c.data.materials.clear()
    export("bounds.glb", cols)


def balustrade():
    """Stone railing along the overlook edge."""
    reset()
    parts = []
    z = -42.0
    while z > -71.0:
        parts.append(box("post", (0.28, 0.28, 1.0), G(-19.6, 12.5, z), "granite", bev=0.03))
        parts.append(lathe("cap", [(0.0, 0.0), (0.17, 0.0), (0.2, 0.06), (0.12, 0.16), (0.0, 0.22)], 12, "granite", loc=G(-19.6, 13.0, z)))
        if z - 2.0 > -71.0:
            parts.append(box("rail", (0.16, 2.0, 0.16), G(-19.6, 12.85, z - 1.0), "granite", bev=0.02))
            parts.append(box("rail", (0.12, 2.0, 0.12), G(-19.6, 12.35, z - 1.0), "granite", bev=0.02))
        z -= 2.0
    for p in parts:
        weather(p, 0.008, 0.1)
    o = join(parts, "balustrade")
    export("balustrade.glb", [o])


ALL = dict(torii=lambda: torii(False), torii_small=lambda: torii(True), lantern=lantern, hall=hall, bridge=bridge,
           bell=bell_pavilion, azumaya=azumaya, pagoda=pagoda, rocks=rocks, trees=trees, terrain=terrain, stairs=stairs_and_paving,
           bounds=boundaries, balustrade=balustrade)

if __name__ == "__main__":
    for k, f in ALL.items():
        if ARGS and k not in ARGS:
            continue
        print("=== building", k, flush=True)
        f()
