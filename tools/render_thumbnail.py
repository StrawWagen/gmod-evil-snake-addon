import importlib.util
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

PROJECTS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FUNGUS = os.path.join(PROJECTS, "gmod-evil-fungus-addon", "tools", "render_thumbnail.py")
MAP = os.path.join(PROJECTS, "gmod-evil-fungus-addon", "renders", "gm_construct")

RADIUS = 14
SEGMENT_LENGTH = 17
SEGMENTS = 28
HEAD_SIZE = 1.2
TAIL_LENGTH = 0.3
COLOR = 9858664

SUB = 8
SIDES = 32
HEAD_RINGS = 40
SHELL = 32
CAVITY = 24
TEX_SIZE = 1024

HEAD_AT = (-2120, -1450, 0)
FACING = -120
PATH = [
    (0, 0, 38),
    (-14, -3, 42),
    (-30, -4, 38),
    (-42, -2, 24),
    (-52, 4, 0),
    (-75, -32, 0),
    (-110, -50, 0),
    (-150, -28, 0),
    (-185, 28, 0),
    (-220, 85, 0),
    (-265, 115, 0),
    (-320, 112, 0),
    (-362, 78, 0),
    (-390, 30, 0),
    (-420, -10, 0),
]
GAPE = 0.34
LIFT = 0.3
TONGUE_REACH = 2.2
TONGUE_RISE = 0.05
TONGUE_SWAY = 0.6

SUN = 4
SKY = 0.55
LAMP = 0.6
CAMERA = dict(at=(120, -100, 115), look=(-75, 28, 18), lens=37, fstop=5.6)
SIZE = (1024, 1024)
EXPOSURE = 0.1

THROAT = (120, 28, 38)
TONGUE = (230, 110, 140)
TONGUE_ROOT = (170, 60, 85)
SCLERA = (235, 215, 120)
IRIS = (215, 95, 20)
PUPIL = (8, 6, 6)

MAW, GULLET, BOWL, RIB, DARK = 0.85, 0.9, 7, 0.12, 0.1
LENGTH, HAMMER, FLAT, BOXY, SWEEP, FRONT, LIPIN, HOLLOW, CROWN = 2.3, 2.1, 0.58, 3.2, 0.35, 0.22, 0.88, 0.75, 0.25
STALK_AT, STALK_OUT, STALK, STALK_R, STALK_TIP, STALK_SEGS, BALL = 0.7, 0.8, 1.05, 0.1, 0.055, 7, 0.25
STALK_UPRIGHT, STALK_REACH, LEAN = 1.2, 1.0, 0.9
PUPIL_W, PUPIL_H, IRIS_AT = 0.22, 0.6, 0.55
TONGUE_ROOT_AT, TONGUE_LIP, TONGUE_LEAD, TONGUE_WIDTH, TONGUE_TAPER = 0.4, 2, 0.3, 0.26, 0.65
FORK, FORK_SPREAD = 0.6, 0.5
UP = Vector((0, 0, 1))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


F = load("fungus_thumb", FUNGUS)
S = F.SCALE


def unpack(v):
    return (v >> 16) & 255, (v >> 8) & 255, v & 255


def linear(c, k=1.0):
    return tuple(min(1, max(0, v * k / 255)) ** 2.2 for v in c) + (1,)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def step(a, b, x):
    t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)


def lerp(t, a, b):
    return a + (b - a) * t


def spow(v, e):
    return -((-v) ** e) if v < 0 else v ** e


def skin_texels(size):
    columns, rows, belly_w, scutes, blotch = 18, 16, 0.13, 16, 3

    def hsh(x, y):
        h = np.sin(x * 127.1 + y * 311.7) * 43758.5453
        return h - np.floor(h)

    def noise(x, y, px, py):
        ix, iy = np.floor(x), np.floor(y)
        fx, fy = x - ix, y - iy
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        x0, x1, y0, y1 = ix % px, (ix + 1) % px, iy % py, (iy + 1) % py
        a, b, c, d = hsh(x0, y0), hsh(x1, y0), hsh(x0, y1), hsh(x1, y1)
        return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy

    def pattern(u, v):
        back = np.minimum(u, 1 - u)
        wob = (noise(u * 10, v * 6, 10, 6) - 0.5) * 0.05
        y = v * blotch
        f = y - np.floor(y) - 0.5
        diamond = (back + wob) / 0.13 + np.abs(f) / 0.5
        lf = y + 0.5 - np.floor(y + 0.5) - 0.5
        lat = np.abs(back - 0.27 + wob) / 0.06 + np.abs(lf) / 0.22
        dark = np.maximum(smooth(0.9, 0.75, diamond), smooth(1, 0.8, lat))
        rim = smooth(0.7, 0.85, diamond) * smooth(1.15, 0.95, diamond)
        mottle = noise(u * 36, v * 18, 36, 18) - 0.5
        return (0.9 - 0.5 * dark + 0.2 * rim) * (1 + 0.1 * mottle)

    def scale(u, v):
        gy = v * rows
        row = np.floor(gy)
        tone = np.full(u.shape, np.nan)
        shadow = np.ones(u.shape)
        for dr in (-1, 0, 1):
            r = row + dr
            gx = u * columns + (r % 2) * 0.5
            c0 = np.floor(gx)
            for dc in (-1, 0, 1):
                c = c0 + dc
                dx, dy = gx - c - 0.5, gy - r - 0.5
                ax = np.abs(dx) / 0.62
                ay = np.where(dy < 0, -dy / 0.6, dy / 1.05)
                d = (ax ** 1.6 + ay ** 1.6) ** (1 / 1.6)
                free = np.isnan(tone)
                inside = free & (d < 1)
                cu, cv = (c + 0.5 - (r % 2) * 0.5) / columns, (r + 0.5) / rows
                base = 0.6 + 0.4 * smooth(-0.6, 0.95, dy)
                dome = 1 - 0.22 * d * d
                keel = 0.07 * smooth(0.1, 0, np.abs(dx)) * smooth(-0.3, 0.6, dy)
                lip = 0.6 + 0.4 * smooth(1, 0.86, d)
                jitter = 1 + (hsh(c % columns, r % rows) - 0.5) * 0.12
                t = (base * dome + keel) * lip * jitter * (pattern(cu % 1, cv % 1) * 0.75 + pattern(u, v) * 0.25)
                tone = np.where(inside, t, tone)
                rim = free & (d >= 1) & (d < 1.3)
                shadow = np.where(rim, np.minimum(shadow, 0.55 + 0.45 * smooth(1, 1.3, d)), shadow)
        return np.where(np.isnan(tone), 0.35, tone) * shadow

    def belly(u, v):
        s = v * scutes
        f = s - np.floor(s)
        side = np.abs(u - 0.5) / belly_w
        crease = 0.62 + 0.38 * smooth(0, 0.12, f) * smooth(1, 0.9, f)
        return (0.74 + 0.16 * f) * crease * (1 - 0.12 * side * side)

    v, u = np.mgrid[0:size, 0:size]
    u, v = (u + 0.5) / size, (v + 0.5) / size
    side = np.abs(u - 0.5)
    on_belly = smooth(belly_w + 0.03, belly_w - 0.02, side)
    top = scale(u, v)
    g = np.clip(top + (belly(u, v) - top) * on_belly, 0, 1)
    b = np.minimum(1, g * (1 + 0.05 * (1 - on_belly)))
    return np.stack([g, g, b, np.ones_like(g)], -1)


def skin_image(out):
    path = os.path.join(out, "snake_skin.png")
    img = bpy.data.images.new("SnakeSkin", TEX_SIZE, TEX_SIZE)
    img.pixels.foreach_set(skin_texels(TEX_SIZE).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def materials(img):
    def base(name, roughness, coat, sss):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = roughness
        for key, value in (("Coat Weight", coat), ("Coat Roughness", 0.2), ("Subsurface Weight", sss),
                           ("Subsurface Scale", 0.02)):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = value
        if "Subsurface Radius" in bsdf.inputs:
            bsdf.inputs["Subsurface Radius"].default_value = (0.6, 0.2, 0.15)
        col = nt.nodes.new("ShaderNodeVertexColor")
        col.layer_name = "Col"
        return m, nt, bsdf, col

    skin, nt, bsdf, col = base("SnakeSkin", 0.55, 0.1, 0.05)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Cubic"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1
    nt.links.new(col.outputs["Color"], mix.inputs["A"])
    nt.links.new(tex.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.004
    nt.links.new(tex.outputs["Color"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    flesh, nt, bsdf, col = base("SnakeFlesh", 0.3, 0.5, 0.15)
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    eye, nt, bsdf, col = base("SnakeEye", 0.12, 0.8, 0.0)
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    return skin, flesh, eye


def add_mesh(name, verts, faces, cols, mats, face_mats=None, uvs=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v * S) for v in verts], [], faces)
    me.update()
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", np.array([linear(c) for c in cols], dtype=np.float32).ravel())
    if uvs is not None:
        layer = me.uv_layers.new(name="UV")
        flat = []
        for f in uvs:
            flat.extend(f)
        layer.data.foreach_set("uv", np.array(flat, dtype=np.float32).ravel())
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    for m in mats:
        me.materials.append(m)
    if face_mats is not None:
        me.polygons.foreach_set("material_index", face_mats)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def catmull(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5


def spline(pts, sub):
    n = len(pts)
    out = []
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, n - 1)]
        for s in range(sub):
            out.append(catmull(p0, p1, p2, p3, s / sub))
    out.append(pts[-1].copy())
    return out


def profile(t, body, tail):
    start = 1 - tail
    s = 1 - min(t / start, 1) if start > 0 else 0
    u = max(0, (t - start) / tail)
    return (body + (1 - body) * s * s) * (1 - u * u)


def joints(origin, toward):
    side = UP.cross(toward)
    body, tail = 1 / max(HEAD_SIZE, 1), min(max(TAIL_LENGTH, 0.01), 1)
    ctrl = [origin + toward * a + side * b + UP * h for a, b, h in PATH]
    dense = spline(ctrl, 40)
    arc = [0.0]
    for i in range(1, len(dense)):
        arc.append(arc[-1] + (dense[i] - dense[i - 1]).length)
    total = SEGMENT_LENGTH * SEGMENTS
    if arc[-1] < total:
        raise RuntimeError("PATH is %d units long, the body needs %d" % (arc[-1], total))
    out, k = [], 0
    for i in range(SEGMENTS + 1):
        s = i * SEGMENT_LENGTH
        while arc[k + 1] < s:
            k += 1
        f = (s - arc[k]) / max(arc[k + 1] - arc[k], 1e-9)
        p = dense[k].lerp(dense[k + 1], f)
        ground = F.floor_at(p.x, p.y, origin.z + 60)
        width = RADIUS * profile(i / SEGMENTS, body, tail)
        raised = (p - origin).dot(UP)
        out.append(Vector((p.x, p.y, ground.z + max(raised, width))))
    return out


def transport(tangents):
    frames = []
    n = UP.copy()
    for t in tangents:
        n = n - t * n.dot(t)
        if n.length < 1e-4:
            n = Vector((-t.y, t.x, 0)) if abs(t.z) < 0.9 else Vector((0, -t.z, t.y))
        n.normalize()
        frames.append((n.copy(), t.cross(n)))
    return frames


def body_mesh(pts, mats, gape_dir):
    skin, flesh = mats
    R = RADIUS
    body, tail = 1 / max(HEAD_SIZE, 1), min(max(TAIL_LENGTH, 0.01), 1)
    sp = spline(pts, SUB)
    m = len(sp)
    widths = [R * profile(j / (m - 1), body, tail) for j in range(m)]
    p = sp[0]
    W = widths[0]
    dir = gape_dir

    rings = []
    ap, deep = W * MAW, W * GULLET
    for k in range(BOWL):
        phi = (1 - k / BOWL) * math.pi * 0.5
        c = math.cos(phi)
        ridge = k > 0 and k % 2 == 0
        shade = lerp(c, DARK, 0.6) * (1.25 if ridge else 1)
        z = -deep * math.sin(phi)
        r = ap * c * (1 - RIB if ridge else 1)
        rings.append(dict(p=p + dir * z, t=-dir, w=max(r, 0.01), col=tuple(v * shade for v in THROAT), v=0))
    colour = unpack(COLOR)
    along = 0
    for j in range(m):
        if j > 0:
            along += (sp[j] - sp[j - 1]).length / (2 * math.pi * max(widths[j], R * 0.25))
        a, b = sp[max(j - 1, 0)], sp[min(j + 1, m - 1)]
        rings.append(dict(p=sp[j], t=(b - a).normalized(), w=widths[j], col=colour, v=along))

    frames = transport([r["t"] for r in rings])
    verts, cols, faces, fm, uvs = [], [], [], [], []
    last = len(rings) - 1
    for j, ring in enumerate(rings[:-1]):
        n, bn = frames[j]
        for q in range(SIDES):
            a = q / SIDES * math.pi * 2
            verts.append(ring["p"] + (n * math.cos(a) + bn * math.sin(a)) * ring["w"])
            cols.append(ring["col"])
    tip = len(verts)
    verts.append(rings[last]["p"])
    cols.append(colour)
    for j in range(last):
        mat = 0 if j >= BOWL else 1
        v0, v1 = rings[j]["v"], rings[j + 1]["v"]
        for q in range(SIDES):
            q2 = (q + 1) % SIDES
            u0, u1 = q / SIDES, (q + 1) / SIDES
            if j + 1 == last:
                faces.append((j * SIDES + q, j * SIDES + q2, tip))
                uvs.append(((u0, v0), (u1, v0), ((u0 + u1) / 2, v1)))
            else:
                faces.append((j * SIDES + q, j * SIDES + q2, (j + 1) * SIDES + q2, (j + 1) * SIDES + q))
                uvs.append(((u0, v0), (u1, v0), (u1, v1), (u0, v1)))
            fm.append(mat)
    add_mesh("Body", verts, faces, cols, [skin, flesh], fm, uvs)
    return p, dir, W


def head_shape(u, W):
    wide, flat = step(0.15, 0.55, u), step(0, 0.5, u)
    v = max(0, (u - (1 - FRONT)) / FRONT)
    a = W * lerp(wide, 1, HAMMER) * (1 - 0.3 * v * v)
    b = W * lerp(flat, 1, FLAT) * math.sqrt(max(1 - v * v, 0))
    return a, b, lerp(flat, 2, BOXY), wide, lerp(flat, 0.9, HOLLOW)


def sweep(y, W, wide):
    s = y / (HAMMER * W)
    return SWEEP * W * wide * s * s


def head_frame(p, dir):
    right = dir.cross(UP)
    if right.length < 1e-4:
        right = dir.cross(Vector((1, 0, 0)))
    right.normalize()
    return right, right.cross(dir)


def placer(p, dir, gape, jaw):
    right, up = head_frame(p, dir)
    jc, js = math.cos(gape), math.sin(gape) * jaw

    def place(x, y, z):
        z = z * jaw
        x2, z2 = x * jc - z * js, x * js + z * jc
        return p + dir * x2 + right * y + up * z2

    return place


def head_mesh(p, dir, W, mats):
    skin, flesh = mats
    colour = unpack(COLOR)
    Lw = W * LENGTH
    K = SHELL + CAVITY + 2
    verts, cols, faces, fm, uvs = [], [], [], [], []
    for jaw in (1, -1):
        place = placer(p, dir, GAPE, jaw)
        base = len(verts)
        tex = []
        for i in range(HEAD_RINGS):
            u = i / (HEAD_RINGS - 1)
            a, b, n, wide, hollow = head_shape(u, W)
            e, cav = 2 / n, b * hollow
            deep = lerp(u, 0.3, 0.85)
            span, along = CROWN * math.sqrt(a / W), -u * Lw / (2 * math.pi * W)
            for k in range(SHELL + 1):
                t = k / SHELL * math.pi
                y = a * spow(math.cos(t), e)
                verts.append(place(u * Lw - sweep(y, W, wide), y, b * spow(math.sin(t), e)))
                cols.append(colour)
                tex.append(((0 if jaw == 1 else 0.5) + (k / SHELL - 0.5) * 2 * span, along))
            for k in range(CAVITY + 1):
                s = k / CAVITY * 2 - 1
                y = s * a * LIPIN
                shade = deep * (0.7 + 0.3 * abs(s))
                verts.append(place(u * Lw - sweep(y, W, wide), y, cav * (1 - s * s)))
                cols.append(tuple(c * shade for c in THROAT))
                tex.append((0, 0))
        for i in range(HEAD_RINGS - 1):
            o0, o1 = base + i * K, base + (i + 1) * K
            for k in range(K):
                k2 = (k + 1) % K
                f = (o0 + k, o0 + k2, o1 + k2, o1 + k)
                if jaw == 1:
                    f = f[::-1]
                faces.append(f)
                uvs.append(tuple(tex[x - base] for x in f))
                fm.append(0 if k < SHELL else 1)
    add_mesh("Head", verts, faces, cols, [skin, flesh], fm, uvs)


def tube(points, radii, colours, verts, faces, cols, sides, caps=(True, True)):
    n = len(points)
    tangents = []
    for j in range(n):
        a, b = points[max(j - 1, 0)], points[min(j + 1, n - 1)]
        tangents.append((b - a).normalized())
    frames = transport(tangents)
    base = len(verts)
    for j in range(n):
        nn, bn = frames[j]
        for q in range(sides):
            a = q / sides * math.pi * 2
            verts.append(points[j] + (nn * math.cos(a) + bn * math.sin(a)) * radii[j])
            cols.append(colours[j])
    for j in range(n - 1):
        for q in range(sides):
            q2 = (q + 1) % sides
            faces.append((base + j * sides + q, base + j * sides + q2, base + (j + 1) * sides + q2, base + (j + 1) * sides + q))
    for end, sign, cap in ((0, -1, caps[0]), (n - 1, 1, caps[1])):
        if not cap:
            continue
        ring = base + end * sides
        verts.append(points[end] + tangents[end] * sign * radii[end] * 0.9)
        cols.append(colours[end])
        c = len(verts) - 1
        for q in range(sides):
            q2 = (q + 1) % sides
            faces.append((ring + q2, ring + q, c) if sign < 0 else (ring + q, ring + q2, c))


def eyes(p, dir, W, look, mat):
    colour = tuple(c * 0.9 for c in unpack(COLOR))
    Lw = W * LENGTH
    place = placer(p, dir, GAPE, 1)
    a, b, n, wide, _ = head_shape(STALK_AT, W)
    verts, faces, cols = [], [], []
    for side in (-1, 1):
        y = side * a * STALK_OUT
        x = STALK_AT * Lw - sweep(y, W, wide)
        z = b * (1 - STALK_OUT ** n) ** (1 / n) - W * 0.03
        root = place(x, y, z)
        up = (place(x, y, z + 1) - root).normalized()
        out = (place(x, y + side, z) - root).normalized()
        up = (up + out * 0.35).normalized()
        to = (look - root).normalized()
        aim = (up * STALK_UPRIGHT + to * LEAN).normalized()
        L = W * STALK
        tip = root + aim * (L * STALK_REACH)
        span = (tip - root).length
        ctrl = root + up * (span * 0.55)
        pts, radii, shades = [], [], []
        steps = STALK_SEGS * 4
        for i in range(steps + 1):
            t = i / steps
            pts.append(root * (1 - t) ** 2 + ctrl * (2 * (1 - t) * t) + tip * (t * t))
            seg = t * STALK_SEGS
            bead = 0.5 - 0.5 * math.cos(seg * 2 * math.pi)
            radii.append(W * lerp(t, STALK_R, STALK_TIP) * (1 + 0.18 * bead))
            shades.append(tuple(c * (1 - 0.15 * bead) for c in colour))
        tube(pts, radii, shades, verts, faces, cols, 16, caps=(False, True))
        tan = (tip - ctrl).normalized()
        centre = tip + tan * (W * BALL * 0.6)
        gaze = (look - centre).normalized()
        ball(centre, gaze, W * BALL, verts, faces, cols)
    add_mesh("Eyes", verts, faces, cols, [mat])


def ball(centre, look, r, verts, faces, cols):
    right = Vector((look.y, -look.x, 0))
    if right.length < 1e-4:
        right = Vector((0, look.z, -look.y))
    right.normalize()
    up = right.cross(look)
    rings, sides = 48, 64
    base = len(verts)
    for i in range(rings + 1):
        lat = (i / rings - 0.5) * math.pi
        f, cl = math.sin(lat), math.cos(lat)
        for q in range(sides):
            ang = q / sides * math.pi * 2
            s, u = math.cos(ang) * cl, math.sin(ang) * cl
            col = SCLERA
            if f > 0.3:
                if (s / PUPIL_W) ** 2 + (u / PUPIL_H) ** 2 < 1:
                    col = PUPIL
                elif f > IRIS_AT:
                    col = IRIS
            verts.append(centre + (look * f + right * s + up * u) * r)
            cols.append(col)
    for i in range(rings):
        for q in range(sides):
            q2 = (q + 1) % sides
            a, b = base + i * sides, base + (i + 1) * sides
            faces.append((b + q, b + q2, a + q2, a + q))


def tongue(p, dir, W, mat):
    right, up = head_frame(p, dir)
    root = p + dir * (W * TONGUE_ROOT_AT)
    lip = p + dir * (W * TONGUE_LIP)
    reach = (dir + right * TONGUE_SWAY + up * TONGUE_RISE).normalized()
    tip = lip + reach * (W * TONGUE_REACH)
    ctrl = lip + dir * ((tip - lip).length * TONGUE_LEAD)
    along = (tip - root).normalized()
    side = along.cross(UP).normalized()
    bend = side.cross(along)
    dist = (tip - root).length
    count = 48
    pts, radii, colours = [], [], []
    r0 = W * TONGUE_WIDTH
    r1 = r0 * (1 - TONGUE_TAPER)
    for i in range(count):
        f = i / (count - 1)
        g = 1 - f
        w = math.sin(math.pi * f) * step(0, 0.2, f) * dist * 0.05
        ph = f * 1.2 * math.pi * 2 + 1.3
        pts.append(root * (g * g) + ctrl * (2 * g * f) + tip * (f * f) + side * (math.sin(ph) * w) + bend * (0.6 * math.cos(ph * 0.8) * w))
        radii.append(lerp(f ** 1.5, r0, r1))
        k = min(f * 3, 1)
        colours.append(tuple(lerp(k, TONGUE_ROOT[c], TONGUE[c]) for c in range(3)))
    verts, faces, cols = [], [], []
    tube(pts, radii, colours, verts, faces, cols, 16, caps=(True, False))
    t = (pts[-1] - pts[-2]).normalized()
    fs = t.cross(UP).normalized()
    length = W * FORK
    for s in (-1, 1):
        spread = fs * (s * FORK_SPREAD)
        prong = [pts[-1] - t * (length * 0.2), pts[-1] + (t + spread * 0.5) * (length * 0.5), pts[-1] + (t + spread) * length]
        dense = spline(prong, 8)
        rr = [lerp(i / (len(dense) - 1), r1, r1 * 0.15) for i in range(len(dense))]
        tube(dense, rr, [TONGUE] * len(dense), verts, faces, cols, 12)
    add_mesh("Tongue", verts, faces, cols, [mat])


def gpu(scene):
    scene.render.engine = "CYCLES"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA", "HIP", "METAL", "ONEAPI"):
            try:
                prefs.compute_device_type = kind
            except TypeError:
                continue
            prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == kind
                scene.cycles.device = "GPU"
                return
    except KeyError:
        pass


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = dict(zip(argv[::2], argv[1::2]))
    out = os.path.abspath(args.get("--out", "renders"))
    samples = int(args.get("--samples", 256))
    pct = int(args.get("--pct", 100))
    os.makedirs(out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    F.SUN, F.SKY, F.LAMP = SUN, SKY, LAMP
    F.stage(os.path.abspath(args.get("--map", MAP)))
    origin = F.floor_at(*HEAD_AT)
    yaw = math.radians(FACING)
    toward = Vector((math.cos(yaw), math.sin(yaw), 0))
    side = UP.cross(toward)

    def local(v):
        return origin + toward * v[0] + side * v[1] + UP * v[2]

    cam_pos = local(CAMERA["at"])
    skin, flesh, eye = materials(skin_image(out))
    pts = joints(origin, toward)
    fwd = (pts[0] - pts[1]).normalized()
    p, dir, W = body_mesh(pts, (skin, flesh), (fwd + UP * LIFT).normalized())
    head_mesh(p, dir, W, (skin, flesh))
    eyes(p, dir, W, cam_pos, eye)
    tongue(p, dir, W, flesh)

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = CAMERA["lens"]
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = cam_pos * S
    target = local(CAMERA["look"])
    cam.rotation_euler = (target * S - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.dof.use_dof = True
    cam_data.dof.focus_distance = (p * S - cam.location).length
    cam_data.dof.aperture_fstop = CAMERA["fstop"]
    scene.camera = cam

    gpu(scene)
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = pct
    scene.render.image_settings.file_format = "PNG"
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = EXPOSURE
    scene.render.filepath = os.path.join(out, "thumbnail.png")
    if args.get("--save"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(args["--save"]))
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
